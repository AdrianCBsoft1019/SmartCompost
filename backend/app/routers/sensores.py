from typing import Optional

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session

from .. import models, schemas, security
from ..database import get_db

router = APIRouter(prefix="/sensores", tags=["Sensores"])

# El instructor (administrador) gestiona sensores; el aprendiz (estudiante)
# solo los consulta.
solo_instructor = security.require_role(models.RolUsuario.instructor)


def _buscar_sensor(db: Session, sensor_id: str) -> models.Sensor:
    sensor = db.query(models.Sensor).filter(models.Sensor.id == sensor_id).first()
    if not sensor:
        raise HTTPException(status_code=404, detail="Sensor no encontrado")
    return sensor


def _validar_pila(db: Session, pila_id: str) -> None:
    pila = db.query(models.Pila).filter(models.Pila.id == pila_id).first()
    if not pila:
        raise HTTPException(status_code=404, detail="La pila indicada no existe")


def _validar_codigo_libre(
    db: Session, codigo: str, excluir_id: Optional[str] = None
) -> None:
    consulta = db.query(models.Sensor).filter(
        models.Sensor.codigo_dispositivo == codigo
    )
    if excluir_id:
        consulta = consulta.filter(models.Sensor.id != excluir_id)
    if consulta.first():
        raise HTTPException(
            status_code=400, detail="El codigo de dispositivo ya esta registrado"
        )


def _a_salida(sensor: models.Sensor) -> dict:
    """Sensor ORM -> dict de SensorOut (con nombre y planta de su pila)."""
    return {
        "id": sensor.id,
        "tipo": sensor.tipo,
        "codigo_dispositivo": sensor.codigo_dispositivo,
        "pila_id": sensor.pila_id,
        "activo": bool(sensor.activo),
        "creado_en": sensor.creado_en,
        "pila_nombre": sensor.pila.nombre if sensor.pila else None,
        "ubicacion": sensor.pila.ubicacion if sensor.pila else None,
    }


@router.post("/", response_model=schemas.SensorOut, status_code=status.HTTP_201_CREATED)
def crear_sensor(
    datos: schemas.SensorCreate,
    db: Session = Depends(get_db),
    current_user: models.Usuario = Depends(solo_instructor),
):
    _validar_pila(db, datos.pila_id)
    codigo = datos.codigo_dispositivo.strip()
    _validar_codigo_libre(db, codigo)

    nuevo_sensor = models.Sensor(
        **datos.model_dump(exclude={"codigo_dispositivo"}),
        codigo_dispositivo=codigo,
    )
    db.add(nuevo_sensor)
    db.commit()
    db.refresh(nuevo_sensor)
    return _a_salida(nuevo_sensor)


@router.get("/", response_model=list[schemas.SensorOut])
def listar_sensores(
    pila_id: Optional[str] = None,
    tipo: Optional[models.TipoSensor] = None,
    activo: Optional[bool] = None,
    q: Optional[str] = None,
    db: Session = Depends(get_db),
    current_user: models.Usuario = Depends(security.get_current_user),
):
    """Listado con filtros: pila_id, tipo, activo y q (codigo del dispositivo)."""
    query = db.query(models.Sensor)
    if pila_id:
        query = query.filter(models.Sensor.pila_id == pila_id)
    if tipo:
        query = query.filter(models.Sensor.tipo == tipo)
    if activo is not None:
        query = query.filter(models.Sensor.activo == activo)
    if q:
        query = query.filter(models.Sensor.codigo_dispositivo.ilike(f"%{q}%"))
    return [_a_salida(s) for s in query.order_by(models.Sensor.codigo_dispositivo)]


@router.get("/{sensor_id}", response_model=schemas.SensorOut)
def obtener_sensor(
    sensor_id: str,
    db: Session = Depends(get_db),
    current_user: models.Usuario = Depends(security.get_current_user),
):
    return _a_salida(_buscar_sensor(db, sensor_id))


@router.put("/{sensor_id}", response_model=schemas.SensorOut)
def actualizar_sensor(
    sensor_id: str,
    datos: schemas.SensorUpdate,
    db: Session = Depends(get_db),
    current_user: models.Usuario = Depends(solo_instructor),
):
    sensor = _buscar_sensor(db, sensor_id)
    cambios = datos.model_dump(exclude_unset=True)
    if "codigo_dispositivo" in cambios:
        cambios["codigo_dispositivo"] = (cambios["codigo_dispositivo"] or "").strip()
        _validar_codigo_libre(db, cambios["codigo_dispositivo"], excluir_id=sensor.id)
    if "pila_id" in cambios:
        _validar_pila(db, cambios["pila_id"])
    for campo, valor in cambios.items():
        # tipo, pila_id y activo no admiten null (son obligatorios en la BD).
        if valor is None and campo != "codigo_dispositivo":
            continue
        setattr(sensor, campo, valor)
    db.commit()
    db.refresh(sensor)
    return _a_salida(sensor)


@router.delete("/{sensor_id}", status_code=status.HTTP_204_NO_CONTENT)
def eliminar_sensor(
    sensor_id: str,
    db: Session = Depends(get_db),
    current_user: models.Usuario = Depends(solo_instructor),
):
    sensor = _buscar_sensor(db, sensor_id)
    db.delete(sensor)
    db.commit()
    return None
