from datetime import datetime
from typing import Optional
from pydantic import BaseModel, EmailStr, Field

from .models import RolUsuario, TipoSensor

# ---------- Auth / Usuarios ----------


class UsuarioRegistro(BaseModel):
    nombre_completo: str = Field(min_length=3, max_length=150)
    correo: EmailStr
    password: str = Field(min_length=8, description="Minimo 8 caracteres")
    rol: RolUsuario = RolUsuario.aprendiz


class UsuarioLogin(BaseModel):
    correo: EmailStr
    password: str


class UsuarioOut(BaseModel):
    id: str
    nombre_completo: str
    correo: EmailStr
    rol: RolUsuario
    activo: bool
    creado_en: datetime

    class Config:
        from_attributes = True


class UsuarioUpdateRol(BaseModel):
    rol: RolUsuario


class Token(BaseModel):
    access_token: str
    token_type: str = "bearer"
    usuario: UsuarioOut


# ---------- Pilas ----------


class PilaCreate(BaseModel):
    nombre: str = Field(min_length=2, max_length=100)
    ubicacion: Optional[str] = None
    latitud: Optional[float] = None
    longitud: Optional[float] = None
    responsable_id: Optional[str] = None


class PilaUpdate(BaseModel):
    nombre: Optional[str] = None
    ubicacion: Optional[str] = None
    latitud: Optional[float] = None
    longitud: Optional[float] = None
    estado: Optional[str] = None
    responsable_id: Optional[str] = None


class PilaOut(BaseModel):
    id: str
    nombre: str
    ubicacion: Optional[str]
    latitud: Optional[float]
    longitud: Optional[float]
    estado: str
    responsable_id: Optional[str]
    creado_en: datetime

    class Config:
        from_attributes = True


# ---------- Sensores ----------


class SensorCreate(BaseModel):
    tipo: TipoSensor
    codigo_dispositivo: str = Field(min_length=3, max_length=60)
    pila_id: str


class SensorUpdate(BaseModel):
    tipo: Optional[TipoSensor] = None
    codigo_dispositivo: Optional[str] = None
    activo: Optional[bool] = None


class SensorOut(BaseModel):
    id: str
    tipo: TipoSensor
    codigo_dispositivo: str
    pila_id: str
    activo: bool
    creado_en: datetime

    class Config:
        from_attributes = True
