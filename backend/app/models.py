"""
Modelos ORM de las entidades principales del MER (seccion 2.3 del
documento del proyecto). En Sprint 1-2 solo se modelan las entidades
base necesarias para login/roles y para dar soporte a los CRUDs
iniciales (Usuario, Pila, Sensor). Lecturas/Alertas/Intervenciones se
amplian en sprints posteriores (adquisicion de datos y reglas).
"""
import enum
import uuid
from datetime import datetime

from sqlalchemy import Column, String, DateTime, Enum, ForeignKey, Float, Boolean
from sqlalchemy.orm import relationship

from .database import Base


def gen_uuid():
    return str(uuid.uuid4())


# MySQL/MariaDB (XAMPP) no tiene un tipo UUID nativo como PostgreSQL,
# asi que los identificadores se guardan como texto de 36 caracteres
# (formato UUID estandar, ej. "550e8400-e29b-41d4-a716-446655440000").
UUID = lambda **kwargs: String(36)  # noqa: E731 - alias simple para no reescribir cada columna


class RolUsuario(str, enum.Enum):
    instructor = "instructor"
    aprendiz = "aprendiz"


class Usuario(Base):
    """HU-10: Acceso por roles."""
    __tablename__ = "usuarios"

    id = Column(UUID(as_uuid=False), primary_key=True, default=gen_uuid)
    nombre_completo = Column(String(150), nullable=False)
    correo = Column(String(150), unique=True, index=True, nullable=False)
    # Nunca se almacena la contrasena en texto plano (criterio HU-10.4)
    password_hash = Column(String(255), nullable=False)
    rol = Column(Enum(RolUsuario), nullable=False, default=RolUsuario.aprendiz)
    activo = Column(Boolean, default=True)
    creado_en = Column(DateTime, default=datetime.utcnow)

    pilas = relationship("Pila", back_populates="responsable")


class Pila(Base):
    """Pila de compostaje monitoreada por el sistema."""
    __tablename__ = "pilas"

    id = Column(UUID(as_uuid=False), primary_key=True, default=gen_uuid)
    nombre = Column(String(100), nullable=False)
    ubicacion = Column(String(150), nullable=True)
    latitud = Column(Float, nullable=True)
    longitud = Column(Float, nullable=True)
    estado = Column(String(30), default="normal")  # normal | advertencia | critico
    responsable_id = Column(UUID(as_uuid=False), ForeignKey("usuarios.id"), nullable=True)
    creado_en = Column(DateTime, default=datetime.utcnow)

    responsable = relationship("Usuario", back_populates="pilas")
    sensores = relationship("Sensor", back_populates="pila", cascade="all, delete-orphan")


class TipoSensor(str, enum.Enum):
    humedad = "humedad"
    temperatura = "temperatura"
    ph = "ph"
    gas_ch4 = "gas_ch4"
    nivel_agua = "nivel_agua"


class Sensor(Base):
    """Sensor fisico asociado a una pila (soporta HU-01, HU-02, HU-03, HU-13, HU-15)."""
    __tablename__ = "sensores"

    id = Column(UUID(as_uuid=False), primary_key=True, default=gen_uuid)
    tipo = Column(Enum(TipoSensor), nullable=False)
    codigo_dispositivo = Column(String(60), unique=True, nullable=False)
    pila_id = Column(UUID(as_uuid=False), ForeignKey("pilas.id"), nullable=False)
    activo = Column(Boolean, default=True)
    creado_en = Column(DateTime, default=datetime.utcnow)

    pila = relationship("Pila", back_populates="sensores")
