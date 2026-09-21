# SmartCompost — Entregable Sprint 1 y 2

Este paquete contiene lo solicitado para el **Mes 1 (Sprints 1 y 2 —
"Cimientos y Seguridad")** del roadmap del proyecto:

- ✅ Configuración de repositorios (repo Git ya inicializado, con commits organizados por Historia de Usuario — ver `git log`)
- ✅ Conexión a la base de datos (MySQL servido por **XAMPP**, vía SQLAlchemy + PyMySQL)
- ✅ Entorno base (backend Python corriendo local con `uvicorn`, apuntando al MySQL de XAMPP)
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

1. Enciende **Apache** y **MySQL** en el Panel de Control de XAMPP y crea la base `smartcompost` desde phpMyAdmin (ver `backend/README.md`, sección 1).
2. Levanta el backend: `cd backend && pip install -r requirements.txt && cp .env.example .env && uvicorn app.main:app --reload`
3. Verifica `http://localhost:8000/api/health` → debe decir `"database": {"status": "up"}`.
4. Corre el frontend: `cd frontend && flutter pub get && flutter run -d chrome --dart-define=API_BASE_URL=http://localhost:8000`
5. Crea una cuenta desde la pantalla de Registro → inicia sesión desde Login → revisa en phpMyAdmin que el usuario quedó guardado en la tabla `usuarios`.
6. Explora `http://localhost:8000/docs` para probar los CRUDs de Pilas y Sensores con el token JWT obtenido.

## Subir este proyecto a tu repositorio de GitHub

Este proyecto ya viene con un repositorio Git inicializado y los commits
organizados por Historia de Usuario (`git log` para verlos). Para subirlo a
tu repo ya creado en GitHub:

```bash
cd smartcompost
git remote add origin https://github.com/<tu-usuario>/<tu-repo>.git
git branch -M main
git push -u origin main
```

Si tu repo de GitHub ya tiene un README u otro archivo (no está vacío), en
vez de `git push -u origin main` usa:

```bash
git push -u origin main --force
```
**solo si estás seguro de que no hay nada importante en el repo remoto**
(esto sobreescribe lo que haya allá). Si sí hay algo que quieras conservar,
dime la URL del repo y te doy los pasos exactos para fusionarlo sin perder nada.

## Alineación con los Entregables y Ceremonias del Sprint (según tu documento)

- **Sprint Planning:** el alcance de este entregable se limitó estrictamente a las
  tareas de Sprint 1-2 (login/registro, CRUDs base, conexión a BD) sin adelantar
  lógica de sensores/alertas (Sprint 3+).
- **Sprint Review:** con el backend corriendo, `/docs` permite demostrar el login
  funcionando y los datos guardándose en PostgreSQL en vivo.
- **Git:** el README del backend incluye una convención de commits atados a las
  Historias de Usuario (`HU-10: ...`) para dejar evidencia trazable.
