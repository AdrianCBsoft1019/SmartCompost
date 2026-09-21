# SmartCompost — Entregable Sprint 1 y 2

Este paquete contiene lo solicitado para el **Mes 1 (Sprints 1 y 2 —
"Cimientos y Seguridad")** del roadmap del proyecto:

- ✅ Configuración de repositorios (estructura backend/frontend lista para `git init`)
- ✅ Conexión a la base de datos (PostgreSQL vía SQLAlchemy)
- ✅ Despliegue del entorno base (Docker Compose: API + PostgreSQL)
- ✅ Sistema de autenticación — Login / Registro (HU-10, con roles instructor/aprendiz)
- ✅ CRUDs de las entidades principales (Usuarios, Pilas, Sensores) — funcionalidad sin diseño complejo en el backend
- ✅ Diseño de las pantallas de Login/Registro replicando el mockup entregado

## Estructura

```
smartcompost/
  backend/     -> API Python (FastAPI) + PostgreSQL + JWT
  frontend/    -> App Flutter (pantallas Login/Registro con el diseño del mockup)
```

Cada carpeta trae su propio `README.md` con instrucciones de instalación.

## Orden sugerido para probarlo

1. Levanta el backend: `cd backend && docker compose up --build`
2. Corre el frontend: `cd frontend && flutter pub get && flutter run -d chrome --dart-define=API_BASE_URL=http://localhost:8000`
3. Crea una cuenta desde la pantalla de Registro → inicia sesión desde Login.
4. Explora `http://localhost:8000/docs` para probar los CRUDs de Pilas y Sensores con el token JWT obtenido.

## Alineación con los Entregables y Ceremonias del Sprint (según tu documento)

- **Sprint Planning:** el alcance de este entregable se limitó estrictamente a las
  tareas de Sprint 1-2 (login/registro, CRUDs base, conexión a BD) sin adelantar
  lógica de sensores/alertas (Sprint 3+).
- **Sprint Review:** con el backend corriendo, `/docs` permite demostrar el login
  funcionando y los datos guardándose en PostgreSQL en vivo.
- **Git:** el README del backend incluye una convención de commits atados a las
  Historias de Usuario (`HU-10: ...`) para dejar evidencia trazable.
