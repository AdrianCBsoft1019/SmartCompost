# 🚨 Runbook de Operaciones e Incidentes — SmartCompost (RAP 1)

**Propósito:** Guía de acción rápida para el equipo de Guardia/SRE frente a fallos del entorno de producción local de SmartCompost (4 réplicas de FastAPI detrás de Nginx, MySQL, Dozzle y Locust).

**Referencia rápida del entorno:**

| Elemento | Valor |
|---|---|
| Servicio del backend (4 réplicas) | `backend` (contenedores `smartcompost-backend-1` … `-4`, puerto interno `8000`) |
| Balanceador | `load-balancer` (Nginx, `http://localhost`) |
| Base de datos | `db` (MySQL 8.0, base `smartcompost`) |
| Logs en tiempo real | Dozzle → `http://localhost:8080` |
| Pruebas de carga | Locust → `http://localhost:8089` |
| Endpoint de salud | `GET http://localhost/api/health` |
| Tabla de logs de la aplicación | `system_logs` (errores de BD con prefijo `[DB]`, logins fallidos) |

**Flujo general ante cualquier alerta:**

1. `docker compose ps` → ¿qué contenedor no está `Up (healthy)`?
2. `curl -i http://localhost/api/health` → ¿qué código HTTP y qué `database.status` devuelve?
3. Dozzle (`http://localhost:8080`) → buscar el error en el contenedor afectado.
4. Ubicar el síntoma en la tabla siguiente y aplicar el procedimiento.

| Síntoma principal | Ir a |
|---|---|
| HTTP **502 Bad Gateway** | [Incidente 1](#-incidente-1-errores-502-bad-gateway-intermitentes-o-totales) |
| Contenedores que se detienen solos bajo carga, `Exited (137)` | [Incidente 2](#-incidente-2-contenedores-destruidos-por-falta-de-ram-oom-killed) |
| HTTP **504 Gateway Timeout** o latencia alta en Locust | [Incidente 3](#-incidente-3-tiempos-de-espera-agotados-504-y-latencia-alta) |
| `/api/health` con `"status":"degraded"` o errores **500** | [Incidente 4](#-incidente-4-base-de-datos-mysql-caída-o-sin-conexiones) |
| Una versión nueva rompe la API | [Rollback](#-procedimiento-de-emergencia-rollback-deshacer-actualización) |

---

## 🛑 Incidente 1: Errores 502 Bad Gateway intermitentes o totales

**Descripción:** Los usuarios, la app Flutter o Locust reportan picos de errores HTTP 502. Nginx está arriba pero no puede comunicarse con una o varias réplicas del backend.

### 🔍 Diagnóstico

1. Revise el estado de salud de las réplicas:

   ```bash
   docker compose ps
   ```

   *(Identifique réplicas `unhealthy`, `Restarting` o `Exited`).*

2. Revise los logs del balanceador:

   ```bash
   docker compose logs load-balancer --tail=20
   ```

   Interprete el mensaje:

   | Mensaje en el log de Nginx | Significado |
   |---|---|
   | `connect() failed (111: Connection refused) while connecting to upstream` | La réplica existe pero la API no está escuchando (reiniciando o caída) |
   | `no live upstreams while connecting to upstream` | Nginx marcó **todas** las réplicas como fallidas |
   | `host not found in upstream "backend"` | El servicio `backend` no está corriendo o no está en la misma red |
   | `upstream prematurely closed connection` | La réplica murió en mitad de la petición (ver Incidente 2) |

3. Revise los logs de la réplica afectada (reemplace `N` por el número de réplica):

   ```bash
   docker logs smartcompost-backend-N --tail=50
   ```

### 🛠️ Mitigación

* **Si todas las réplicas están `healthy` pero Nginx dice `no live upstreams`:** Nginx las bloqueó tras varios fallos. Verifique en `nginx.conf` que las líneas `server` del bloque `upstream` tengan `max_fails=0` (o un valor alto con `fail_timeout` corto) y reinicie Nginx:

  ```bash
  docker compose restart load-balancer
  ```

* **Si se recrearon réplicas (actualización o `--scale`) y aparecen 502 con `Connection refused`:** Nginx conserva las IP antiguas en caché. Reinícielo con el mismo comando anterior.

* **Si una réplica está `unhealthy` o `Restarting`:** revise su log (paso 3). Si es un fallo de BD vaya al Incidente 4; si es por memoria, al Incidente 2. Para forzar su recuperación:

  ```bash
  docker compose restart backend
  ```

* **Si el servicio `backend` no tiene contenedores:** vuelva a levantarlo:

  ```bash
  docker compose up -d backend
  ```

**Verificación de cierre:** `curl -i http://localhost/api/health` devuelve `200 OK` y Locust muestra 0 % de fallos durante 1 minuto.

---

## 🛑 Incidente 2: Contenedores destruidos por falta de RAM (OOM Killed)

**Descripción:** Una o varias réplicas se detienen de repente bajo carga (por ejemplo, al generar reportes PDF de `/analisis/reporte.pdf` o `/alertas/reporte.pdf`, o al subir fotos de perfil). En Locust se ven caídas abruptas de conexiones y en `docker compose ps` aparece `Exited (137)`.

### 🔍 Diagnóstico

1. Verifique el consumo en tiempo real (columna `MEM USAGE / LIMIT` y `MEM %`):

   ```bash
   docker stats
   ```

   *(Una réplica que se acerca al 100 % de su límite está en riesgo).*

2. Confirme que el contenedor fue destruido por falta de memoria:

   ```bash
   docker inspect smartcompost-backend-N --format "{{.State.OOMKilled}} {{.State.ExitCode}}"
   ```

   *(Si responde `true 137`, es un OOM confirmado).*

3. Revise en Dozzle qué endpoint se estaba atendiendo justo antes de la caída.

### 🛠️ Mitigación

1. Aumente el límite de memoria del servicio `backend` en `docker-compose.yml` (por ejemplo, de `256M` a `512M`):

   ```yaml
   backend:
     deploy:
       resources:
         limits:
           memory: 512M
   ```

2. Aplique el cambio:

   ```bash
   docker compose up -d backend
   ```

3. Reinicie Nginx para que tome las IP de las réplicas recreadas:

   ```bash
   docker compose restart load-balancer
   ```

4. Si el OOM se repite con un endpoint concreto (por ejemplo, reportes PDF), reporte al equipo de desarrollo para limitar el tamaño del reporte o generarlo en segundo plano.

> ⚠️ Antes de subir la memoria, verifique que la máquina host la tenga: 4 réplicas × 512M = 2 GB solo para el backend, más MySQL.

---

## 🛑 Incidente 3: Tiempos de espera agotados (504) y Latencia Alta

**Descripción:** Nginx devuelve **504 Gateway Timeout**, o en Locust el tiempo de respuesta del percentil 95 supera los **2 segundos**. Las réplicas pueden marcarse `unhealthy` porque el healthcheck no recibe respuesta a tiempo y Docker las reinicia, lo que sobrecarga a las demás (falla en cascada).

### 🔍 Diagnóstico

1. Abra Dozzle (`http://localhost:8080`), seleccione las réplicas `backend` y filtre por `ERROR`, `Timeout` o `500`.
2. En los logs de Nginx busque el mensaje de tiempo agotado:

   ```bash
   docker compose logs load-balancer --tail=50
   ```

   *(Mensaje típico: `upstream timed out (110: Connection timed out) while reading response header from upstream`).*

3. Verifique si la CPU de las réplicas está saturada (columna `CPU %` cerca del límite configurado):

   ```bash
   docker stats
   ```

4. En Locust (pestaña **Statistics**), identifique qué endpoint tiene el mayor tiempo de respuesta (por ejemplo, `/analisis/resumen` o `/pilas/{id}/detalle`).

### 🛠️ Mitigación

1. Aumente temporalmente la cantidad de réplicas en `docker-compose.yml` para absorber la carga:

   ```yaml
   backend:
     deploy:
       replicas: 6
   ```

2. Despliegue el cambio de escala:

   ```bash
   docker compose up -d backend
   ```

   *(Alternativa sin editar el archivo: `docker compose up -d --scale backend=6`).*

3. Reinicie Nginx para que incluya las réplicas nuevas en el balanceo:

   ```bash
   docker compose restart load-balancer
   ```

4. Si las réplicas se reinician en cadena por el healthcheck, dé más margen en `docker-compose.yml` (sección `healthcheck` del servicio `backend`), por ejemplo `interval: 10s`, `timeout: 5s`, `retries: 3`, `start_period: 20s`, y aplique con `docker compose up -d backend`.
5. **A largo plazo** (equipo de desarrollo): optimizar las consultas lentas a MySQL (índices en `lecturas` por `pila_id` y fecha), ejecutar Uvicorn con varios workers (`--workers 2`) y convertir los endpoints bloqueantes en asíncronos.

---

## 🛑 Incidente 4: Base de datos MySQL caída o sin conexiones

**Descripción:** `GET /api/health` responde `200` pero con `"status":"degraded"` y `"database":{"status":"down"}`; el login y los listados devuelven **500 Internal Server Error**. Puede deberse a que el contenedor `db` se detuvo o a que se agotaron las conexiones (`Too many connections`) al escalar muchas réplicas.

> ⚠️ El healthcheck de Docker de las réplicas solo valida que la API responda; **no** las marca `unhealthy` cuando falla MySQL. Revise siempre el JSON de `/api/health`.

### 🔍 Diagnóstico

1. Verifique el estado de la base de datos:

   ```bash
   docker compose ps db
   ```

2. Consulte la salud desde la API:

   ```bash
   curl -s http://localhost/api/health
   ```

   *(El campo `database.error` indica la causa exacta, por ejemplo `Can't connect to MySQL server on 'db'` o `Too many connections`).*

3. Revise los logs de MySQL:

   ```bash
   docker compose logs db --tail=50
   ```

4. Si MySQL está arriba, consulte los últimos errores registrados por la aplicación:

   ```bash
   docker compose exec db mysql -uroot smartcompost -e "SELECT fecha_hora, nivel, mensaje FROM system_logs ORDER BY fecha_hora DESC LIMIT 10;"
   ```

### 🛠️ Mitigación

* **Si `db` está detenido o `unhealthy`:**

  ```bash
  docker compose up -d db
  ```

  Espere a que muestre `healthy` (unos 20 s). Las réplicas se reconectan solas (`pool_pre_ping=True`).

* **Si el error es `Too many connections`:** reduzca réplicas a 4 (`docker compose up -d --scale backend=4`) o aumente el límite de MySQL añadiendo `command: --max-connections=300` al servicio `db` y aplicando `docker compose up -d db`.

* **Si el error es `Table ... doesn't exist` o `Unknown column`:** la base es anterior a la versión actual. Ejecute las migraciones de `backend/migrations/` en orden (`001`, `002`, `003`):

  ```bash
  docker compose exec -T db mysql -uroot smartcompost < backend/migrations/001_pilas_ciclo.sql
  ```

  *(Repita con `002_usuario_foto.sql` y `003_sensor_dano.sql`. Solo en entornos de prueba: `docker compose down -v` y volver a levantar recrea la base desde cero, **borrando todos los datos**).*

**Verificación de cierre:** `/api/health` responde `"status":"ok"` y `"database":{"status":"up"}`.

---

## ⏪ Procedimiento de Emergencia: Rollback (Deshacer actualización)

Use este procedimiento si una nueva versión del backend (v2) causa un fallo crítico inmediato (errores 500 masivos, réplicas que no arrancan) que no puede solucionarse en menos de **15 minutos**.

1. Identifique el último commit estable (v1):

   ```bash
   git log --oneline -10
   ```

2. Restaure el código del backend a esa versión (reemplace `<commit_v1>` por el hash identificado):

   ```bash
   git checkout <commit_v1> -- backend/
   ```

3. Reconstruya y recree **solo** las réplicas del backend, sin tocar MySQL ni Nginx:

   ```bash
   docker compose up --build -d --no-deps --force-recreate backend
   ```

4. Reinicie Nginx para que apunte a las réplicas nuevas:

   ```bash
   docker compose restart load-balancer
   ```

5. Verifique:
   * `docker compose ps` → las 4 réplicas en `Up (healthy)`.
   * `curl -i http://localhost/api/health` → `200 OK` con `"status":"ok"`.
   * Locust → la tasa de errores vuelve a **0 %**.

6. Registre el incidente (fecha, versión revertida, causa) y notifique al equipo de desarrollo. Para volver a la última versión una vez corregida: `git checkout HEAD -- backend/` y repetir los pasos 3 a 5.

> ⚠️ Si la v2 incluyó una migración de base de datos, revertir el código **no** revierte el esquema de MySQL. Consulte con desarrollo antes de hacer rollback en ese caso.
