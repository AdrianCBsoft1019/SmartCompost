# Manual de Instalación y Despliegue - SmartCompost

## 1. ¿Qué es este proyecto?

SmartCompost es una API para monitorear pilas de compostaje (temperatura, humedad, gases, alertas y reportes).

En este manual se explica cómo instalarla en su computador usando **Docker Compose**, con esta arquitectura:

- **4 copias (réplicas)** de la API trabajando al mismo tiempo.
- **Nginx**, que recibe las peticiones y las reparte entre las 4 réplicas.
- **MySQL**, la base de datos.
- **Dozzle**, para ver los logs (mensajes) de los contenedores.
- **Locust**, para hacer pruebas de carga (simular muchos usuarios).

**Importante:** ejecute los pasos en orden y copie los comandos tal como están. Todos los comandos se ejecutan dentro de la carpeta del proyecto.

---

## 2. Arquitectura

```
Usuario / Locust
       |
       v
Nginx (http://localhost)
       |
       +--> backend 1
       +--> backend 2
       +--> backend 3
       +--> backend 4
                |
                v
          MySQL (base de datos)
```

| Servicio | Para qué sirve | Dirección |
|---|---|---|
| `load-balancer` (Nginx) | Reparte el tráfico entre las réplicas | http://localhost |
| `backend` (4 réplicas) | La API de SmartCompost (FastAPI) | Puerto interno 8000 |
| `db` (MySQL 8.0) | Guarda los datos | Puerto 3306 |
| `dozzle` | Ver los logs | http://localhost:8080 |
| `locust` | Pruebas de carga | http://localhost:8089 |

---

## 3. Requisitos

Instale lo siguiente antes de empezar:

| Programa | Versión mínima | Comando para revisar |
|---|---|---|
| Docker Desktop (o Docker Engine) | 20.10 | `docker --version` |
| Docker Compose | 2.0 | `docker compose version` |
| Git | 2.x | `git --version` |

Además:

- **Docker Desktop debe estar abierto** antes de usar cualquier comando.
- Deben estar libres los puertos **80, 3306, 8080 y 8089**. Si tiene XAMPP o MySQL abierto, ciérrelo.
- Sistema operativo probado: Windows 10/11 con Docker Desktop, o Linux Ubuntu 22.04.

---

## 4. Instalación

### Paso 1: Descargar el proyecto

```bash
git clone https://github.com/AdrianCBsoft1019/SmartCompost.git
```

```bash
cd SmartCompost
```

### Paso 2: Crear el archivo de configuración

Copie el archivo de ejemplo:

```bash
cp .env.example .env
```

En PowerShell use: `Copy-Item .env.example .env`

El archivo `.env` ya trae valores que funcionan para pruebas. No necesita cambiar nada.

### Paso 3: Levantar el proyecto

```bash
docker compose up --build -d
```

La primera vez puede tardar varios minutos porque descarga e instala todo. Cuando termine, **espere 30 segundos** antes de seguir.

### Paso 4: Cargar datos de prueba

```bash
docker compose exec --index 1 backend python -m app.seed
```

Esto crea pilas, sensores, lecturas y estos usuarios:

| Rol | Correo | Contraseña |
|---|---|---|
| Administrador | admin@smartcompost.com | Admin12345 |
| Estudiante | estudiante@smartcompost.com | Estudiante123 |

---

## 5. Verificar que todo funciona

**1. Ver los contenedores:**

```bash
docker compose ps
```

Debe ver **8 contenedores** en estado `Up`: 1 de `db`, 4 de `backend`, 1 de `load-balancer`, 1 de `dozzle` y 1 de `locust`. Los de `db` y `backend` deben decir `healthy`.

Si alguno dice `starting`, espere unos segundos y repita el comando.

**2. Probar la API:**

```bash
curl -i http://localhost/api/health
```

En PowerShell use `curl.exe` en lugar de `curl`.

Debe responder `HTTP/1.1 200 OK` y un texto que contenga `"status":"ok"` y `"database":{"status":"up"`.

**3. Abrir las páginas en el navegador:**

| Página | Dirección |
|---|---|
| Documentación de la API (Swagger) | http://localhost/docs |
| Logs (Dozzle) | http://localhost:8080 |
| Pruebas de carga (Locust) | http://localhost:8089 |

**4. Hacer una prueba de carga:**

1. Abra http://localhost:8089
2. Escriba: Number of users = `50`, Ramp up = `5`, Host = `http://load-balancer`
3. Presione **Start** y espere 1 minuto.
4. La columna **Failures** debe quedar en **0%**.

---

## 6. Comandos útiles

| Qué quiero hacer | Comando |
|---|---|
| Ver los logs de la API | `docker compose logs -f backend` |
| Ver cuánta CPU y RAM usa cada contenedor | `docker stats` |
| Reiniciar Nginx | `docker compose restart load-balancer` |
| Apagar todo | `docker compose down` |
| Apagar todo y borrar la base de datos | `docker compose down -v` |

**Actualizar la API después de un cambio en el código:**

```bash
docker compose up --build -d --no-deps --force-recreate backend
```

```bash
docker compose restart load-balancer
```

---

## 7. Problemas comunes al instalar

| Problema | Solución |
|---|---|
| `port is already allocated` (puerto ocupado) | Cierre el programa que usa ese puerto (XAMPP, MySQL, Apache, IIS) y repita el Paso 3 |
| `Cannot connect to the Docker daemon` | Abra Docker Desktop y espere a que diga "Running" |
| `docker-compose: command not found` | Escriba `docker compose` (con espacio, sin guion) |
| La API responde `502 Bad Gateway` | La API todavía está arrancando. Espere 30 segundos y pruebe de nuevo |
| El login responde `401` | Falta cargar los datos de prueba (Paso 4) |

Si el problema aparece después de una instalación correcta, consulte el archivo `RUNBOOK_INCIDENTES.md`.
