# SmartCompost 

## Estructura

```
smartcompost/
  backend/     -> API Python (FastAPI) + PostgreSQL + JWT
  frontend/    -> App Flutter (pantallas Login/Registro con el diseño del mockup)
```



## Orden sugerido para probarlo

1. Enciende **Apache** y **MySQL** en el Panel de Control de XAMPP y crea la base `smartcompost` desde phpMyAdmin (ver `backend/README.md`, sección 1).
2. Levanta el backend: `cd backend && pip install -r requirements.txt && cp .env.example .env && uvicorn app.main:app --reload`
3. Verifica `http://localhost:8000/api/health` → debe decir `"database": {"status": "up"}`.
4. Corre el frontend: `cd frontend && flutter pub get && flutter run -d chrome --dart-define=API_BASE_URL=http://localhost:8000`
5. Crea una cuenta desde la pantalla de Registro → inicia sesión desde Login → revisa en phpMyAdmin que el usuario quedó guardado en la tabla `usuarios`.
6. Explora `http://localhost:8000/docs` para probar los CRUDs de Pilas y Sensores con el token JWT obtenido.


## Alineación con los Entregables y Ceremonias del Sprint (según tu documento)

- **Sprint Planning:** el alcance de este entregable se limitó estrictamente a las
  tareas de Sprint 1-2 (login/registro, CRUDs base, conexión a BD) sin adelantar
  lógica de sensores/alertas (Sprint 3+).
- **Sprint Review:** con el backend corriendo, `/docs` permite demostrar el login
  funcionando y los datos guardándose en PostgreSQL en vivo.
- **Git:** el README del backend incluye una convención de commits atados a las
  Historias de Usuario (`HU-10: ...`) para dejar evidencia trazable.
