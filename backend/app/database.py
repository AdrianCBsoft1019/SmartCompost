"""
Conexion a la base de datos MySQL (servida localmente por XAMPP).

Sprint 1-2: "Configuracion de repositorios, conexion a la base de datos
y despliegue del entorno base" (ver roadmap SmartCompost, Mes 1).
"""

import os
from dotenv import load_dotenv
from sqlalchemy import create_engine
from sqlalchemy.exc import OperationalError
from sqlalchemy.orm import sessionmaker, declarative_base

load_dotenv()

DB_HOST = os.getenv("DB_HOST", "127.0.0.1")
DB_PORT = os.getenv("DB_PORT", "3306")
DB_NAME = os.getenv("DB_NAME", "smartcompost")
DB_USER = os.getenv("DB_USER", "root")
DB_PASSWORD = os.getenv("DB_PASSWORD", "")

# XAMPP expone MySQL/MariaDB en localhost:3306. Usamos el driver PyMySQL
# (puro Python, no requiere compilar nada, ideal para este entorno).
DATABASE_URL = (
    f"mysql+pymysql://{DB_USER}:{DB_PASSWORD}"
    f"@{DB_HOST}:{DB_PORT}/{DB_NAME}?charset=utf8mb4"
)

# pool_pre_ping evita errores por conexiones caidas del pool cuando
# el backend queda inactivo un rato (util en entornos de desarrollo).
engine = create_engine(DATABASE_URL, pool_pre_ping=True)

SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)

Base = declarative_base()


def get_db():
    """Dependencia de FastAPI: entrega una sesion y la cierra siempre.
    Si ocurre un error de conexion/consulta a la BD durante la request,
    queda registrado en la tabla system_logs (Modulo Transversal)."""
    db = SessionLocal()
    try:
        yield db
    except OperationalError as exc:
        # Import diferido para evitar import circular (log_service usa
        # SessionLocal, definido en este mismo modulo).
        from .log_service import log_error_bd

        log_error_bd(f"Error de conexion/consulta a la base de datos: {exc}")
        raise
    finally:
        db.close()
