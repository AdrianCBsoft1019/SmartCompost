# SmartCompost — Backend (FastAPI)

Control Semana 2 (Mes 1, Sprints 1-2): revisión de la conexión a la base
de datos y despliegue del entorno base. Este README documenta los dos
caminos posibles para levantar el entorno y cómo verificar que quedó
arriba correctamente.

## Opción A — XAMPP (MySQL local)

1. Enciende **MySQL** en el Panel de Control de XAMPP.
2. Crea la base de datos vacía `smartcompost` desde phpMyAdmin
   (`http://localhost/phpmyadmin` → Nueva → nombre `smartcompost` → Crear).
   Las tablas las crea automáticamente la app la primera vez que arranca.
3. Instala dependencias y copia las variables de entorno:
```bash
   cd backend
   python -m venv venv
   source venv/bin/activate        # Windows: venv\Scripts\activate
   pip install -r requirements.txt
   cp .env.example .env
```
4. Levanta el servidor:
```bash
   uvicorn app.main:app --reload
```

## Opción B — Docker Compose (entorno base reproducible)

No requiere tener XAMPP ni MySQL instalados: levanta la base de datos
y el backend en contenedores, con un solo comando, desde la raíz del
repositorio:

```bash
docker compose up --build
```

Esto crea:
- `smartcompost_db`: MySQL 8 con la base `smartcompost` ya creada.
- `smartcompost_backend`: la API, esperando a que la base de datos
  esté saludable (`healthcheck`) antes de arrancar.

Para bajar el entorno (conservando los datos en el volumen):
```bash
docker compose down
```
Para bajarlo y borrar también los datos de la base:
```bash
docker compose down -v
```

## Verificar que el entorno quedó arriba (con cualquiera de las 2 opciones)

Con el backend corriendo (opción A o B), visita: