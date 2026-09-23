"""
SmartCompost API - Backend Python (FastAPI)

Sprint 1 y 2: entorno base, conexion a BD, autenticacion por roles
y CRUDs de las entidades principales (Usuarios, Pilas, Sensores).

Modulo Transversal (Fase 2): Health Check + Trazabilidad ciega (system_logs).
"""

import time
from datetime import datetime

from fastapi import FastAPI, Request
from fastapi.middleware.cors import CORSMiddleware
from sqlalchemy import text
from sqlalchemy.exc import OperationalError

from .database import Base, engine, SessionLocal
from .routers import auth, usuarios, pilas, sensores
from . import log_model  # noqa: F401 - registra el modelo SystemLog en Base.metadata
from .log_service import log_error_bd

# Crea las tablas si no existen (para desarrollo). En un entorno real
# se recomienda manejar el esquema con Alembic (migraciones versionadas).
Base.metadata.create_all(bind=engine)

_INICIO_SERVIDOR = time.time()

app = FastAPI(
    title="SmartCompost API",
    description=(
        "Backend del sistema de monitoreo de compostaje - "
        "Centro de Biotecnologia Agropecuaria SENA Mosquera"
    ),
    version="0.2.0-modulo-transversal",
)

# En desarrollo se permite el frontend Flutter (web/emulador) sin restriccion.
# Antes de produccion, restringir 'allow_origins' a los dominios reales.
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(auth.router)
app.include_router(usuarios.router)
app.include_router(pilas.router)
app.include_router(sensores.router)


@app.get("/", tags=["Salud"])
def raiz():
    return {"status": "ok", "proyecto": "SmartCompost", "modulo": "transversal"}


@app.get("/api/health", tags=["Salud"])
def health_check(request: Request):
    """
    Health Check publico (Modulo Transversal, requisito 1):
    - status del servidor
    - uptime en segundos
    - ping real a la base de datos (SELECT 1)

    Si el ping a la BD falla, se registra el incidente en system_logs
    (o en el archivo de fallback si system_logs tampoco es alcanzable)
    y el endpoint responde igualmente, mostrando el estado real.
    """
    uptime_segundos = round(time.time() - _INICIO_SERVIDOR, 2)
    db_status = "unknown"
    db_error = None

    db = SessionLocal()
    try:
        db.execute(text("SELECT 1"))
        db_status = "up"
    except OperationalError as exc:
        db_status = "down"
        db_error = str(exc)
        origen_ip = request.client.host if request.client else None
        log_error_bd(
            f"Fallo el ping de /api/health a la base de datos: {exc}",
            origen_ip,
        )
    finally:
        db.close()

    return {
        "status": "ok" if db_status == "up" else "degraded",
        "timestamp": datetime.utcnow().isoformat() + "Z",
        "uptime_seconds": uptime_segundos,
        "database": {
            "status": db_status,
            "error": db_error,
        },
    }
