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
