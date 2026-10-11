from datetime import datetime
from typing import Optional
from pydantic import BaseModel, EmailStr, Field

from .models import RolUsuario, TipoSensor


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
    tiene_foto: bool = False

    class Config:
        from_attributes = True


class UsuarioUpdateRol(BaseModel):
    rol: RolUsuario


class UsuarioCreate(BaseModel):
    """El instructor crea perfiles y les asigna rol."""

    nombre_completo: str = Field(min_length=3, max_length=150)
    correo: EmailStr
    password: str = Field(min_length=8)
    rol: RolUsuario = RolUsuario.aprendiz


class UsuarioUpdate(BaseModel):
    """Edicion de un perfil por el instructor."""

    nombre_completo: Optional[str] = Field(default=None, min_length=3, max_length=150)
    correo: Optional[EmailStr] = None
    rol: Optional[RolUsuario] = None
    activo: Optional[bool] = None
    password: Optional[str] = Field(default=None, min_length=8)


class PerfilUpdate(BaseModel):
    """Edicion del propio perfil (clic en el logo de usuario)."""

    nombre_completo: Optional[str] = Field(default=None, min_length=3, max_length=150)
    correo: Optional[EmailStr] = None
    password_actual: Optional[str] = None
    password_nueva: Optional[str] = Field(default=None, min_length=8)


class Token(BaseModel):
    access_token: str
    token_type: str = "bearer"
    usuario: UsuarioOut


class PilaCreate(BaseModel):
    nombre: str = Field(min_length=2, max_length=100)
    ubicacion: Optional[str] = None
    latitud: Optional[float] = None
    longitud: Optional[float] = None
    responsable_id: Optional[str] = None
    fecha_inicio: Optional[datetime] = None
    dias_ciclo: int = Field(default=90, ge=30, le=365)


class PilaUpdate(BaseModel):
    nombre: Optional[str] = Field(default=None, min_length=2, max_length=100)
    ubicacion: Optional[str] = None
    latitud: Optional[float] = None
    longitud: Optional[float] = None
    estado: Optional[str] = None
    responsable_id: Optional[str] = None
    fecha_inicio: Optional[datetime] = None
    dias_ciclo: Optional[int] = Field(default=None, ge=30, le=365)


class PilaOut(BaseModel):
    """Pila + datos calculados (fase, maduracion, ultima lectura)."""

    id: str
    nombre: str
    ubicacion: Optional[str]
    latitud: Optional[float]
    longitud: Optional[float]
    estado: str
    responsable_id: Optional[str]
    creado_en: datetime
    fecha_inicio: datetime
    dias_ciclo: int
    fase: str
    madurez_pct: float
    dias_faltantes_fase: int
    temperatura: Optional[float] = None
    humedad: Optional[float] = None


class LecturaCreate(BaseModel):
    temperatura: float = Field(ge=-20, le=120)
    humedad: float = Field(ge=0, le=100)
    co2_ppm: Optional[float] = Field(default=None, ge=0)
    ch4_ppm: Optional[float] = Field(default=None, ge=0)
    nh3_ppm: Optional[float] = Field(default=None, ge=0)
    sensor_id: Optional[str] = None


class LecturaOut(BaseModel):
    id: str
    pila_id: str
    temperatura: float
    humedad: float
    co2_ppm: Optional[float]
    ch4_ppm: Optional[float]
    nh3_ppm: Optional[float]
    creado_en: datetime

    class Config:
        from_attributes = True


class Evaluacion(BaseModel):
    """Resultado de comparar una lectura contra los limites de seguridad."""

    semaforo: str  # verde | amarillo | rojo
    indicador: str  # seguro | inseguro
    violaciones: list[str]


class LecturaEvaluadaOut(BaseModel):
    lectura: LecturaOut
    evaluacion: Evaluacion


class PuntoHora(BaseModel):
    hora: datetime
    temperatura: float
    humedad: float


class GasesActuales(BaseModel):
    co2_ppm: Optional[float]
    ch4_ppm: Optional[float]
    nh3_ppm: Optional[float]


class PilaDetalleOut(BaseModel):
    pila: PilaOut
    evaluacion: Evaluacion
    gases: GasesActuales
    serie_24h: list[PuntoHora]
    dias_transcurridos: int


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


class Promedios(BaseModel):
    temperatura: Optional[float]
    humedad: Optional[float]
    co2_ppm: Optional[float]
    ch4_ppm: Optional[float]
    nh3_ppm: Optional[float]


class ComparativaPila(BaseModel):
    pila_id: str
    nombre: str
    ubicacion: Optional[str]
    estado: str
    fase: str
    temperatura_prom: Optional[float]
    temperatura_max: Optional[float]
    humedad_prom: Optional[float]
    madurez_pct: float
    lecturas_fuera_limite: int


class AlertaActiva(BaseModel):
    pila_id: str
    pila: str
    mensaje: str


class PuntoTendencia(BaseModel):
    fecha: str
    co2_ppm: Optional[float]
    ch4_ppm: Optional[float]
    nh3_ppm: Optional[float]


class SensorEstado(BaseModel):
    id: str
    codigo: str
    tipo: str
    pila: str
    activo: bool
    alteraciones: int = 0


class PlantaSensores(BaseModel):
    planta: str
    total: int
    activos: int
    inactivos: int
    sensores: list[SensorEstado]


class AnalisisResumenOut(BaseModel):
    periodo: str
    desde: datetime
    hasta: datetime
    promedios: Promedios
    total_lecturas: int
    comparativa: list[ComparativaPila]
    alertas_activas: list[AlertaActiva]
    tendencia_semanal: list[PuntoTendencia]
    sensores_por_planta: list[PlantaSensores]
