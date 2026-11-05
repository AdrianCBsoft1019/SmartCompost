# SmartCompost – Prototipo físico (Arduino UNO + ESP32)

## 1. Cómo encaja con el resto del proyecto

```
 Sensores ─► ARDUINO UNO ──serie──► ESP32 ──WiFi, HTTP──► Nginx :80 ─► API FastAPI ─► MySQL
 (C++)       decide riego,         (C++)   POST /iot/lecturas         (Python)          │
             volteo, alarma                cabecera X-API-Key                           │
             ├─► LCD 16x2                                                               ▼
             ├─► Buzzer                                          App Flutter (dashboard,
             ├─► Bomba 12 V                                      alertas, análisis, PDF)
             └─► Motor volteo 12 V
```

| Capa | Lenguaje | Carpeta |
|---|---|---|
| Arduino UNO (control) | C++ (Arduino) | `firmware/SmartCompost_UNO/` |
| ESP32 (WiFi) | C++ (Arduino) | `firmware/SmartCompost_ESP32/` |
| API | Python / FastAPI | `backend/app/routers/iot.py`, `backend/app/gases_service.py` |
| Base de datos | MySQL (tabla `lecturas`) | igual que antes |
| Página | Dart / Flutter | sin cambios: lee las lecturas nuevas como cualquier otra |

**Qué pasa con cada lectura:**
1. El UNO manda cada 2 s: `{"humedad":45,"temperatura":55.2,"mq2":310,"mq135":420,...,"estado":"VOLTEANDO"}`
2. El ESP32 le agrega `"codigo_dispositivo":"ESP32-01"` y la sube cada 30 s, o enseguida si cambia el estado (por ejemplo, pasa a REGANDO o a EMERGENCIA GAS).
3. La API busca el **sensor con ese código** y guarda la lectura en **su pila**. Convierte MQ-2 a **CH₄ ppm** y MQ-135 a **CO₂ y NH₃ ppm**, calcula el semáforo y actualiza el estado de la pila.
4. El dashboard, la gráfica de 24 h, las alertas y el análisis ya muestran **valores reales** en lugar de los del `seed`.

## 2. Poner a funcionar el enlace (paso a paso)

1. **Servidor**: en el `.env` de la raíz pon una clave propia para el ESP32:
   ```
   IOT_API_KEY=una-clave-larga-que-inventen
   ```
   y levanta todo con `docker compose up --build`.
2. **IP del computador**: en Windows ejecuta `ipconfig` y busca la "Dirección IPv4" (por ejemplo `192.168.1.50`). El ESP32 y el computador deben estar en **la misma red WiFi**. Prueba desde el celular, conectado a esa red, que `http://192.168.1.50/api/health` responde.
   - Si no responde, permite el puerto 80 en el Firewall de Windows (o la app Docker Desktop).
3. **Registrar el dispositivo en la página**: entra como instructor, ve a **Sensores → Nuevo**, código `ESP32-01`, tipo *temperatura*, y elige la pila (la caneca). Ese código es el que une el aparato con la pila.
4. **Firmware del ESP32**: en `SmartCompost_ESP32.ino` cambia `WIFI_SSID`, `WIFI_PASSWORD`, `SERVER_URL` (con la IP del paso 2), `API_KEY` (igual a `IOT_API_KEY`) y `CODIGO_DISPOSITIVO`.
5. Abre el Monitor Serie del ESP32 (115200 baudios). Debe salir `API: lectura guardada (201)`. Si no:

| Mensaje | Causa |
|---|---|
| `401` | `API_KEY` distinta de `IOT_API_KEY` |
| `404` | No hay un sensor con ese código en la página |
| `409` | El sensor está marcado como inactivo |
| `422` | Dato fuera de rango (el DS18B20 desconectado marca −127 °C) |
| `503` | El servidor no tiene `IOT_API_KEY` |
| `Sin conexión con el servidor` | IP mal escrita, otra red WiFi o firewall |

También puedes probar la API sin el ESP32 desde `http://localhost/docs` → **IoT (ESP32)** → `POST /iot/lecturas`. Pon la clave en la cabecera `X-API-Key`.

## 3. Valores reales de los sensores de gas (calibración)

Los MQ dan un número de 0 a 1023, no ppm. El servidor lo convierte con la fórmula del datasheet `ppm = a·(Rs/R0)^b`, y para eso necesita el **R0** de *cada* sensor:

1. Deja los MQ encendidos 24 h la primera vez. Luego, en **aire limpio** (afuera, sin compost), mira en el Monitor Serie del UNO los valores `mq2` y `mq135`.
2. Entra a `http://localhost/docs` → `GET /iot/calibracion?mq2=VALOR&mq135=VALOR` (con la `X-API-Key`).
3. Copia la respuesta en el `.env`:
   ```
   MQ2_R0_KOHM=...
   MQ135_R0_KOHM=...
   MQ_RL_KOHM=10      # resistencia de la plaquita del módulo: "103" = 10, "102" = 1
   ```
4. `docker compose up -d` para que tome los valores.

Mientras no calibren, los ppm salen con R0 = 10 kΩ y **no son confiables**: por ejemplo, el NH₃ puede salir por encima de 25 ppm y poner la pila en rojo. Son mediciones aproximadas, útiles para tendencias y alertas.

**Humedad y temperatura** también se calibran en el UNO: `HUM_LECTURA_SECO` / `HUM_LECTURA_MOJADO`, con el sensor al aire y luego en un vaso de agua.

> **Ojo con los límites:** el Arduino riega por debajo de 30 % y considera la temperatura buena entre 40 y 65 °C. La página (`backend/app/pila_service.py`, `LIMITES`) pone en rojo la humedad fuera de 40–65 % y la temperatura por encima de 70 °C. Pónganse de acuerdo en un solo criterio para que la página y el aparato digan lo mismo.

## 4. Lo que les falta

| Falta | Recomendado | Por qué |
|---|---|---|
| Sensor de temperatura | **DS18B20 sumergible** + resistencia 4.7 kΩ | Mide hasta 125 °C dentro del compost. El DHT11 solo llega a 50 °C. |
| Sensor de humedad de suelo | **Capacitivo v1.2** | El resistivo se oxida en el compost. |
| Fuente | **12 V, 3 A** o más | Para la bomba y el motor de 12 V. |
| Reductor 12 V → 5 V | **Módulo LM2596** (ajustado a 5.0 V) | El regulador del UNO se recalienta si le das 12 V y además alimenta los dos MQ (unos 300 mA). |
| Potenciómetro 10 kΩ | Para el contraste de la LCD | Sin él la pantalla se ve en blanco. |

### Transistores ("varios"): lee el código impreso
| Código | ¿Sirve para la bomba/motor de 12 V? |
|---|---|
| TIP120, TIP121, TIP122 | **Sí** (resistencia de base 1 kΩ) |
| IRLZ44N | **Sí, el mejor** (puerta ← 220 Ω ← pin; 10 kΩ de puerta a GND) |
| IRFZ44N, IRF540 | Mejor no: con los 5 V del Arduino no conducen del todo y se calientan |
| TIP31, TIP41, BD139 | Bomba sí. Motor solo si es pequeño (con base de 470 Ω) |
| 2N2222, 2N3904, BC547, BC548 | **No**: se queman con el pico de arranque del motor |

Si no tienen ninguno que sirva, usen un **módulo relé de 5 V** de 2 canales (IN1 → D9, IN2 → D10). No necesita diodo ni transistor.

## 5. Circuito en Tinkercad

### 5.1 Componentes
| Real | En Tinkercad |
|---|---|
| DS18B20 | Sensor de temperatura **TMP36** |
| MQ-2 / MQ-135 | **Sensor de gas** × 2 |
| Bomba y motor 12 V | **Motor de CC** × 2 (rotulados "Bomba" y "Volteo") |
| Fuente 12 V | **Fuente de alimentación** ajustada a 12 V (o batería 9 V) |
| Transistores | Transistor NPN (BJT) × 2 |
| LCD 16x2 | LCD 16 x 2 (la normal; la suya también es la normal, de 16 pines) |
| Buzzer | Piezo |
| Resistencias | 1 kΩ × 4, 220 Ω × 1, potenciómetro 10 kΩ |

Tinkercad no tiene ESP32 ni internet: allí solo se prueba el UNO. El JSON se ve en el Monitor Serie.

### 5.2 Conexiones del UNO
| Pin UNO | Va a |
|---|---|
| 5V / GND | Rieles + / − de la protoboard |
| A0 | Señal del sensor de humedad (VCC 5V, GND) |
| A1 | Vout del TMP36 (pata central; izq. 5V, der. GND, mirando la cara plana) |
| A2 | MQ-2 |
| A3 | MQ-135 |
| D2, D3, D4, D5 | LCD D7, D6, D5, D4 |
| D11 | LCD E |
| D12 | LCD RS |
| D7 | ESP32 GPIO16 (divisor 1k/2k), solo en el montaje real |
| D8 | Buzzer + |
| D9 | Transistor de la bomba (base, por 1 kΩ) |
| D10 | Transistor del motor de volteo (base, por 1 kΩ) |

**Sensor de gas de Tinkercad (6 patas):** H1 → 5V, A1 → 5V, H2 → GND, B1 → A2 (o A3), y B1 también a GND por una **resistencia de 1 kΩ**. Si en reposo ya marca más de 600, prueba 470 Ω.
**Módulo MQ real (4 pines):** VCC → 5V, GND → GND, AO → A2 / A3. DO queda libre.

**LCD 16x2 (sus pines: GND VDD VO RS RW E D0–D7 BLA BLK)**
| Pin | Va a |
|---|---|
| GND | GND |
| VDD | 5V |
| VO | Pata central del potenciómetro (las otras dos a 5V y GND) |
| RS | D12 |
| RW | GND |
| E | D11 |
| D0–D3 | sin conectar |
| D4 / D5 / D6 / D7 | D5 / D4 / D3 / D2 |
| BLA (luz +) | 5V por 220 Ω |
| BLK (luz −) | GND |

**Bomba (D9) y motor de volteo (D10)**: se arman dos veces iguales.
```
  +12 V ──────────────────┬──────────────┬──────────────┐
                          │              │              │ (+)
                     (banda/cátodo)      │         CONDENSADOR
                        DIODO        BOMBA/MOTOR    470 µF / 25 V
                        1N4007          12 V            │ (−)
                          │              │              │
                          └──────┬───────┘              │
                                 │ Colector (TIP120)    │
   D9 ───[ 1 kΩ ]────────── Base │                      │
                                 │ Emisor               │
   GND Arduino ──────────────────┴──────────────────────┴─── − fuente 12 V
```
- El **diodo** va con la banda hacia +12 V. Si no lo ponen, el pico del motor quema el transistor.
- El **condensador** tiene que ser de **25 V o más**, porque uno de 16 V explota a 12 V. Va de +12 V a GND, respetando la polaridad.
- El TIP120, visto de frente (letras hacia ti), tiene las patas: **B C E**.
- **El GND de la fuente de 12 V se une al GND del Arduino.**

### 5.3 Probar en Tinkercad
Pon `#define MODO_PRUEBA 1` para que los tiempos sean 10 veces más cortos y mueve las barras de los sensores durante la simulación:

| Prueba | Debe pasar |
|---|---|
| Humedad < 30 % | Gira "Bomba", suena el buzzer, la LCD dice REGANDO |
| Humedad ≥ 66 % | Para la bomba y gira "Volteo" (3 min, o 18 s en prueba) |
| Temperatura > 65 °C o < 40 °C | Riega (si la humedad está por debajo de 66 %) y suena el buzzer |
| Gas > 600 | EMERGENCIA GAS, voltea y pita rápido si no está regando |
| Esperar 8 min (48 s en prueba) | Volteo periódico |

Antes de subirlo al Arduino real, vuelve a poner `MODO_PRUEBA 0`.

## 6. Alimentación del montaje real
```
 Fuente 12 V ─┬─► Bomba y motor (por los transistores)
              └─► LM2596 (ajustado a 5.0 V) ─┬─► pin 5V del UNO
                                             ├─► VCC de los MQ-2 y MQ-135
                                             └─► pin 5V/VIN del ESP32
 Todos los GND unidos.
```
Mientras el UNO esté conectado por USB al PC para cargar el código, no conectes también el LM2596 al pin 5V.

## 7. Cambiar TMP36 por DS18B20 (montaje real)
Instala las librerías **OneWire** y **DallasTemperature**. Conexión: rojo → 5V, negro → GND, amarillo → A1, y 4.7 kΩ entre amarillo y 5V.
```cpp
#include <OneWire.h>                 // junto a los otros #include
#include <DallasTemperature.h>
OneWire oneWire(A1);
DallasTemperature sensorTemp(&oneWire);

sensorTemp.begin();                  // en setup(), después de lcd.begin(16, 2);

// en leerSensores(), en lugar de las 2 líneas del TMP36:
sensorTemp.requestTemperatures();
temperatura = sensorTemp.getTempCByIndex(0);   // -127 = desconectado
```

## 8. Ubicación en la caneca
- **Humedad y temperatura**: en la pared interior, a media altura. Dejen las aspas a 3–4 cm de la pared y saquen el cable por un agujero sellado con silicona.
- **MQ-2 y MQ-135**: arriba, donde salen los gases. Pónganles una rejilla y protéjanlos del agua de la manguera.
- **Electrónica** (UNO, ESP32, LCD, buzzer, LM2596): en una caja cerrada por fuera. El ESP32 debe quedar al alcance del WiFi.
- **Motor**: debajo, con el eje sellado.

## 9. Reglas del Arduino (se cambian al inicio de `SmartCompost_UNO.ino`)
- **Riego**: humedad < 30 %, o temperatura fuera de 40–65 °C. Se corta al llegar a 66 %, y ahí empieza el volteo post-riego de 3 min.
- **Seguridad de la bomba**: máximo 1 min seguido y 2 min de pausa. Así un sensor dañado no inunda la caneca.
- **Volteo periódico**: cada 8 min, dura 3 min.
- **Gas > 600**: voltea mientras dure. El buzzer suena si no se está regando.
- **LCD**: la fila 1 muestra `H: 45% T: 55.2C` y la fila 2 alterna entre `Gases:310/420` y el estado.
