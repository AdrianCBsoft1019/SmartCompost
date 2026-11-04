# Bitácora de Auditoría Cruzada - Proyecto CUNITECH

| Campo | Valor |
|---|---|
| Equipo auditor | SmartCompost |
| Equipo auditado | CUNITECH |
| Manual auditado | https://github.com/adrianalucia2008/documentacion-Cunitech/blob/main/Manual_Instalacion.md |
| Runbook auditado | https://github.com/adrianalucia2008/documentacion-Cunitech/blob/main/Runbook_de_Incidentes.md |
| Repositorio del código | https://github.com/Sara-AprendizCBA/Cunitech |
| Versión revisada | Manual: commit `2132da2` / Código: commit `5065c84` |
| Fecha | 4 de noviembre de 2026 |
| Regla de la prueba | Seguir EXCLUSIVAMENTE el manual, sin preguntas verbales al otro equipo |

## 1. Resumen

El manual de CUNITECH está bien organizado y es fácil de leer: explica la arquitectura, los prerrequisitos, los pasos y las pruebas de verificación. Sin embargo, **no documenta la arquitectura que pide la actividad** (4 réplicas con Nginx, Dozzle y Locust). Describe una app Flutter conectada a Supabase en la nube y no usa Docker.

Además, se encontraron defectos de redacción, pasos incompletos y diferencias entre lo que dice el manual y lo que hay en el código.

| Severidad | Cantidad |
|---|---|
| Crítica | 1 |
| Alta | 1 |
| Media | 4 |
| Baja | 5 |
| **Total** | **11** |

## 2. Recorrido paso a paso

| Paso del manual | Comando | Resultado |
|------------|--------------|------------------|
| Paso 1: Clonar el repositorio | `git clone https://github.com/Sara-AprendizCBA/Cunitech.git` y `cd Cunitech` | Funcionó. Se descargó el proyecto con las carpetas `lib`, `supabase`, `web` y `android` |
| Prerrequisito: Flutter con Dart 3.11.4 o superior | `flutter --version` | Se instaló Flutter 3.47.9 (Dart 3.13.7). El `pubspec.yaml` pide `sdk: ^3.11.4`, así que coincide con el manual |
| Paso 2: Instalar dependencias | `flutter pub get` | Completar con el resultado en el equipo auditor |
| Paso 3: Variables de entorno | (no requiere comando) | Defecto D-03 |
| Paso 4: Cuenta de prueba | `admin@gmail.com` / contraseña del manual | Completar con el resultado en el equipo auditor |
| Paso 5: Ejecutar la app | `flutter run -d chrome --web-port=60144` | Completar con el resultado en el equipo auditor |
| Smoke test 3: estado del backend | `curl -i https://aswhtehpmmeetplnskmz.supabase.co/functions/v1/health` | Completar con el resultado en el equipo auditor |
| Smoke test 4: CRUD de conejos y chat IA | (desde la app) | Completar con el resultado en el equipo auditor |

## 3. Defectos de Documentación

| ID | Sección del manual | Defecto | Evidencia | Severidad |
|----|----------|----------------------------|--------------------|--------|
| D-01 | Todo el manual | No documenta la arquitectura pedida en la actividad: no hay 4 réplicas, Nginx, Dozzle, Locust ni Docker Compose. No se puede verificar `docker compose ps` ni Dozzle | El manual describe Flutter + Supabase en la nube. El repositorio no tiene `docker-compose.yml`, `nginx.conf` ni `locustfile.py` | Crítica |
| D-02 | 6.4 Base de Datos | La base de datos no se puede reconstruir: faltan las migraciones 001 y 008 a 013. Si el proyecto de Supabase se pierde, nadie puede volver a instalar el sistema | `supabase/migrations/` solo tiene 002 a 007 y 014 a 018. El mismo manual lo reconoce | Alta |
| D-03 | 4. Link del repositorio / Paso 1 | El manual está en un repositorio (`adrianalucia2008/documentacion-Cunitech`) y el código en otro (`Sara-AprendizCBA/Cunitech`). El repositorio entregado no contiene la aplicación | El repositorio entregado solo tiene `Manual_Instalacion.md` y `Runbook_de_Incidentes.md` | Media |
| D-04 | 6.3 Despliegue del Backend | Solo despliega 4 funciones (`create-user`, `generate-insights`, `identify-breed`, `chat-assistant`). Omite `login` y `health`, que el manual dice que son necesarias (sección 2 y smoke test 3) | `supabase/functions/` tiene 6 funciones: también `login` y `health` | Media |
| D-05 | Paso 4: Cuenta de prueba | Publica el correo y la contraseña del administrador en un documento público. La contraseña es débil (`123456789`) | Manual, Paso 4 | Media |
| D-06 | 2. Arquitectura / Paso 3 | Todo depende de un proyecto de Supabase en la nube que el Equipo B no controla. Si el proyecto está pausado o caído, el manual no da forma de arreglarlo sin acceso de propietario | Runbook INC-03 e INC-06 piden "Restore project" en el panel de Supabase | Media |
| D-07 | Paso 3: Variables de entorno | Dice que `.env.example` "está vacío a propósito", pero tiene contenido | `.env.example` tiene la línea `# Example env — copy to .env and fill values. Never commit secrets.` | Baja |
| D-08 | 6.3 Despliegue del Backend | Numeración rota: el primer paso no tiene número y la lista empieza en "2.". Frase incompleta: "vincule la carpeta local con e proyecto en la nube. Reemplace con el ID de referencia del proyecto" | Manual, sección 6.3 | Baja |
| D-09 | Paso 5 y Runbook INC-04 | Dice que las funciones de IA y de usuarios solo aceptan peticiones desde `http://localhost:60144` (CORS). En el código del repositorio las funciones responden `Access-Control-Allow-Origin: *` y la variable `APP_URL` se declara pero no se usa | `supabase/functions/chat-assistant/index.ts` líneas 10 y 18 (igual en `generate-insights` e `identify-breed`) | Baja |
| D-10 | Runbook INC-05 | Remite a la "sección 4.5 del manual", que no existe (la cuenta de prueba está en el Paso 4) | Runbook, INC-05, paso 1 | Baja |
| D-11 | Repositorio del código | El `README.md` del código es la plantilla por defecto de Flutter ("A new Flutter project.") y no menciona el manual | `Cunitech/README.md` | Baja |

## 4. Lo que está bien

- El manual es claro, ordenado y fácil de seguir.
- Los comandos de clonado y la URL del repositorio funcionan.
- Los prerrequisitos coinciden con el código: el `pubspec.yaml` pide `sdk: ^3.11.4`.
- Lo que dice del código coincide: `lib/main.dart` tiene `Supabase.initialize(...)` con la URL indicada, y existen las 6 Edge Functions nombradas.
- Advierte que el puerto 60144 es obligatorio y que la primera compilación tarda.
- No incluye llaves secretas en el código (Gemini, Resend y service_role se guardan como secretos de Supabase).
- El Runbook es muy completo: tiene 10 incidentes, una tabla de diagnóstico rápido, niveles de acceso ([LOCAL] / [SUPABASE]) y un registro de incidentes.

## 5. Recomendaciones para el Equipo CUNITECH

1. Agregar la arquitectura de la actividad (Docker Compose con 4 réplicas, Nginx, Dozzle y Locust) o justificar por escrito por qué no aplica.
2. Poner el manual y el runbook dentro del mismo repositorio del código.
3. Subir las migraciones que faltan (001 y 008 a 013) para poder reconstruir la base de datos desde cero.
4. Incluir `login` y `health` en los comandos de despliegue de la sección 6.3.
5. Quitar la contraseña del administrador del manual, o crear una cuenta de prueba con permisos limitados.
6. Corregir la numeración y la frase incompleta de la sección 6.3, la referencia "4.5" del Runbook y la descripción de `.env.example`.
7. Revisar la configuración de CORS para que el código coincida con lo que dice el manual.
