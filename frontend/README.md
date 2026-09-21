# SmartCompost — Frontend (Flutter) — Sprint 1 y 2

Pantallas de **Login** y **Registro** replicando el diseño oscuro de los
mockups (rebrandeado de "ToxShield" a "SmartCompost"), conectadas al
backend vía `ApiService`.

## Cómo correr

```bash
flutter pub get
flutter run -d chrome   # o -d <tu-emulador/dispositivo>
```

Si el backend corre en un emulador Android, usa:

```bash
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8000
```

## Estructura

```
lib/
  main.dart                     # arranque de la app
  theme/app_theme.dart           # colores y estilos (tema oscuro del mockup)
  services/api_service.dart       # llamadas HTTP a /auth/register y /auth/login
  models/rol_usuario.dart          # enum instructor/aprendiz (espeja al backend)
  screens/login_screen.dart         # HU-10: pantalla de inicio de sesión
  screens/register_screen.dart       # HU-10: pantalla de creación de cuenta
```

## Notas de diseño

- Se mantuvo la estructura visual del mockup original (tarjeta oscura,
  acento verde, panel lateral de marca en Registro).
- Se reemplazó el texto genérico de marketing SaaS por copy orientado a
  monitoreo de compostaje.
- Se quitó el campo "Empresa" (no aplica al dominio) y se agregó un
  selector de **Rol** (Instructor / Aprendiz), acorde a HU-10.
- Los botones "Google / GitHub" del mockup original se omitieron por no
  formar parte del alcance del Sprint 1-2 (autenticación propia con
  JWT); se puede agregar SSO en un sprint posterior si el equipo lo
  decide.
