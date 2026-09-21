# SmartCompost — Backend (Sprint 1 y 2 + Módulo Transversal)

API en **Python (FastAPI)** conectada a **MySQL vía XAMPP**, con autenticación
por roles (HU-10), CRUDs base de **Usuarios**, **Pilas** y **Sensores**, y el
Módulo Transversal (**Health Check** + tabla de trazabilidad **system_logs**).

## 1. Preparar la base de datos con XAMPP

1. Abre el **Panel de Control de XAMPP** y enciende **Apache** y **MySQL**.
2. Ve a `http://localhost/phpmyadmin`.
3. Click en **Nueva** (panel izquierdo) → escribe el nombre `smartcompost` → **Crear**.
   - No necesitas crear tablas a mano: la API las crea solas la primera vez que arranca.
4. Si tu MySQL de XAMPP tiene usuario/contraseña distintos al default
   (`root` sin contraseña), anótalos para el paso siguiente.

## 2. Preparar y correr el backend

```bash
cd backend
python -m venv venv
source venv/bin/activate        # Windows: venv\Scripts\activate

pip install -r requirements.txt

cp .env.example .env            # Windows: copy .env.example .env
# Si tu XAMPP usa otro usuario/contraseña de MySQL, edítalos en .env

uvicorn app.main:app --reload
```

La API queda en `http://localhost:8000` y la documentación interactiva
(Swagger) en `http://localhost:8000/docs`.

**Verifica la conexión** abriendo `http://localhost:8000/api/health` — si todo
está bien verás `"database": {"status": "up"}`.

## 3. Probar Login/Registro conectados a la base de datos

Desde Swagger (`/docs`) o desde la app Flutter:

1. `POST /auth/register` con un correo, contraseña (mín. 8 caracteres) y rol.
2. Verifica en phpMyAdmin → base `smartcompost` → tabla `usuarios` que el
   registro quedó guardado (la contraseña se ve como hash bcrypt, nunca en
   texto plano).
3. `POST /auth/login` con esas mismas credenciales → debe devolver un `access_token`.
4. Si pones una contraseña incorrecta a propósito, revisa la tabla
   `system_logs` en phpMyAdmin: debe aparecer un registro `WARNING` con el
   intento fallido (Módulo Transversal).

## 4. Endpoints disponibles

| Método | Ruta                       | Descripción                          | Rol requerido        |
|--------|----------------------------|---------------------------------------|-----------------------|
| GET    | `/api/health`               | Health check + ping a BD + uptime    | Público               |
| POST   | `/auth/register`           | Registro de usuario (HU-10)          | Público               |
| POST   | `/auth/login`               | Login, devuelve JWT (HU-10)          | Público               |
| GET    | `/auth/me`                  | Perfil del usuario autenticado       | Autenticado           |
| GET    | `/usuarios/`                | Listar usuarios                      | Instructor            |
| PATCH  | `/usuarios/{id}/rol`        | Cambiar rol de un usuario            | Instructor            |
| DELETE | `/usuarios/{id}`            | Desactivar usuario                   | Instructor            |
| POST/GET/PUT/DELETE | `/pilas/`      | CRUD de pilas de compostaje          | Autenticado (delete: Instructor) |
| POST/GET/PUT/DELETE | `/sensores/`   | CRUD de sensores por pila            | Autenticado (delete: Instructor) |

## 5. Módulo Transversal (Health Check y Trazabilidad)

**`GET /api/health`** — devuelve:
```json
{
  "status": "ok",
  "timestamp": "2026-09-17T20:00:00Z",
  "uptime_seconds": 134.5,
  "database": { "status": "up", "error": null }
}
```
Ejecuta un `SELECT 1` real contra MySQL para confirmar que la conexión está
viva. Si falla (ej. apagaste MySQL en XAMPP), `status` pasa a `"degraded"` y
el incidente queda registrado automáticamente en `system_logs`.

**Tabla `system_logs`** (independiente, sin llaves foráneas — `app/log_model.py`):

| Campo       | Tipo      | Descripción                              |
|-------------|-----------|-------------------------------------------|
| id          | CHAR(36)  | PK (UUID como texto)                      |
| fecha_hora  | DateTime  | Momento del evento                        |
| nivel       | Enum      | INFO / WARNING / ERROR                    |
| origen_ip   | String    | IP del cliente que originó el evento      |
| mensaje     | String    | Descripción del evento                    |

Se inserta automáticamente en dos casos (`app/log_service.py`):
- **Login fallido** (contraseña incorrecta o correo inexistente) en `POST /auth/login`.
- **Error de conexión/consulta a la BD**, capturado en la dependencia `get_db`
  y en el propio `/api/health`.

Si el propio intento de insertar el log falla (por ejemplo, apagaste MySQL
por completo), el evento se escribe como respaldo en `backend/fallback.log`.

## 6. Estructura del repositorio

```
backend/
  app/
    main.py            # arranque de FastAPI, monta routers y /api/health
    database.py         # conexión a MySQL/XAMPP (SQLAlchemy + PyMySQL)
    models.py            # entidades del MER (Usuario, Pila, Sensor)
    log_model.py           # tabla system_logs (trazabilidad ciega)
    log_service.py           # inserta eventos en system_logs (con fallback)
    schemas.py                # validación de entrada/salida (Pydantic)
    security.py                 # hashing bcrypt + JWT + control de roles
    routers/
      auth.py, usuarios.py, pilas.py, sensores.py
  requirements.txt
  .env.example
```

## 7. Flujo de Git recomendado (evidencia de commits atados a HU)

```bash
git init
git checkout -b develop

git add app/database.py
git commit -m "HU-10: configura conexion a MySQL (XAMPP)"

git add app/models.py app/schemas.py
git commit -m "HU-10: modela entidades Usuario, Pila y Sensor (MER)"

git add app/security.py app/routers/auth.py
git commit -m "HU-10: implementa registro/login con hash bcrypt y JWT"

git add app/routers/pilas.py app/routers/sensores.py
git commit -m "ep-01: CRUD basico de Pilas y Sensores"

git add app/log_model.py app/log_service.py app/main.py
git commit -m "modulo-transversal: health check y tabla system_logs"
```
