from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session

from .. import models, schemas, security
from ..database import get_db

router = APIRouter(prefix="/sensores", tags=["Sensores"])


@router.post("/", response_model=schemas.SensorOut, status_code=status.HTTP_201_CREATED)
def crear_sensor(
    datos: schemas.SensorCreate,
    db: Session = Depends(get_db),
    current_user: models.Usuario = Depends(security.get_current_user),
):
    pila = db.query(models.Pila).filter(models.Pila.id == datos.pila_id).first()
    if not pila:
        raise HTTPException(status_code=404, detail="La pila indicada no existe")

    existente = (
        db.query(models.Sensor)
        .filter(models.Sensor.codigo_dispositivo == datos.codigo_dispositivo)
        .first()
    )
    if existente:
        raise HTTPException(status_code=400, detail="El codigo de dispositivo ya esta registrado")

    nuevo_sensor = models.Sensor(**datos.model_dump())
    db.add(nuevo_sensor)
    db.commit()
    db.refresh(nuevo_sensor)
    return nuevo_sensor


@router.get("/", response_model=list[schemas.SensorOut])
def listar_sensores(
    pila_id: str | None = None,
    db: Session = Depends(get_db),
    current_user: models.Usuario = Depends(security.get_current_user),
):
    query = db.query(models.Sensor)
    if pila_id:
        query = query.filter(models.Sensor.pila_id == pila_id)
    return query.all()


@router.get("/{sensor_id}", response_model=schemas.SensorOut)
def obtener_sensor(
    sensor_id: str,
    db: Session = Depends(get_db),
    current_user: models.Usuario = Depends(security.get_current_user),
):
    sensor = db.query(models.Sensor).filter(models.Sensor.id == sensor_id).first()
    if not sensor:
        raise HTTPException(status_code=404, detail="Sensor no encontrado")
    return sensor


@router.put("/{sensor_id}", response_model=schemas.SensorOut)
def actualizar_sensor(
    sensor_id: str,
    datos: schemas.SensorUpdate,
    db: Session = Depends(get_db),
    current_user: models.Usuario = Depends(security.get_current_user),
):
    sensor = db.query(models.Sensor).filter(models.Sensor.id == sensor_id).first()
    if not sensor:
        raise HTTPException(status_code=404, detail="Sensor no encontrado")
    for campo, valor in datos.model_dump(exclude_unset=True).items():
        setattr(sensor, campo, valor)
    db.commit()
    db.refresh(sensor)
    return sensor


@router.delete("/{sensor_id}", status_code=status.HTTP_204_NO_CONTENT)
def eliminar_sensor(
    sensor_id: str,
    db: Session = Depends(get_db),
    current_user: models.Usuario = Depends(security.require_role(models.RolUsuario.instructor)),
):
    sensor = db.query(models.Sensor).filter(models.Sensor.id == sensor_id).first()
    if not sensor:
        raise HTTPException(status_code=404, detail="Sensor no encontrado")
    db.delete(sensor)
    db.commit()
    return None
