/*
  =====================================================================
   SmartCompost - Controlador principal (Arduino UNO)
  =====================================================================
   Sirve tal cual para Tinkercad y para el montaje real.
   El UNO lee los sensores, controla bomba / volteo / buzzer / LCD
   y manda los datos al ESP32 (que los sube a la página web).

   SENSOR DE TEMPERATURA Y HUMEDAD: DHT11 (uno solo mide las dos cosas)
     Rango del DHT11: temperatura 0-50 °C, humedad del aire 20-90 %.
     Tinkercad no tiene DHT11, por eso allí se simula con:
       potenciómetro en A0 = humedad (0-100 %)  y  TMP36 en A1 = temperatura.

   PINES
     A0  DATA del DHT11            (Tinkercad: potenciómetro de humedad)
     A1  sin uso en el real        (Tinkercad: TMP36)
     A2  MQ-2
     A3  MQ-135
     D12 LCD RS   D11 LCD E   D5 LCD D4   D4 LCD D5   D3 LCD D6   D2 LCD D7
     D7  TX hacia el ESP32 (con divisor de voltaje 1k / 2k)
     D8  Buzzer
     D9  Transistor -> bomba de agua
     D10 Transistor -> motor de volteo (aspas)

   LÓGICA
     Riego:        humedad < 30 %  o  temperatura > 45 °C  o  < 15 °C
                   (se apaga al llegar a 66 % de humedad)
     Post-riego:   al llegar o superar 66 % -> volteo 3 min
     Periódico:    volteo cada 8 min, dura 3 min
     Gas:          nivelGas > 600 -> emergencia (volteo para airear)
                   vuelve a normal cuando nivelGas <= 600
     Buzzer:       humedad baja, temperatura fuera de rango,
                   gas alto sin que se esté regando, o DHT11 sin respuesta
  =====================================================================
*/

#include <LiquidCrystal.h>
#include <SoftwareSerial.h>

// 0 = Tinkercad (potenciómetro + TMP36)   1 = montaje real con DHT11
#define USAR_DHT11 0

// 1 = todos los tiempos 10 veces más cortos (para probar rápido en Tinkercad)
// 0 = tiempos reales del proyecto
#define MODO_PRUEBA 0

#if MODO_PRUEBA
const unsigned long ESCALA = 10;
#else
const unsigned long ESCALA = 1;
#endif

// ---------------------------- PINES ----------------------------
const byte PIN_DHT11   = A0;   // real: DATA del DHT11
const byte PIN_HUMEDAD = A0;   // Tinkercad: potenciómetro de humedad
const byte PIN_TEMP    = A1;   // Tinkercad: TMP36
const byte PIN_MQ2     = A2;
const byte PIN_MQ135   = A3;
const byte PIN_ESP_RX  = 6;    // no se usa (el ESP32 no le responde al UNO)
const byte PIN_ESP_TX  = 7;
const byte PIN_BUZZER  = 8;
const byte PIN_BOMBA   = 9;
const byte PIN_VOLTEO  = 10;

LiquidCrystal lcd(12, 11, 5, 4, 3, 2);   // RS, E, D4, D5, D6, D7
SoftwareSerial esp32(PIN_ESP_RX, PIN_ESP_TX);

// --------------------------- UMBRALES --------------------------
// Ajustados al DHT11 (temperatura 0-50 °C, humedad 20-90 %).
const int   HUM_MIN        = 30;     // riego si humedad < 30 %
const int   HUM_POST_RIEGO = 66;     // corta el riego y voltea al llegar a 66 %
const int   HUM_REARME     = 60;     // evita repetir el volteo post-riego por ruido del sensor
const float TEMP_MIN       = 15.0;   // por debajo: compost frío
const float TEMP_MAX       = 45.0;   // por encima: demasiado caliente (el DHT11 llega a 50)
const int   GAS_MAX        = 600;
const byte  FALLOS_DHT_MAX = 3;      // lecturas fallidas seguidas antes de dar error

// ---------------------------- TIEMPOS --------------------------
const unsigned long T_VOLTEO         = 180000UL / ESCALA;  // 3 min
const unsigned long T_PERIODO_VOLTEO = 480000UL / ESCALA;  // 8 min
const unsigned long T_RIEGO_MAX      =  60000UL / ESCALA;  // seguridad: máx. 1 min seguido de bomba
const unsigned long T_PAUSA_RIEGO    = 120000UL / ESCALA;  // espera para que el agua se reparta
const unsigned long T_CALENTAR_MQ    =  20000UL / ESCALA;  // precalentamiento de los MQ al encender
const unsigned long T_LECTURA        = 500;
const unsigned long T_LECTURA_DHT    = 2000;  // el DHT11 no se puede leer más de 1 vez por segundo
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
unsigned long tLectura = 0, tEnvio = 0, tLcd = 0, tDHT = 0;
const char* motivoVolteo = "-";

bool sensorOk = false;       // false hasta tener una lectura válida de temp./humedad
byte fallosDHT = 0;

// ======================= SENSORES =======================
int leerPromedio(byte pin) {
  long suma = 0;
  for (byte i = 0; i < 10; i++) {
    suma += analogRead(pin);
    delay(2);
  }
  return suma / 10;
}

#if USAR_DHT11
// Lectura del DHT11 sin librerías: el sensor responde con 40 bits.
// Cada bit es un pulso BAJO (~50 us) y uno ALTO: corto (~27 us) = 0, largo (~70 us) = 1.
unsigned int medirPulso(byte pin, byte nivel) {
  unsigned int cuenta = 0;
  while (digitalRead(pin) == nivel) {
    if (++cuenta > 2000) return 0;   // el sensor no respondió
  }
  return cuenta;
}

bool leerDHT11(int &hum, float &temp) {
  byte datos[5] = {0, 0, 0, 0, 0};

  pinMode(PIN_DHT11, OUTPUT);       // señal de inicio: 20 ms en BAJO
  digitalWrite(PIN_DHT11, LOW);
  delay(20);
  pinMode(PIN_DHT11, INPUT_PULLUP);
  delayMicroseconds(55);

  noInterrupts();
  bool ok = medirPulso(PIN_DHT11, LOW) && medirPulso(PIN_DHT11, HIGH);  // respuesta
  for (byte i = 0; ok && i < 40; i++) {
    unsigned int bajo = medirPulso(PIN_DHT11, LOW);
    unsigned int alto = medirPulso(PIN_DHT11, HIGH);
    if (!bajo || !alto) ok = false;
    datos[i / 8] <<= 1;
    if (alto > bajo) datos[i / 8] |= 1;
  }
  interrupts();

  if (!ok) return false;
  if (datos[4] != (byte)(datos[0] + datos[1] + datos[2] + datos[3])) return false;  // checksum
  hum  = datos[0];
  temp = datos[2] + datos[3] * 0.1;
  return hum <= 100 && temp <= 60;
}
#endif

void leerTempHumedad(unsigned long ahora) {
#if USAR_DHT11
  if (ahora - tDHT < T_LECTURA_DHT && tDHT != 0) return;
  tDHT = ahora;
  int h;
  float t;
  if (leerDHT11(h, t)) {
    humedad = h;
    temperatura = t;
    sensorOk = true;
    fallosDHT = 0;
  } else if (++fallosDHT >= FALLOS_DHT_MAX) {
    sensorOk = false;    // se queda con el último valor, pero deja de regar por él
  }
#else
  // Tinkercad: potenciómetro = humedad 0-100 %, TMP36 = temperatura
  humedad = map(leerPromedio(PIN_HUMEDAD), 0, 1023, 0, 100);
  float voltios = leerPromedio(PIN_TEMP) * 5.0 / 1023.0;
  temperatura = (voltios - 0.5) * 100.0;   // TMP36: 10 mV/°C, 500 mV a 0 °C
  sensorOk = true;
#endif
}

void leerSensores() {
  leerTempHumedad(millis());

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
  // Sin lectura válida del DHT11 no se riega por humedad/temperatura
  bool humBaja  = sensorOk && humedad < HUM_MIN;
  bool tempMala = sensorOk && ((temperatura > TEMP_MAX) || (temperatura < TEMP_MIN));

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
  } else if (!sensorOk) {
    bomba(false);                       // se perdió el sensor: no seguir regando a ciegas
    finRiego = ahora;
    huboRiego = true;
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
  alarma = humBaja || tempMala || (emergenciaGas && !bombaOn) || !sensorOk;
}

const char* estadoTexto() {
  if (emergenciaGas)       return "EMERGENCIA GAS";
  if (!sensorOk)           return "ERROR DHT11";
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

  // Fila 1 (fija): humedad y temperatura   ->  "H: 45% T: 28.0C"
  if (sensorOk) {
    dtostrf(temperatura, 5, 1, t);
    snprintf(linea, sizeof(linea), "H:%3d%% T:%sC", humedad, t);
    lcdLinea(0, linea);
  } else {
    lcdLinea(0, "Revisar DHT11");
  }

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
  if (!sensorOk) return;    // la página solo recibe lecturas válidas
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
