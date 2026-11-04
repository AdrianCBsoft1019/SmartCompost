# Runbook de Operaciones e Incidentes - SmartCompost (RAP 1)

**Propósito:** guía rápida para saber qué hacer cuando algo falla en el entorno de SmartCompost (4 réplicas de la API, Nginx, MySQL, Dozzle y Locust).

## Antes de empezar: revisión rápida

Ante cualquier falla, haga siempre estos 3 pasos:

1. Ver el estado de los contenedores:

   ```bash
   docker compose ps
   ```

2. Probar la API:

   ```bash
   curl -i http://localhost/api/health
   ```

3. Abrir Dozzle (http://localhost:8080) y revisar los logs del contenedor que falla.

Luego busque su caso en esta tabla:

| ¿Qué está pasando? | Vaya a |
|---|---|
| Error **502 Bad Gateway** | Incidente 1 |
| Un contenedor se apaga solo cuando hay mucha carga | Incidente 2 |
| Error **504 Gateway Timeout** o la API está muy lenta | Incidente 3 |
| `/api/health` dice `"degraded"` o la API da error **500** | Incidente 4 |
| Una versión nueva dañó la API | Rollback |

---

## Incidente 1: Error 502 Bad Gateway

**Qué pasa:** Nginx está funcionando, pero no logra comunicarse con las réplicas de la API.

### Diagnóstico

1. Revise si alguna réplica está mal:

   ```bash
   docker compose ps
   ```

   Busque réplicas con estado `unhealthy`, `Restarting` o `Exited`.

2. Revise los logs de Nginx:

   ```bash
   docker compose logs load-balancer --tail=20
   ```

   | Mensaje | Qué significa |
   |---|---|
   | `Connection refused` | La réplica se está reiniciando o está caída |
   | `no live upstreams` | Nginx bloqueó todas las réplicas |
   | `host not found in upstream` | El servicio `backend` no está corriendo |

### Solución

- **Si dice `no live upstreams`:** revise que en `nginx.conf` las réplicas tengan `max_fails=0` y reinicie Nginx:

  ```bash
  docker compose restart load-balancer
  ```

- **Si una réplica está `unhealthy` o `Restarting`:** reinicie las réplicas:

  ```bash
  docker compose restart backend
  ```

  Si se apagó por falta de memoria, vaya al Incidente 2.

- **Si el servicio `backend` no aparece:** vuelva a levantarlo:

  ```bash
  docker compose up -d backend
  ```

**Cómo saber que quedó resuelto:** `curl -i http://localhost/api/health` responde `200 OK`.

---

## Incidente 2: Contenedor apagado por falta de memoria (OOM Killed)

**Qué pasa:** una réplica se apaga de repente cuando hay mucha carga (por ejemplo, al generar reportes PDF). En `docker compose ps` aparece `Exited (137)`.

### Diagnóstico

1. Revise el consumo de memoria en tiempo real:

   ```bash
   docker stats
   ```

   Si la columna `MEM %` está cerca de 100%, la réplica se está quedando sin memoria.

2. Confirme que se apagó por falta de memoria (cambie `N` por el número de la réplica):

   ```bash
   docker inspect smartcompost-backend-N --format "{{.State.OOMKilled}}"
   ```

   Si responde `true`, la causa fue falta de memoria.

### Solución

1. En `docker-compose.yml` aumente la memoria del servicio `backend` (por ejemplo, de `256M` a `512M`):

   ```yaml
   deploy:
     resources:
       limits:
         memory: 512M
   ```

2. Aplique el cambio:

   ```bash
   docker compose up -d backend
   ```

3. Reinicie Nginx:

   ```bash
   docker compose restart load-balancer
   ```

---

## Incidente 3: Error 504 Gateway Timeout o API lenta

**Qué pasa:** Nginx responde 504 porque la API tarda demasiado, o en Locust el tiempo de respuesta pasa de **2 segundos**. Las réplicas pueden marcarse `unhealthy` y reiniciarse, lo que sobrecarga a las demás.

### Diagnóstico

1. En Dozzle (http://localhost:8080) busque las palabras `ERROR` o `Timeout`.
2. Revise los logs de Nginx:

   ```bash
   docker compose logs load-balancer --tail=50
   ```

   Busque el mensaje `upstream timed out`.

3. Revise si la CPU está al máximo:

   ```bash
   docker stats
   ```

4. En Locust (pestaña **Statistics**) mire qué ruta es la más lenta.

### Solución

1. En `docker-compose.yml` aumente el número de réplicas:

   ```yaml
   deploy:
     replicas: 6
   ```

2. Aplique el cambio:

   ```bash
   docker compose up -d backend
   ```

3. Reinicie Nginx para que use las réplicas nuevas:

   ```bash
   docker compose restart load-balancer
   ```

4. **A largo plazo:** el equipo de desarrollo debe optimizar las consultas lentas a la base de datos.

---

## Incidente 4: Falla la base de datos (MySQL)

**Qué pasa:** `/api/health` responde `"status":"degraded"` y `"database":{"status":"down"}`. El login y las consultas dan error **500**.

### Diagnóstico

1. Revise si MySQL está funcionando:

   ```bash
   docker compose ps db
   ```

2. Revise los logs de MySQL:

   ```bash
   docker compose logs db --tail=50
   ```

3. Mire el campo `error` en la respuesta de `/api/health`; ahí aparece la causa exacta.

### Solución

- **Si MySQL está apagado:** enciéndalo y espere 20 segundos:

  ```bash
  docker compose up -d db
  ```

  Las réplicas se vuelven a conectar solas.

- **Si el error dice `Too many connections`:** vuelva a 4 réplicas:

  ```bash
  docker compose up -d --scale backend=4
  ```

**Cómo saber que quedó resuelto:** `/api/health` responde `"status":"ok"`.

---

## Rollback: volver a la versión anterior

Use este procedimiento si una versión nueva (v2) daña la API y no se puede arreglar rápido.

1. Vea los últimos cambios y copie el código (hash) de la última versión que funcionaba (v1):

   ```bash
   git log --oneline -10
   ```

2. Regrese el código del backend a esa versión (cambie `<commit_v1>` por el código copiado):

   ```bash
   git checkout <commit_v1> -- backend/
   ```

3. Vuelva a construir y levantar solo la API:

   ```bash
   docker compose up --build -d --no-deps --force-recreate backend
   ```

4. Reinicie Nginx:

   ```bash
   docker compose restart load-balancer
   ```

5. Verifique:
   - `docker compose ps`: las 4 réplicas en `healthy`.
   - `curl -i http://localhost/api/health`: responde `200 OK`.
   - En Locust los errores vuelven a **0%**.
