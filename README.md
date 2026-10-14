# SmartCompost

## Estructura

```
smartcompost/
  backend/     -> API en Python (FastAPI) + MySQL + JWT
  frontend/    -> App Flutter (Login/Registro y consumo de la API)
  docker-compose.yml -> Levanta base de datos + backend con un solo comando
```

## Requisitos

- Docker y Docker Compose
- Flutter SDK (solo para correr el frontend)

## 1. Configurar variables de entorno

En la raíz del proyecto (junto a `docker-compose.yml`) crea un archivo `.env` con tu clave secreta de JWT:

```
JWT_SECRET_KEY=pon-aqui-tu-clave-generada
```

> Si no lo creas, `docker-compose.yml` usa por defecto `dev-secret-change-me`, válido solo para pruebas locales, nunca para producción.

`backend/.env.example` es solo de referencia para cuando el backend se corre **sin** Docker (localmente con `uvicorn`); al usar Docker, `docker-compose.yml` ya inyecta esas mismas variables (`DB_HOST`, `DB_PORT`, `DB_NAME`, `DB_USER`, `DB_PASSWORD`, `JWT_SECRET_KEY`, etc.) directamente al contenedor del backend.

## 2. Levantar el proyecto con Docker

Desde la raíz del proyecto:

```bash
docker compose up --build
```

Esto levanta dos contenedores:

- `smartcompost_db` → MySQL 8.0, con la base `smartcompost` creada automáticamente.
- `smartcompost_backend` → API FastAPI en `http://localhost:8000`, esperando a que la base de datos esté lista (`healthcheck`).

Para correrlo en segundo plano: `docker compose up --build -d`. Para detenerlo: `docker compose down` (agrega `-v` si además quieres borrar los datos de MySQL).

## 3. Verificar que el backend quedó arriba

- `http://localhost:8000/` → debe responder `{"status": "ok", ...}`
- `http://localhost:8000/api/health` → debe decir `"database": {"status": "up"}`
- `http://localhost:8000/docs` → documentación interactiva (Swagger) para probar login y los CRUDs de Usuarios, Pilas y Sensores con el token JWT.

## 4. Correr el frontend (Flutter)

```bash
cd frontend
flutter pub get
flutter run -d chrome --dart-define=API_BASE_URL=http://localhost:8000
```

Desde ahí puedes crear una cuenta en la pantalla de Registro e iniciar sesión desde Login; el usuario debe quedar guardado en la tabla `usuarios` de MySQL.

## 5. Modulo Pilas, Analisis y Perfiles (Nareth)

### Datos de demostracion

```bash
docker compose exec backend python -m app.seed
```

Crea 2 usuarios, 4 pilas, sensores y 30 dias de lecturas:

| Rol | Correo | Contrasena |
|-----|--------|------------|
| Administrador (instructor) | admin@smartcompost.com | Admin12345 |
| Estudiante (aprendiz) | estudiante@smartcompost.com | Estudiante123 |

> Si tu base MySQL ya existia, ejecuta antes `backend/migrations/001_pilas_ciclo.sql`
> (o `docker compose down -v` para empezar de cero).

### Endpoints nuevos

| Metodo | Ruta | Rol |
|--------|------|-----|
| GET | `/pilas/?q=&fase=&ubicacion=&estado=` | todos |
| POST / PUT / DELETE | `/pilas/`, `/pilas/{id}` | instructor |
| GET | `/pilas/{id}/detalle` | todos |
| GET / POST | `/pilas/{id}/lecturas` | todos |
| GET | `/analisis/resumen?periodo=semana\|mes\|anio` | todos |
| GET | `/analisis/sensores`, `/analisis/pilas` | todos |
| GET | `/analisis/reporte.pdf?periodo=` | todos |
| GET / PUT | `/usuarios/me` | todos |
| GET / POST / PUT / DELETE | `/usuarios/`, `/usuarios/{id}` | instructor |

Coleccion Postman lista para importar: `docs/SmartCompost_Nareth.postman_collection.json`.

### Pruebas del backend

```bash
cd backend && pip install -r requirements.txt pytest httpx && python -m pytest -q
```

### Foto de perfil

Cada usuario (administrador o estudiante) puede cambiar su foto desde **Mi perfil**
(clic en el avatar): *Cambiar foto* abre el selector de archivos del dispositivo.

- La API acepta PNG, JPG o WEBP de hasta 5 MB, la valida, la recorta a cuadrado y
  la reduce a 256x256 (se guarda como PNG en la base de datos).
- Endpoints: `POST/DELETE/GET /usuarios/me/foto` y `GET /usuarios/{id}/foto`.
- Bases ya creadas: ejecutar una vez `backend/migrations/002_usuario_foto.sql`.
- Frontend: despues de actualizar, correr `flutter pub get` (nueva dependencia `image_picker`).

## 6. Modulo Sensores y Alertas

Documentacion detallada (reglas, limites y ejemplos): [`docs/sensores-y-alertas.md`](docs/sensores-y-alertas.md).

### Sensores

| Metodo | Ruta | Rol |
|--------|------|-----|
| GET | `/sensores/?pila_id=&tipo=&activo=&q=` | todos |
| GET | `/sensores/{id}` | todos |
| POST / PUT / DELETE | `/sensores/`, `/sensores/{id}` | instructor |

- Al crear un sensor la pila debe existir y el `codigo_dispositivo` debe ser unico (3 a 60 caracteres).
- Al eliminar un sensor sus lecturas **se conservan** (`sensor_id` queda en vacio).
- Las respuestas incluyen `pila_nombre` y `ubicacion` de la pila del sensor.

### Alertas

Una alerta aparece cuando una lectura supera los limites de una variable (temperatura, humedad, CO2, CH4 o NH3). Es de solo lectura para instructor y estudiante.

| Metodo | Ruta | Rol |
|--------|------|-----|
| GET | `/alertas/?periodo=&pila_id=&variable=&solo_activas=&limite=` | todos |
| GET | `/alertas/resumen?periodo=semana\|mes\|anio` | todos |
| GET | `/alertas/reporte.pdf?periodo=semana\|mes\|anio` | todos |

### Pantallas (Flutter)

- **Sensores**: listado con filtros; el administrador crea, edita, desactiva y elimina, el estudiante solo consulta.
- **Alertas**: selector de periodo, tarjetas de resumen, graficas (por dia, variable, pila y sensor), historial con filtros y boton **Descargar PDF**. Es igual para administrador y estudiante.

Para probar los endpoints sin Postman usa Swagger en `http://localhost:8000/docs`: inicia sesion en `/auth/login`, pulsa **Authorize** con el token y prueba `/sensores` y `/alertas`.

## 7. Pruebas y calidad de codigo

Desde `backend/`:

```bash
pip install -r requirements.txt pytest httpx black flake8
python -m pytest -q      # pruebas (usan SQLite temporal, no necesitan MySQL)
black --check app        # formato
flake8 app               # estilo (max-line-length = 88)
```

Si Black marca archivos, corrigelos con `black app` y sube solo tus archivos.

El workflow `.github/workflows/ci.yml` corre estos mismos tres pasos en cada push y pull request hacia `main`.

## 8. Dashboard, Historial e Integración Final 

### Dashboard Principal (Administrador)

El dashboard principal permite al administrador consultar el estado general del sistema Smart Compost y visualizar información importante sobre las pilas de compostaje y los sensores registrados.

**Funcionalidades principales:**

- Visualización de gráficas con las tendencias de temperatura y gases de las pilas de compostaje.
- Panel lateral con un resumen del estado de las pilas y un botón **"Ver todas"** para consultar el listado completo.
- Tabla con información de los sensores activos y sus últimas lecturas disponibles.
- Integración con la API para consultar los datos registrados en el sistema.
- Organización de la información para facilitar el seguimiento del proceso de compostaje.

### Historial de Acciones e Intervenciones

El módulo de historial de acciones e intervenciones permite consultar y organizar las actividades realizadas durante el seguimiento de las pilas de compostaje.

**Funcionalidades contempladas:**

- Consulta del historial de acciones e intervenciones asociadas a las pilas.
- Visualización de información como la pila relacionada, el técnico responsable, la fecha, el tipo de acción y su estado.
- Filtros para facilitar la búsqueda por técnico, fecha y estado.
- Identificación visual de los estados de las intervenciones.
- Generación y descarga de reportes en formato PDF.

**Nota de implementación:** La vista actual genera registros de ejemplo asociados a las pilas existentes. Para completar el CRUD del historial, es necesario conectar las operaciones de creación, consulta y actualización con un endpoint persistente en el backend y la base de datos. Los filtros y el reporte deben utilizar los registros reales disponibles.

### Flujos End-to-End e Integración con la API

La integración final busca garantizar la comunicación entre el frontend desarrollado en Flutter, la API construida con FastAPI y la base de datos utilizada por Smart Compost.

**Actividades de integración:**

- Unificación de las solicitudes realizadas desde el frontend hacia los endpoints de la API.
- Validación de las respuestas recibidas y del manejo de errores de comunicación.
- Verificación de la carga de información en los módulos del dashboard, pilas, sensores y alertas.
- Implementación o revisión de los estados de carga y de los mensajes cuando ocurre un error.
- Pruebas de los flujos completos desde la interfaz hasta la API y la base de datos.
- Documentación de las actividades y los resultados correspondientes al Sprint Planning 4.

#### Verificación del backend

El endpoint de salud permite comprobar el estado de la API y de la conexión con la base de datos configurada.

**Endpoint:** `GET /api/health`

Para consultar su respuesta localmente, ejecutar:

```powershell
Invoke-RestMethod http://127.0.0.1:8000/api/health | ConvertTo-Json -Depth 5
```

Durante las pruebas locales se obtuvo una respuesta con estado `ok` y base de datos `up`. En esa ejecución, el backend estaba configurado para utilizar SQLite; por lo tanto, esta verificación no demuestra por sí sola que la conexión con MySQL mediante Docker Compose esté funcionando.

#### Ejecución del proyecto en entorno local

**Terminal 1 — Backend**

```powershell
cd backend
python -m uvicorn app.main:app --reload
```

**Terminal 2 — Frontend**

```powershell
cd frontend
flutter pub get
flutter run -d chrome --dart-define=API_BASE_URL=http://localhost:8000
```

Antes de iniciar las pruebas de integración, verificar que la API esté activa y que el frontend utilice la URL correcta del backend.

#### Pruebas automatizadas

Desde la carpeta `backend`, ejecutar:

```powershell
python -m pytest -q
```

En una ejecución local se obtuvo el siguiente resultado:

```text
32 passed, 851 warnings
```

Las 32 pruebas finalizaron correctamente. Los avisos corresponden a advertencias de compatibilidad y uso de funciones o configuraciones que pueden requerir actualización. El resultado debe interpretarse como evidencia de esa ejecución de pruebas, no como una validación de todos los flujos de la aplicación ni de la conexión con MySQL.

## Sprint Planning 4

El trabajo de este sprint se centra en integrar las funcionalidades del dashboard, el historial de intervenciones y la comunicación entre el frontend, la API y la base de datos.

**Objetivos del sprint:**

- Consolidar la visualización de las lecturas y los estados de las pilas.
- Conectar el historial de acciones con los datos persistentes del sistema.
- Facilitar la búsqueda de intervenciones y la descarga de reportes en PDF.
- Verificar los flujos completos de comunicación entre los módulos de Flutter y los servicios del backend.
- Ejecutar pruebas de funcionamiento y documentar los resultados.

**Criterios de aceptación:**

- El dashboard presenta información obtenida de la API.
- Los datos de sensores y pilas se visualizan correctamente cuando están disponibles.
- El historial permite consultar registros reales y realizar las operaciones implementadas.
- Los filtros y el reporte PDF funcionan con la información consultada.
- Se validan los flujos principales entre frontend, backend y base de datos.
- Los errores de comunicación se manejan sin bloquear la interfaz.
- Se documentan las pruebas ejecutadas y las funcionalidades que continúan pendientes.
