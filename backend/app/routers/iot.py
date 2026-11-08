"""Entrada de datos del prototipo fisico (Arduino UNO + ESP32).

El ESP32 no inicia sesion como un usuario: se identifica con la cabecera
`X-API-Key` (variable IOT_API_KEY del servidor) y con el codigo de un sensor
registrado en la pagina. La lectura se guarda en la pila de ese sensor y
pasa por la misma evaluacion (semaforo, estado, alertas) que una manual.
"""

import os
import secrets
from typing import Optional

from fastapi import APIRouter, Depends, Header, HTTPException, status
from sqlalchemy.orm import Session

from .. import gases_service, models, pila_service, schemas
from ..database import get_db

router = APIRouter(prefix="/iot", tags=["IoT (ESP32)"])


def verificar_dispositivo(x_api_key: Optional[str] = Header(default=None)) -> None:
    esperada = os.getenv("IOT_API_KEY", "")
    if not esperada:
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="Entrada IoT deshabilitada: falta IOT_API_KEY en el servidor",
        )
    if not x_api_key or not secrets.compare_digest(x_api_key, esperada):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Clave del dispositivo invalida",
        )


@router.post(
    "/lecturas",
    response_model=schemas.LecturaEvaluadaOut,
    status_code=status.HTTP_201_CREATED,
    dependencies=[Depends(verificar_dispositivo)],
)
def recibir_lectura(datos: schemas.LecturaDispositivoIn, db: Session = Depends(get_db)):
    codigo = datos.codigo_dispositivo.strip()
    sensor = (
        db.query(models.Sensor)
        .filter(models.Sensor.codigo_dispositivo == codigo)
        .first()
    )
    if not sensor:
        raise HTTPException(
            status_code=404,
            detail=f"Dispositivo '{codigo}' no registrado: crea un sensor con "
            "ese codigo en la pagina",
        )
    if not sensor.activo:
        raise HTTPException(status_code=409, detail="El sensor esta inactivo")

    valores = {
        "temperatura": datos.temperatura,
        "humedad": datos.humedad,
        "sensor_id": sensor.id,
        **gases_service.gases_desde_crudos(datos.mq2, datos.mq135),
    }
    lectura, evaluacion = pila_service.guardar_lectura(db, sensor.pila, valores)
    return {"lectura": lectura, "evaluacion": evaluacion}


@router.get("/calibracion", dependencies=[Depends(verificar_dispositivo)])
def calibrar_r0(mq2: Optional[int] = None, mq135: Optional[int] = None):
    """Con los sensores en aire limpio, pasa sus lecturas crudas y devuelve
    el R0 de cada uno para poner en MQ2_R0_KOHM / MQ135_R0_KOHM."""
    return {
        "rl_kohm": gases_service.RL_KOHM,
        "mq2_r0_kohm": gases_service.r0_en_aire_limpio(mq2, "mq2"),
        "mq135_r0_kohm": gases_service.r0_en_aire_limpio(mq135, "mq135"),
    }
