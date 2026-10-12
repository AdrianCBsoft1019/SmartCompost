"""Esquemas de la vista de Alertas."""

from datetime import date, datetime
from typing import Optional

from pydantic import BaseModel


class AlertaOut(BaseModel):
    id: str  # "<lectura_id>:<variable>"
    pila_id: str
    pila: str
    ubicacion: Optional[str] = None
    variable: str  # temperatura | humedad | co2_ppm | ch4_ppm | nh3_ppm
    nombre: str
    valor: float
    limite: float
    lado: str  # maximo | minimo
    mensaje: str
    sensor_codigo: Optional[str] = None
    fecha: datetime
    activa: bool  # True si es la ultima lectura de la pila y sigue fuera de limite


class ConteoVariable(BaseModel):
    variable: str
    nombre: str
    total: int


class ConteoPila(BaseModel):
    pila_id: str
    pila: str
    ubicacion: Optional[str] = None
    total: int


class ConteoSensor(BaseModel):
    sensor_id: str
    codigo: str
    tipo: str
    pila: str
    total: int


class ConteoDia(BaseModel):
    fecha: date
    total: int


class AlertasResumenOut(BaseModel):
    periodo: str
    desde: datetime
    hasta: datetime
    total_alertas: int
    alertas_activas: int
    total_lecturas: int
    lecturas_fuera_de_limite: int
    porcentaje_fuera_de_limite: float
    por_variable: list[ConteoVariable]
    por_pila: list[ConteoPila]
    por_sensor: list[ConteoSensor]
    por_dia: list[ConteoDia]
