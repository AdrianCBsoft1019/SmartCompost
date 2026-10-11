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
