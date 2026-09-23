import time
from datetime import datetime

from fastapi import FastAPI, Request
from fastapi.middleware.cors import CORSMiddleware
from sqlalchemy import text
from sqlalchemy.exc import OperationalError

from .database import Base, engine, SessionLocal
from .routers import auth, usuarios, pilas, sensores
from . import log_model  
from .log_service import log_error_bd

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
