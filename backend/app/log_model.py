"""
Tabla de Trazabilidad Ciega (system_logs).

Requisito del Modulo Transversal: tabla independiente, SIN llaves
foraneas complejas, para registrar eventos criticos del sistema
(errores de conexion a BD, intentos de login fallidos, etc.)
"""

import enum
import uuid
from datetime import datetime

from sqlalchemy import Column, String, DateTime, Enum

from .database import Base


def gen_uuid():
    return str(uuid.uuid4())


# Mismo criterio que en models.py: MySQL/MariaDB no tiene tipo UUID nativo.
UUID = lambda **kwargs: String(36)  # noqa: E731


class NivelLog(str, enum.Enum):
    INFO = "INFO"
    WARNING = "WARNING"
    ERROR = "ERROR"


class SystemLog(Base):
    __tablename__ = "system_logs"

    id = Column(UUID(as_uuid=False), primary_key=True, default=gen_uuid)
    fecha_hora = Column(DateTime, default=datetime.utcnow, nullable=False)
    nivel = Column(Enum(NivelLog), nullable=False, default=NivelLog.INFO)
    origen_ip = Column(String(45), nullable=True)  # 45 = soporta IPv6
    mensaje = Column(String(500), nullable=False)

    # Nota: a proposito NO tiene ForeignKey hacia usuarios/pilas/etc.
    # Es una tabla "ciega" e independiente, tal como pide el requisito,
    # para que siga funcionando aunque el resto del esquema falle o
    # cambie (es la primera linea de auditoria del sistema).
