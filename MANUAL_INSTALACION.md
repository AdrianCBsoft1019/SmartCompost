# 🛠️ Manual de Instalación y Despliegue — SmartCompost

## 1. Descripción del Proyecto

Este documento describe, paso a paso, cómo clonar y desplegar la **API de SmartCompost** (sistema de monitoreo de pilas de compostaje del Centro de Biotecnología Agropecuaria SENA Mosquera) en un clúster local de **Alta Disponibilidad** con Docker Compose.

La arquitectura incluye:

- **4 réplicas idénticas** del backend detrás de un balanceador de carga.
- **Límites de recursos** (CPU y RAM) por contenedor.
- **Healthchecks** para que Docker detecte réplicas caídas.
- **Observabilidad** de logs en tiempo real con Dozzle.
- **Pruebas de carga** con Locust.

> ⚠️ Siga los pasos **en el orden indicado** y copie los comandos tal como aparecen. Todos los comandos se ejecutan desde la **raíz del repositorio** (la carpeta donde está `docker-compose.yml`), salvo que se indique lo contrario.

---

## 2. Arquitectura del Sistema

```
                 ┌──────────────────────────┐
  Navegador /    │  Nginx (load-balancer)   │
  Locust  ─────► │  http://localhost:80     │
                 └────────────┬─────────────┘
                              │ round-robin
        ┌──────────────┬──────┴───────┬──────────────┐
        ▼              ▼              ▼              ▼
   backend #1     backend #2     backend #3     backend #4
   (FastAPI +     (FastAPI +     (FastAPI +     (FastAPI +
    Uvicorn)       Uvicorn)       Uvicorn)       Uvicorn)
   :8000 interno  :8000 interno  :8000 interno  :8000 interno
        └──────────────┴──────┬───────┴──────────────┘
                              ▼
                     ┌──────────────────┐
                     │  MySQL 8.0 (db)  │
                     │  :3306           │
                     └──────────────────┘

  Dozzle  (visor de logs)      → http://localhost:8080
  Locust  (pruebas de carga)   → http://localhost:8089
```

| Servicio (`docker-compose.yml`) | Imagen / Tecnología | Puerto en el host | Puerto interno | Función |
|---|---|---|---|---|
| `load-balancer` | `nginx:alpine` | **80** | 80 | Proxy inverso y balanceador de carga hacia las 4 réplicas |
| `backend` | Build de `./backend` (Python 3.12, FastAPI + Uvicorn) | — (no se publica) | 8000 | API REST de SmartCompost, **4 réplicas** |
| `db` | `mysql:8.0` | 3306 | 3306 | Base de datos `smartcompost` (volumen persistente `smartcompost_db_data`) |
| `dozzle` | `amir20/dozzle` | **8080** | 8080 | Visor de logs de todos los contenedores en tiempo real |
| `locust` | `locustio/locust` | **8089** | 8089 | Generador de carga contra Nginx (`locustfile.py`) |

**Endpoint de salud de la API:** `GET /api/health` → responde `{"status": "ok", ..., "database": {"status": "up"}}` cuando la API y la conexión a MySQL funcionan.

### Archivos de infraestructura que debe contener el repositorio

| Archivo | Para qué sirve |
|---|---|
| `docker-compose.yml` | Define los 5 servicios, las 4 réplicas (`deploy.replicas: 4`), límites de recursos y healthchecks |
| `nginx.conf` | Configuración del balanceador (`upstream` apuntando a `backend:8000`) |
| `locustfile.py` | Escenario de carga (health, login y consulta de pilas) |
| `backend/Dockerfile` | Imagen de la API |
| `backend/requirements.txt` | Dependencias Python |
| `.env.example` | Plantilla de variables de entorno |

---

## 3. Prerrequisitos de Software

Antes de iniciar, asegúrese de tener instalado:

| Software | Versión mínima | Cómo verificar |
|---|---|---|
| **Docker Engine** (o Docker Desktop) | 20.10 | `docker --version` |
| **Docker Compose** (plugin v2, comando `docker compose` con espacio) | 2.0 | `docker compose version` |
| **Git** | 2.x | `git --version` |
| **curl** (para smoke tests) | cualquiera | `curl --version` |

- **Sistema Operativo probado:** Windows 10/11 con Docker Desktop (backend WSL2) o Linux Ubuntu 22.04.
- **Recursos mínimos de la máquina:** 4 GB de RAM libres para Docker y 2 núcleos de CPU.
- **Puertos libres en el host:** `80`, `3306`, `8080` y `8089`. Si alguno está ocupado (por ejemplo, un MySQL o XAMPP local en el 3306, o IIS/Apache en el 80) deténgalo antes de continuar. Ver la sección [8. Problemas frecuentes](#8-problemas-frecuentes-durante-la-instalación).
- **Docker Desktop debe estar abierto y en estado "Running"** antes de ejecutar cualquier comando `docker`.

> En Windows use **PowerShell** o **Git Bash**. Los comandos `curl` de este manual funcionan en Git Bash; en PowerShell use `curl.exe` (con `.exe`) para no invocar el alias `Invoke-WebRequest`.

---

## 4. Pasos de Instalación

### Paso 1: Clonar el repositorio

```bash
git clone https://github.com/AdrianCBsoft1019/SmartCompost.git
```

```bash
cd SmartCompost
```

Si el equipo entregó una rama específica para la prueba, cámbiese a ella (si no, omita este comando y quédese en `main`):

```bash
git checkout <nombre-de-la-rama>
```

### Paso 2: Configuración de Variables de Entorno

Copie la plantilla de variables a un archivo `.env` en la raíz del proyecto:

```bash
cp .env.example .env
```

*(En PowerShell: `Copy-Item .env.example .env`)*

Abra `.env` con cualquier editor (`nano .env`, `notepad .env`, VS Code…) y revise los valores:

| Variable | Valor por defecto | Descripción |
|---|---|---|
| `DB_NAME` | `smartcompost` | Nombre de la base de datos que MySQL crea al iniciar |
| `JWT_SECRET_KEY` | `dev-secret-change-me` | Clave para firmar los tokens de inicio de sesión. **Cámbiela** fuera de pruebas locales |

> Las variables de conexión del backend a la BD (`DB_HOST=db`, `DB_PORT=3306`, `DB_USER=root`, `DB_PASSWORD` vacío) ya se inyectan desde `docker-compose.yml`; **no** es necesario editarlas.
>
> El archivo `backend/.env.example` es solo para correr el backend **sin Docker**; no se usa en este despliegue.

Para generar una clave segura (opcional):

```bash
python -c "import secrets; print(secrets.token_urlsafe(32))"
```

### Paso 3: Despliegue de la Infraestructura

Construya las imágenes y levante todos los servicios en segundo plano:

```bash
docker compose up --build -d
```

Qué ocurre en este paso (tarda de 1 a 5 minutos la primera vez porque descarga imágenes e instala dependencias):

1. Se descarga `mysql:8.0` y arranca `db`. Su healthcheck (`mysqladmin ping`) debe pasar antes de que arranque el backend.
2. Se construye la imagen del backend y se crean **4 contenedores** (`smartcompost-backend-1` … `smartcompost-backend-4`). Al iniciar, la API crea automáticamente las tablas en MySQL.
3. Arranca `load-balancer` (Nginx), que reparte el tráfico entre las 4 réplicas.
4. Arrancan `dozzle` y `locust`.

Espere unos **30 segundos** y continúe con la verificación.

### Paso 4: Cargar datos de demostración (recomendado)

Ejecute **una sola vez** el script de datos de prueba dentro de una de las réplicas:

```bash
docker compose exec --index 1 backend python -m app.seed
```

Esto crea 4 pilas, sus sensores, 30 días de lecturas y estos usuarios:

| Rol | Correo | Contraseña |
|---|---|---|
| Administrador (instructor) | `admin@smartcompost.com` | `Admin12345` |
| Estudiante (aprendiz) | `estudiante@smartcompost.com` | `Estudiante123` |

> Como las 4 réplicas comparten la misma base MySQL, basta con ejecutarlo en una sola (`--index 1`).

---

## 5. Verificación de Despliegue (Smoke Tests)

Ejecute los siguientes comandos para confirmar que el sistema está operativo.

**1. Verificar estado de contenedores:**

```bash
docker compose ps
```

Resultado esperado: **8 contenedores** en estado `Up`:

| Contenedor | Estado esperado |
|---|---|
| `smartcompost-db-1` | `Up (healthy)` |
| `smartcompost-backend-1` … `smartcompost-backend-4` | `Up (healthy)` |
| `smartcompost-load-balancer-1` | `Up` |
| `smartcompost-dozzle-1` | `Up` |
| `smartcompost-locust-1` | `Up` |

*(Si alguna réplica aparece `health: starting`, espere 20 segundos y repita. Si aparece `unhealthy` o `Restarting`, consulte el `RUNBOOK_INCIDENTES.md`).*

**2. Prueba de conectividad de la API a través del balanceador:**

```bash
curl -i http://localhost/api/health
```

Debe devolver `HTTP/1.1 200 OK` y un JSON similar a:

```json
{"status":"ok","timestamp":"2026-11-04T19:00:00Z","uptime_seconds":42.1,"database":{"status":"up","error":null}}
```

> ⚠️ Si el JSON dice `"status":"degraded"` y `"database":{"status":"down"}`, la API está arriba pero **no** conecta a MySQL (ver Incidente 4 del Runbook).

**3. Verificar que el balanceo reparte entre las 4 réplicas:**

```bash
docker compose logs backend --tail=5
```

Repita el `curl` del punto 2 unas 8 veces y vuelva a ejecutar el comando anterior: deben aparecer líneas `GET /api/health HTTP/1.1" 200 OK` con prefijos de **distintas réplicas** (`backend-1`, `backend-2`, `backend-3`, `backend-4`).

**4. Prueba funcional de inicio de sesión (requiere el Paso 4):**

```bash
curl -i -X POST http://localhost/auth/login -H "Content-Type: application/json" -d "{\"correo\":\"admin@smartcompost.com\",\"password\":\"Admin12345\"}"
```

Debe devolver `HTTP/1.1 200 OK` con un `access_token`.

**5. Acceso a consolas de administración (en el navegador):**

| Consola | URL | Qué debe ver |
|---|---|---|
| Documentación de la API (Swagger) | `http://localhost/docs` | Lista de endpoints de SmartCompost |
| Visor de Logs (Dozzle) | `http://localhost:8080` | Los 8 contenedores en el panel izquierdo |
| Panel de Pruebas (Locust) | `http://localhost:8089` | Formulario "Start new load test" |

**6. Ejecutar una prueba de carga corta con Locust:**

1. Abra `http://localhost:8089`.
2. Configure: **Number of users** = `50`, **Ramp up** = `5`, **Host** = `http://load-balancer` (ya viene precargado).
3. Pulse **Start** y deje correr 1–2 minutos.
4. Criterio de aceptación: la columna **Failures** debe mantenerse en **0 %** y las 4 réplicas deben seguir `healthy` en `docker compose ps`.

---

## 6. Comandos de Operación Diaria

| Acción | Comando |
|---|---|
| Ver logs de las réplicas en terminal | `docker compose logs -f backend` |
| Ver logs del balanceador | `docker compose logs -f load-balancer` |
| Ver consumo de CPU/RAM en vivo | `docker stats` |
| Reiniciar solo el balanceador | `docker compose restart load-balancer` |
| Apagar el entorno (conserva los datos de MySQL) | `docker compose down` |
| Apagar y **borrar** los datos de MySQL | `docker compose down -v` |
| Cambiar el número de réplicas sin editar el archivo | `docker compose up -d --scale backend=6` |

**Actualizar el backend tras un cambio de código:**

```bash
git pull
```

```bash
docker compose up --build -d --no-deps backend
```

Después del cambio, reinicie Nginx para que resuelva las IP de las réplicas nuevas:

```bash
docker compose restart load-balancer
```

> ℹ️ **Nota sobre "Zero-Downtime":** en Docker Compose (sin Swarm) la sección `deploy.update_config` (`parallelism`, `order: start-first`) **no se aplica**; Compose recrea las réplicas del servicio. Para minimizar el corte, Nginx reintenta en otra réplica (`proxy_next_upstream`) y el tiempo de indisponibilidad suele ser de pocos segundos. Verifíquelo corriendo Locust durante la actualización.

---

## 7. Desinstalación completa

```bash
docker compose down -v --rmi local
```

Elimina los contenedores, la red, el volumen de MySQL y las imágenes construidas localmente.

---

## 8. Problemas frecuentes durante la instalación

| Síntoma | Causa probable | Solución |
|---|---|---|
| `Bind for 0.0.0.0:3306 failed: port is already allocated` | Hay un MySQL/XAMPP local corriendo | Deténgalo, o cambie en `docker-compose.yml` el mapeo de `db` a `"3307:3306"` |
| `Bind for 0.0.0.0:80 failed` | IIS, Apache u otro servidor usa el puerto 80 | Deténgalo, o cambie el mapeo de `load-balancer` a `"8082:80"` y use `http://localhost:8082` en los smoke tests |
| `Cannot connect to the Docker daemon` / `error during connect` | Docker Desktop está cerrado | Abra Docker Desktop y espere a que diga "Running" |
| `docker-compose: command not found` | Se usa Compose v1 | Use `docker compose` (con espacio) o actualice Docker |
| `curl http://localhost/api/health` → `502 Bad Gateway` justo después de levantar | Las réplicas aún están iniciando o esperando a MySQL | Espere 30 s y repita; si persiste, ver Incidente 1 del Runbook |
| Una réplica queda `Restarting` en el primer arranque | Las 4 réplicas intentaron crear las tablas al mismo tiempo | Se recupera sola por `restart: unless-stopped`; si no, `docker compose restart backend` |
| El login devuelve `401` | No se cargaron los datos de demostración | Ejecute el Paso 4 |

Para cualquier fallo **después** de una instalación correcta, consulte `RUNBOOK_INCIDENTES.md`.
