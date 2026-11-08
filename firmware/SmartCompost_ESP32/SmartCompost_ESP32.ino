/*
  =====================================================================
   SmartCompost - Puente WiFi (ESP32)
  =====================================================================
   Recibe del Arduino UNO una línea JSON cada 2 s y la sube a la API
   de SmartCompost (FastAPI) en  POST /iot/lecturas.

   La API guarda la lectura en la pila del sensor cuyo código coincide
   con CODIGO_DISPOSITIVO, convierte los MQ a ppm, calcula el semáforo y
   actualiza el estado de la pila -> aparece en el dashboard de Flutter.

   CONEXIÓN (el UNO trabaja a 5 V y el ESP32 a 3.3 V -> divisor):

     UNO D7 ──[ 1kΩ ]──┬── ESP32 GPIO16 (RX2)
                       │
                    [ 2kΩ ]   (dos de 1kΩ en serie, o 2.2kΩ)
                       │
     UNO GND ──────────┴── ESP32 GND      (¡GND común obligatorio!)
  =====================================================================
*/

#include <WiFi.h>
#include <HTTPClient.h>
#include <WiFiClientSecure.h>

// ----------------------- CAMBIAR ESTOS DATOS -----------------------
const char* WIFI_SSID     = "NOMBRE_DE_TU_WIFI";
const char* WIFI_PASSWORD = "CLAVE_DE_TU_WIFI";

// IP del computador donde corre `docker compose up` (Nginx, puerto 80).
// En Windows: ipconfig -> "Dirección IPv4". Ej: http://192.168.1.50/iot/lecturas
const char* SERVER_URL    = "http://192.168.1.50/iot/lecturas";

// Igual que IOT_API_KEY del archivo .env del servidor
const char* API_KEY       = "dev-iot-key-change-me";

// Código del sensor que registraron en la página (Sensores -> Nuevo)
const char* CODIGO_DISPOSITIVO = "ESP32-01";
// -------------------------------------------------------------------

const int RX2_PIN = 16;
const int TX2_PIN = 17;
const unsigned long INTERVALO_NORMAL = 30000;  // sube una lectura cada 30 s
const unsigned long INTERVALO_MINIMO = 5000;   // si cambia el estado, sube ya (máx. 1 cada 5 s)

String linea;
String ultimoJson;
String ultimoEstadoSubido;
unsigned long ultimaSubida = 0;
unsigned long ultimoIntentoWifi = 0;

void conectarWiFi() {
  Serial.printf("Conectando a %s", WIFI_SSID);
  WiFi.mode(WIFI_STA);
  WiFi.begin(WIFI_SSID, WIFI_PASSWORD);
  unsigned long inicio = millis();
  while (WiFi.status() != WL_CONNECTED && millis() - inicio < 15000) {
    delay(500);
    Serial.print(".");
  }
  if (WiFi.status() == WL_CONNECTED) {
    Serial.print("\nWiFi OK, IP del ESP32: ");
    Serial.println(WiFi.localIP());
  } else {
    Serial.println("\nSin WiFi, se reintentará");
  }
}

// Saca el valor de "estado" de la línea del UNO (ej. "REGANDO")
String extraerEstado(const String& json) {
  int i = json.indexOf("\"estado\":\"");
  if (i < 0) return "";
  i += 10;
  int f = json.indexOf('"', i);
  return f < 0 ? "" : json.substring(i, f);
}

// Agrega el código del dispositivo al JSON del UNO:
// {"humedad":45,...}  ->  {"codigo_dispositivo":"ESP32-01","humedad":45,...}
String armarCuerpo(const String& json) {
  return String("{\"codigo_dispositivo\":\"") + CODIGO_DISPOSITIVO + "\"," + json.substring(1);
}

bool subirDatos(const String& json) {
  WiFiClientSecure clienteSeguro;
  WiFiClient clienteNormal;
  HTTPClient http;

  bool ok;
  if (String(SERVER_URL).startsWith("https")) {
    clienteSeguro.setInsecure();
    ok = http.begin(clienteSeguro, SERVER_URL);
  } else {
    ok = http.begin(clienteNormal, SERVER_URL);
  }
  if (!ok) {
    Serial.println("URL inválida");
    return false;
  }

  http.setTimeout(8000);
  http.addHeader("Content-Type", "application/json");
  http.addHeader("X-API-Key", API_KEY);
  int codigo = http.POST(armarCuerpo(json));

  if (codigo == 201) {
    Serial.println("API: lectura guardada (201)");
  } else if (codigo > 0) {
    // 401 = API_KEY distinta, 404 = código no registrado, 409 = sensor inactivo,
    // 422 = dato inválido (p. ej. sensor de temperatura desconectado)
    Serial.printf("API respondió %d: %s\n", codigo, http.getString().c_str());
  } else {
    Serial.printf("Sin conexión con el servidor: %s\n", http.errorToString(codigo).c_str());
  }
  http.end();
  return codigo == 201;
}

void setup() {
  Serial.begin(115200);
  Serial2.setRxBufferSize(1024);
  Serial2.begin(9600, SERIAL_8N1, RX2_PIN, TX2_PIN);
  conectarWiFi();
}

void loop() {
  // 1) Leer las líneas que manda el UNO
  while (Serial2.available()) {
    char c = Serial2.read();
    if (c == '\n') {
      linea.trim();
      if (linea.startsWith("{") && linea.endsWith("}")) {
        ultimoJson = linea;
        Serial.println("UNO: " + linea);
      }
      linea = "";
    } else if (c != '\r') {
      linea += c;
      if (linea.length() > 400) linea = "";   // línea rota
    }
  }

  // 2) Mantener el WiFi
  if (WiFi.status() != WL_CONNECTED) {
    if (millis() - ultimoIntentoWifi > 10000) {
      ultimoIntentoWifi = millis();
      Serial.println("Reconectando WiFi...");
      WiFi.reconnect();
    }
    return;
  }

  // 3) Subir: cada 30 s, o enseguida si cambió el estado (REGANDO, GAS...)
  if (ultimoJson.length() == 0) return;
  unsigned long pasado = millis() - ultimaSubida;
  String estado = extraerEstado(ultimoJson);
  bool cambioEstado = estado != ultimoEstadoSubido;

  if (pasado >= INTERVALO_NORMAL || (cambioEstado && pasado >= INTERVALO_MINIMO)) {
    ultimaSubida = millis();
    if (subirDatos(ultimoJson)) ultimoEstadoSubido = estado;
    ultimoJson = "";
  }
}
