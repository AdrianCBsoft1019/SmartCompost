# SmartCompost – Prototipo físico (Arduino UNO + ESP32)

Solo se usan los materiales que ya tenemos: Arduino UNO, ESP32, **DHT11**, MQ-2, MQ-135, LCD 16x2, potenciómetro de 10 kΩ, bomba de 12 V, motor de 12 V, transistores, diodos, resistencias, condensador, buzzer, protoboard y jumpers.

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
1. El UNO manda cada 2 s: `{"humedad":72,"temperatura":28.0,"mq2":310,"mq135":420,...,"estado":"VOLTEANDO"}`
2. El ESP32 le agrega `"codigo_dispositivo":"ESP32-01"` y la sube cada 30 s, o enseguida si cambia el estado (por ejemplo, pasa a REGANDO o a EMERGENCIA GAS).
3. La API busca el **sensor con ese código** y guarda la lectura en **su pila**. Convierte MQ-2 a **CH₄ ppm** y MQ-135 a **CO₂ y NH₃ ppm**, calcula el semáforo y actualiza el estado de la pila.
4. El dashboard, la gráfica de 24 h, las alertas y el análisis muestran **valores reales**.

## 2. Valores con los que trabaja el sistema

El **DHT11** mide las dos cosas a la vez: temperatura **de 0 a 50 °C** y humedad **del aire de 20 a 90 %**. Por eso los umbrales quedaron así:

| Regla | Antes | Ahora (DHT11) |
|---|---|---|
| Riego por humedad baja | < 30 % | < 30 % (igual) |
| Fin del riego y volteo post-riego | ≥ 66 % | ≥ 66 % (igual) |
| Temperatura segura | 40–65 °C | **15–45 °C** |
| Riego por temperatura | > 65 o < 40 °C | **> 45 o < 15 °C** |
| Gas de emergencia | > 600 | > 600 (igual) |
| Volteos | 3 min post-riego / cada 8 min | igual |

- **45 °C** como máximo deja margen antes de los 50 °C, que es lo máximo que lee el DHT11.
- **15 °C** como mínimo evita que la bomba se active cada noche por el frío. Si la caneca queda en un lugar más templado, pueden subirlo.
- La humedad que mide el DHT11 es **la del aire dentro de la caneca**, no la de la tierra, pero sube y baja con el compost.
- Todos estos valores se cambian al inicio de `SmartCompost_UNO.ino` (`TEMP_MIN`, `TEMP_MAX`, `HUM_MIN`…).

**Si el DHT11 deja de responder** (cable suelto), después de 3 intentos:
- La LCD muestra `Revisar DHT11` y el buzzer suena.
- La bomba no se enciende por humedad o temperatura.
- No se envían datos a la página.

El volteo periódico y la emergencia de gas siguen funcionando.

> **Ojo con los límites de la página:** `backend/app/pila_service.py` (`LIMITES`) y algunas pantallas de Flutter todavía usan humedad 40–65 % y temperatura máxima de 70 °C. Si quieren que la página use los mismos valores del aparato, hay que cambiarlos allí también.

## 3. Poner a funcionar el enlace con la página (paso a paso)

1. **Servidor**: en el `.env` de la raíz pon una clave propia para el ESP32:
   ```
   IOT_API_KEY=una-clave-larga-que-inventen
   ```
   y levanta todo con `docker compose up --build`.
2. **IP del computador**: en Windows ejecuta `ipconfig` y busca la "Dirección IPv4" (por ejemplo `192.168.1.50`). El ESP32 y el computador deben estar en **la misma red WiFi**. Prueba desde el celular, conectado a esa red, que `http://192.168.1.50/api/health` responde. Si no responde, permite el puerto 80 en el Firewall de Windows.
3. **Registrar el dispositivo en la página**: entra como instructor, ve a **Sensores → Nuevo**, código `ESP32-01`, tipo *temperatura*, y elige la pila (la caneca).
4. **Firmware del ESP32**: en `SmartCompost_ESP32.ino` cambia `WIFI_SSID`, `WIFI_PASSWORD`, `SERVER_URL` (con la IP del paso 2), `API_KEY` (igual a `IOT_API_KEY`) y `CODIGO_DISPOSITIVO`.
5. Abre el Monitor Serie del ESP32 (115200 baudios). Debe salir `API: lectura guardada (201)`. Si no:

| Mensaje | Causa |
|---|---|
| `401` | `API_KEY` distinta de `IOT_API_KEY` |
| `404` | No hay un sensor con ese código en la página |
| `409` | El sensor está marcado como inactivo |
| `422` | Dato fuera de rango |
| `503` | El servidor no tiene `IOT_API_KEY` |
| `Sin conexión con el servidor` | IP mal escrita, otra red WiFi o firewall |

También puedes probar la API sin el ESP32 desde `http://localhost/docs` → **IoT (ESP32)** → `POST /iot/lecturas`.

## 4. Calibrar los sensores de gas

Los MQ dan un número de 0 a 1023. El servidor lo pasa a ppm con la fórmula del datasheet, y para eso necesita el **R0** de cada sensor:

1. Deja los MQ encendidos unas horas la primera vez. Luego, en **aire limpio** (lejos del compost), mira en el Monitor Serie del UNO los valores `mq2` y `mq135`.
2. Entra a `http://localhost/docs` → `GET /iot/calibracion?mq2=VALOR&mq135=VALOR` (con la `X-API-Key`).
3. Copia la respuesta en el `.env` (`MQ2_R0_KOHM`, `MQ135_R0_KOHM`; `MQ_RL_KOHM=10`, o `1` si la resistencia de la plaquita dice "102") y ejecuta `docker compose up -d`.

Sin calibrar, los ppm **no son confiables** (por ejemplo, el NH₃ puede salir alto y poner la pila en rojo). El umbral de 600 del Arduino no depende de esto: usa el número crudo.

## 5. Circuito en Tinkercad

Tinkercad **no tiene DHT11 ni ESP32**. Por eso allí se simula así, y en el código se deja `#define USAR_DHT11 0`:

| Real | En Tinkercad |
|---|---|
| DHT11 (humedad) | **Potenciómetro** en A0 (girarlo = cambiar la humedad de 0 a 100 %) |
| DHT11 (temperatura) | **Sensor de temperatura TMP36** en A1 |
| MQ-2 / MQ-135 | **Sensor de gas** × 2 |
| Bomba y motor 12 V | **Motor de CC** × 2 (rotulados "Bomba" y "Volteo") |
| Fuente 12 V | **Fuente de alimentación** ajustada a 12 V |
| Transistores | Transistor NPN (BJT) × 2, con resistencia de base de 470 Ω o 1 kΩ |
| LCD 16x2 | LCD 16 x 2 (la normal) + **potenciómetro 10 kΩ** para el contraste |
| Buzzer | Piezo |

### 5.1 Conexiones del UNO
| Pin UNO | Tinkercad | Montaje real |
|---|---|---|
| 5V / GND | Rieles + / − de la protoboard | Igual |
| A0 | Pata central del potenciómetro de humedad (extremos a 5V y GND) | **DATA del DHT11** |
| A1 | Vout del TMP36 (pata central; izquierda 5V, derecha GND, mirando la cara plana) | Libre |
| A2 | MQ-2 | MQ-2 (AO) |
| A3 | MQ-135 | MQ-135 (AO) |
| D2, D3, D4, D5 | LCD D7, D6, D5, D4 | Igual |
| D11 / D12 | LCD E / LCD RS | Igual |
| D7 | — | ESP32 GPIO16 por divisor 1k/2k |
| D8 | Buzzer + | Igual |
| D9 | Base del transistor de la bomba, por 1 kΩ | Igual |
| D10 | Base del transistor del motor de volteo, por 1 kΩ | Igual |

**DHT11 (real)**
- **Módulo de 3 pines** (en plaquita): `+`/VCC → 5V, `−`/GND → GND, `OUT`/DATA → A0. Ya trae la resistencia.
- **DHT11 suelto de 4 patas** (mirando la rejilla, de izquierda a derecha): 1 VCC → 5V, 2 DATA → A0, 3 sin conectar, 4 GND. Pon además una resistencia de **10 kΩ (o 4.7 kΩ) entre DATA y 5V**.

**Sensor de gas de Tinkercad (6 patas):**
- H1 → 5V, A1 → 5V, H2 → GND.
- B1 → A2 (o A3), y B1 también a GND por una **resistencia de 1 kΩ**.
- Si en reposo ya marca más de 600, prueba con 470 Ω.

**Módulo MQ real (4 pines):** VCC → 5V, GND → GND, AO → A2 / A3. DO queda libre.

**LCD 16x2 (pines: GND VDD VO RS RW E D0–D7 BLA BLK)**
| Pin | Va a |
|---|---|
| GND / VDD | GND / 5V |
| VO | Pata central del **potenciómetro 10 kΩ** (las otras dos a 5V y GND) |
| RS / RW / E | D12 / GND / D11 |
| D0–D3 | sin conectar |
| D4 / D5 / D6 / D7 | D5 / D4 / D3 / D2 |
| BLA (luz +) | 5V por una resistencia de 220 Ω (o la más cercana que tengan, entre 100 y 1 kΩ) |
| BLK (luz −) | GND |

**Bomba (D9) y motor de volteo (D10)**: se arman dos veces iguales.
```
  +12 V ──────────────────┬──────────────┬──────────────┐
                          │              │              │ (+)
                     (banda/cátodo)      │         CONDENSADOR
                         DIODO       BOMBA/MOTOR        │ (−)
                          │             12 V            │
                          └──────┬───────┘              │
                                 │ Colector             │
   D9 ───[ 1 kΩ ]────────── Base │  transistor          │
                                 │ Emisor               │
   GND Arduino ──────────────────┴──────────────────────┴─── − fuente 12 V
```
- **Diodo**: en paralelo con el motor y con la **banda hacia +12 V**. Protege al transistor.
- **Condensador**: lee el voltaje impreso en él. Si dice **25 V o más**, va entre +12 V y GND, respetando la polaridad. Si dice **16 V o menos, no lo pongas en los 12 V**, porque puede explotar. En ese caso, ponlo entre 5V y GND del Arduino, cerca de los MQ.
- **El GND de la fuente de 12 V se une al GND del Arduino.**

### 5.2 Sus motores y su transistor
Según las fotos tienen:
- **Mini bomba de 12 V** (blanca): consume unos 150–300 mA.
- **Motorreductor pequeño de 12 V** (motor plateado con caja de engranajes dorada): unos 50–100 mA girando suave y hasta unos 300–400 mA si se traba.
- **Transistores pequeños de 3 patas, encapsulado TO-92** (negros, con una cara plana).

Con motores así de pequeños, **sí sirven esos transistores**, uno para la bomba y otro para el motor, siempre que sean de los que aguantan 500 mA o más. Miren el código con una linterna o una lupa:

| Código impreso | ¿Sirve? |
|---|---|
| 2N2222 / 2N2222A, S8050, PN2222 | **Sí**, para los dos |
| 2N3904, BC547, BC548 | Solo aguantan 100–200 mA: pueden servir para el motor, pero se calientan con la bomba |
| S8550, 2N3906, BC557 | **No** (son PNP: este circuito no funciona con ellos) |

**Patas del transistor**, mirando la cara plana con las letras hacia ti y las patas hacia abajo:
- 2N2222A, 2N3904 y PN2222: **E B C** (Emisor, Base, Colector) de izquierda a derecha.
- S8050: E B C en la mayoría.
- BC547 y BC548: **C B E**.

Si el código no se lee bien, búsquenlo en internet como "<código> pinout".

- **Resistencia de base:** usen **470 Ω** si tienen. Si no, 1 kΩ. Con 470 Ω el transistor conduce mejor y se calienta menos.
- **Prueba de temperatura:** dejen la bomba encendida 1 minuto y toquen el transistor. Si quema, cambien por otro de los que tengan o bajen la resistencia de base a 330 Ω (no menos).
- **Torque del motor:** este motorreductor tiene poca fuerza. Hagan las aspas livianas y no las llenen de compost apretado. Si el motor se traba, consume más corriente y calienta el transistor.

### 5.3 Probar en Tinkercad
Pon `#define MODO_PRUEBA 1` para que los tiempos sean 10 veces más cortos:

| Prueba | Debe pasar |
|---|---|
| Potenciómetro de humedad < 30 % | Gira "Bomba", suena el buzzer, la LCD dice REGANDO |
| Humedad ≥ 66 % | Para la bomba y gira "Volteo" (18 s en prueba) |
| TMP36 > 45 °C o < 15 °C | Riega (si la humedad está por debajo de 66 %) y suena el buzzer |
| Gas > 600 | EMERGENCIA GAS, voltea y pita rápido si no está regando |
| Esperar 48 s (en prueba) | Volteo periódico |

## 6. Pasar al montaje real
1. En `SmartCompost_UNO.ino` cambia `#define USAR_DHT11 0` a **`1`** y `MODO_PRUEBA` a **`0`**.
2. Conecta el DHT11 a A0 (sección 5.1). El TMP36 y el potenciómetro de humedad no se usan; el potenciómetro queda solo para el contraste de la LCD.
3. No hace falta instalar librerías: el DHT11 se lee con código propio.
4. **Alimentación, sin comprar nada más:**
```
 Fuente 12 V ───► Bomba y motor (por los transistores)
   (sirve un adaptador de 12 V de 1 A, como el de un router o un módem viejo)
 Cargador USB 5 V (de celular, 1 A o más) ───► Arduino UNO (USB) ─► 5V a LCD, DHT11, MQ-2, MQ-135
 Otro cargador USB o el PC ───► ESP32 (USB)
 Todos los GND unidos: Arduino, ESP32 y el − de la fuente de 12 V.
```
   No conecten los 12 V al Arduino: el regulador del UNO se recalienta con los dos MQ conectados.

## 7. Ubicación en la caneca
- **DHT11**: en la pared interior, por encima del compost, mirando hacia adentro. **No lo entierren ni lo mojen**: no es resistente al agua. Pónganle encima un techito o una malla para que no le caiga el agua de la manguera, y dejen las aspas a 3–4 cm de la pared.
- **MQ-2 y MQ-135**: arriba, donde salen los gases, protegidos del agua.
- **Electrónica** (UNO, ESP32, LCD, buzzer): en una caja cerrada por fuera, al alcance del WiFi.
- **Motor**: debajo, con el eje sellado.

## 8. Reglas del Arduino (se cambian al inicio de `SmartCompost_UNO.ino`)
- **Riego**: humedad < 30 %, o temperatura fuera de 15–45 °C. Se corta al llegar a 66 %, y ahí empieza el volteo post-riego de 3 min.
- **Seguridad de la bomba**: máximo 1 min seguido y 2 min de pausa.
- **Volteo periódico**: cada 8 min, dura 3 min.
- **Gas > 600**: voltea mientras dure. El buzzer suena si no se está regando.
- **LCD**: la fila 1 muestra `H: 72% T: 28.0C` y la fila 2 alterna entre `Gases:310/420` y el estado.
