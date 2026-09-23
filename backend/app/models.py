import enum
import uuid
from datetime import datetime

from sqlalchemy import Column, String, DateTime, Enum, ForeignKey, Float, Boolean
from sqlalchemy.orm import relationship

from .database import Base


def gen_uuid():
    return str(uuid.uuid4())

def UUID(**kwargs):
    return String(36)


class RolUsuario(str, enum.Enum):
    instructor = "instructor"
    aprendiz = "aprendiz"


class Usuario(Base):
    """HU-10: Acceso por roles."""

    __tablename__ = "usuarios"

    id = Column(UUID(as_uuid=False), primary_key=True, default=gen_uuid)
    nombre_completo = Column(String(150), nullable=False)
    correo = Column(String(150), unique=True, index=True, nullable=False)
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
    estado = Column(String(30), default="normal")
    responsable_id = Column(
        UUID(as_uuid=False), ForeignKey("usuarios.id"), nullable=True
    )
    creado_en = Column(DateTime, default=datetime.utcnow)

    responsable = relationship("Usuario", back_populates="pilas")
    sensores = relationship(
        "Sensor", back_populates="pila", cascade="all, delete-orphan"
    )


class TipoSensor(str, enum.Enum):
    humedad = "humedad"
    temperatura = "temperatura"
    ph = "ph"
    gas_ch4 = "gas_ch4"
    nivel_agua = "nivel_agua"


class Sensor(Base):

    __tablename__ = "sensores"

    id = Column(UUID(as_uuid=False), primary_key=True, default=gen_uuid)
    tipo = Column(Enum(TipoSensor), nullable=False)
    codigo_dispositivo = Column(String(60), unique=True, nullable=False)
    pila_id = Column(UUID(as_uuid=False), ForeignKey("pilas.id"), nullable=False)
    activo = Column(Boolean, default=True)
    creado_en = Column(DateTime, default=datetime.utcnow)

    pila = relationship("Pila", back_populates="sensores")
