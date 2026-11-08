/*
  =====================================================================
   SmartCompost - Controlador principal (Arduino UNO)
  =====================================================================
   Sirve tal cual para Tinkercad y para el montaje real.
   El UNO lee los sensores, controla bomba / volteo / buzzer / LCD
   y manda los datos al ESP32 (que los sube a la página web).

   PINES
     A0  Sensor de humedad de suelo
     A1  Sensor de temperatura (TMP36 en Tinkercad; ver guía para DS18B20)
     A2  MQ-2
     A3  MQ-135
     D12 LCD RS   D11 LCD E   D5 LCD D4   D4 LCD D5   D3 LCD D6   D2 LCD D7
     D7  TX hacia el ESP32 (con divisor de voltaje 1k / 2k)
     D8  Buzzer
     D9  Transistor -> bomba de agua
     D10 Transistor -> motor de volteo (aspas)

   LÓGICA
     Riego:        humedad < 30 %  o  temperatura > 65 °C  o  < 40 °C
                   (se apaga al llegar a 66 % de humedad)
     Post-riego:   al llegar o superar 66 % -> volteo 3 min
     Periódico:    volteo cada 8 min, dura 3 min
     Gas:          nivelGas > 600 -> emergencia (volteo para airear)
                   vuelve a normal cuando nivelGas <= 600
     Buzzer:       humedad baja, temperatura fuera de rango,
                   o gas alto sin que se esté regando
  =====================================================================
*/

#include <LiquidCrystal.h>
#include <SoftwareSerial.h>

// 1 = todos los tiempos 10 veces más cortos (para probar rápido en Tinkercad)
// 0 = tiempos reales del proyecto
#define MODO_PRUEBA 0

#if MODO_PRUEBA
const unsigned long ESCALA = 10;
#else
const unsigned long ESCALA = 1;
#endif

// ---------------------------- PINES ----------------------------
const byte PIN_HUMEDAD = A0;
const byte PIN_TEMP    = A1;
const byte PIN_MQ2     = A2;
const byte PIN_MQ135   = A3;
const byte PIN_ESP_RX  = 6;    // no se usa (el ESP32 no le responde al UNO)
const byte PIN_ESP_TX  = 7;
const byte PIN_BUZZER  = 8;
const byte PIN_BOMBA   = 9;
const byte PIN_VOLTEO  = 10;

LiquidCrystal lcd(12, 11, 5, 4, 3, 2);   // RS, E, D4, D5, D6, D7
SoftwareSerial esp32(PIN_ESP_RX, PIN_ESP_TX);

// ------------------------- CALIBRACIÓN -------------------------
// Lectura cruda (0-1023) del sensor de humedad totalmente seco y en agua.
//   Tinkercad:                 SECO = 0,    MOJADO = 876
//   Real, sensor capacitivo:   SECO ~ 520,  MOJADO ~ 260  (¡mídelo con el Monitor Serie!)
//   Real, sensor resistivo:    SECO ~ 1023, MOJADO ~ 300
const int HUM_LECTURA_SECO   = 0;
const int HUM_LECTURA_MOJADO = 876;

// --------------------------- UMBRALES --------------------------
const int   HUM_MIN        = 30;     // riego si humedad < 30 %
const int   HUM_POST_RIEGO = 66;     // corta el riego y voltea al llegar a 66 %
const int   HUM_REARME     = 60;     // evita repetir el volteo post-riego por ruido del sensor
const float TEMP_MIN       = 40.0;
const float TEMP_MAX       = 65.0;
const int   GAS_MAX        = 600;

// ---------------------------- TIEMPOS --------------------------
const unsigned long T_VOLTEO         = 180000UL / ESCALA;  // 3 min
const unsigned long T_PERIODO_VOLTEO = 480000UL / ESCALA;  // 8 min
const unsigned long T_RIEGO_MAX      =  60000UL / ESCALA;  // seguridad: máx. 1 min seguido de bomba
const unsigned long T_PAUSA_RIEGO    = 120000UL / ESCALA;  // espera para que el agua se reparta
const unsigned long T_CALENTAR_MQ    =  20000UL / ESCALA;  // precalentamiento de los MQ al encender
const unsigned long T_LECTURA        = 500;
const unsigned long T_ENVIO          = 2000;
const unsigned long T_CAMBIO_LCD     = 2500;

// --------------------------- VARIABLES -------------------------
int   humedad = 0;
float temperatura = 0;
int   gasMQ2 = 0, gasMQ135 = 0, nivelGas = 0;

bool bombaOn = false;
bool volteoOn = false;
bool emergenciaGas = false;
bool alarma = false;
bool postRiegoArmado = true;
bool huboRiego = false;
bool buzzerSonando = false;
bool lcdMostrarGas = true;

unsigned long inicioRiego = 0, finRiego = 0, inicioVolteo = 0;
unsigned long tLectura = 0, tEnvio = 0, tLcd = 0;
const char* motivoVolteo = "-";

// ======================= SENSORES =======================
int leerPromedio(byte pin) {
  long suma = 0;
  for (byte i = 0; i < 10; i++) {
    suma += analogRead(pin);
    delay(2);
  }
  return suma / 10;
}

void leerSensores() {
  int crudo = leerPromedio(PIN_HUMEDAD);
  humedad = constrain(map(crudo, HUM_LECTURA_SECO, HUM_LECTURA_MOJADO, 0, 100), 0, 100);

  // TMP36: 10 mV por °C con 500 mV de desplazamiento
  float voltios = leerPromedio(PIN_TEMP) * 5.0 / 1023.0;
  temperatura = (voltios - 0.5) * 100.0;

  gasMQ2   = leerPromedio(PIN_MQ2);
  gasMQ135 = leerPromedio(PIN_MQ135);
  nivelGas = max(gasMQ2, gasMQ135);
}

// ======================= ACTUADORES =======================
void bomba(bool on)  { bombaOn = on;  digitalWrite(PIN_BOMBA,  on ? HIGH : LOW); }
void volteo(bool on) { volteoOn = on; digitalWrite(PIN_VOLTEO, on ? HIGH : LOW); }

void iniciarVolteo(unsigned long ahora, const char* motivo) {
  inicioVolteo = ahora;     // si ya estaba girando, se reinician los 3 min
  motivoVolteo = motivo;
  volteo(true);
}

// ======================= CONTROL =======================
void controlar(unsigned long ahora) {
  bool humBaja  = humedad < HUM_MIN;
  bool tempMala = (temperatura > TEMP_MAX) || (temperatura < TEMP_MIN);

  // 1) Gas de emergencia (inmediato, sin retardo)
  emergenciaGas = nivelGas > GAS_MAX;

  // 2) Riego
  bool riegoTerminoEn66 = false;
  if (!bombaOn) {
    bool necesita = (humBaja || tempMala) && humedad < HUM_POST_RIEGO;
    bool pausaOk  = !huboRiego || (ahora - finRiego >= T_PAUSA_RIEGO);
    if (necesita && pausaOk) {
      bomba(true);
      inicioRiego = ahora;
    }
  } else if (humedad >= HUM_POST_RIEGO) {
    bomba(false);
    finRiego = ahora;
    huboRiego = true;
    riegoTerminoEn66 = true;
  } else if (ahora - inicioRiego >= T_RIEGO_MAX) {
    bomba(false);                       // seguridad: descansa y luego sigue
    finRiego = ahora;
    huboRiego = true;
  }

  // 3) Volteo post-riego: al llegar o superar el 66 %
  if (humedad < HUM_REARME) postRiegoArmado = true;
  if (riegoTerminoEn66 || (postRiegoArmado && humedad >= HUM_POST_RIEGO)) {
    postRiegoArmado = false;
    iniciarVolteo(ahora, "post-riego");
  }

  // 4) Fin del volteo (no se detiene mientras haya emergencia de gas)
  if (volteoOn && !emergenciaGas && ahora - inicioVolteo >= T_VOLTEO) {
    volteo(false);
  }

  // 5) Volteo periódico cada 8 min
  if (!volteoOn && ahora - inicioVolteo >= T_PERIODO_VOLTEO) {
    iniciarVolteo(ahora, "periodico");
  }

  // 6) Emergencia de gas: airear volteando
  if (emergenciaGas && !volteoOn) {
    iniciarVolteo(ahora, "gas");
  }

  // 7) Alarma sonora
  alarma = humBaja || tempMala || (emergenciaGas && !bombaOn);
}

const char* estadoTexto() {
  if (emergenciaGas)       return "EMERGENCIA GAS";
  if (bombaOn && volteoOn) return "RIEGO+VOLTEO";
  if (bombaOn)             return "REGANDO";
  if (volteoOn)            return "VOLTEANDO";
  if (alarma)              return "ALERTA";
  return "NORMAL";
}

// ======================= BUZZER =======================
void actualizarBuzzer(unsigned long ahora) {
  if (!alarma) {
    if (buzzerSonando) { noTone(PIN_BUZZER); buzzerSonando = false; }
    return;
  }
  unsigned long periodo = emergenciaGas ? 150 : 500;      // gas = pitido más rápido
  bool debeSonar = (ahora / periodo) % 2 == 0;
  if (debeSonar && !buzzerSonando) {
    tone(PIN_BUZZER, emergenciaGas ? 2500 : 1800);
    buzzerSonando = true;
  } else if (!debeSonar && buzzerSonando) {
    noTone(PIN_BUZZER);
    buzzerSonando = false;
  }
}

// ======================= LCD =======================
void lcdLinea(byte fila, const char* texto) {
  char buf[17];
  snprintf(buf, sizeof(buf), "%-16s", texto);
  lcd.setCursor(0, fila);
  lcd.print(buf);
}

void actualizarLCD(unsigned long ahora) {
  char t[8], linea[17];

  // Fila 1 (fija): humedad y temperatura   ->  "H: 45% T: 55.2C"
  dtostrf(temperatura, 5, 1, t);
  snprintf(linea, sizeof(linea), "H:%3d%% T:%sC", humedad, t);
  lcdLinea(0, linea);

  // Fila 2 (alterna): gases (MQ-2/MQ-135)  <->  estado
  if (ahora - tLcd >= T_CAMBIO_LCD) {
    tLcd = ahora;
    lcdMostrarGas = !lcdMostrarGas;
  }
  if (lcdMostrarGas) {
    snprintf(linea, sizeof(linea), "Gases:%d/%d", gasMQ2, gasMQ135);
    lcdLinea(1, linea);
  } else {
    lcdLinea(1, estadoTexto());
  }
}

// ======================= ENVÍO AL ESP32 =======================
void enviarDatos() {
  char t[8];
  dtostrf(temperatura, 1, 1, t);
  char json[220];
  snprintf(json, sizeof(json),
           "{\"humedad\":%d,\"temperatura\":%s,\"mq2\":%d,\"mq135\":%d,\"gas\":%d,"
           "\"riego\":%d,\"volteo\":%d,\"emergenciaGas\":%d,\"alarma\":%d,"
           "\"estado\":\"%s\",\"motivoVolteo\":\"%s\"}",
           humedad, t, gasMQ2, gasMQ135, nivelGas,
           bombaOn, volteoOn, emergenciaGas, alarma,
           estadoTexto(), volteoOn ? motivoVolteo : "-");
  esp32.println(json);
  Serial.println(json);     // para verlo en el Monitor Serie
}

// ======================= SETUP / LOOP =======================
void setup() {
  pinMode(PIN_BOMBA, OUTPUT);
  pinMode(PIN_VOLTEO, OUTPUT);
  pinMode(PIN_BUZZER, OUTPUT);
  bomba(false);
  volteo(false);

  Serial.begin(9600);
  esp32.begin(9600);
  lcd.begin(16, 2);
  lcdLinea(0, "  SmartCompost");

  // Precalentamiento de los sensores MQ
  unsigned long inicio = millis();
  while (millis() - inicio < T_CALENTAR_MQ) {
    char buf[17];
    unsigned long resta = (T_CALENTAR_MQ - (millis() - inicio)) / 1000 + 1;
    snprintf(buf, sizeof(buf), "Calentando %3lus", resta);
    lcdLinea(1, buf);
    delay(250);
  }

  inicioVolteo = millis();   // el primer volteo periódico será a los 8 min
  lcd.clear();
}

void loop() {
  unsigned long ahora = millis();

  if (ahora - tLectura >= T_LECTURA) {
    tLectura = ahora;
    leerSensores();
    controlar(millis());
    actualizarLCD(millis());
  }

  if (ahora - tEnvio >= T_ENVIO) {
    tEnvio = ahora;
    enviarDatos();
  }

  actualizarBuzzer(millis());
}
