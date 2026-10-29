from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session

from .. import models, schemas, security
from ..database import get_db

router = APIRouter(prefix="/notificaciones", tags=["Notificaciones"])

_TIPO_TEXTO = {
    "temperatura": "de temperatura",
    "humedad": "de humedad",
    "ph": "de pH",
    "gas_ch4": "de gas CH4",
    "nivel_agua": "de nivel de agua",
}


def _mensaje(sensor: models.Sensor, pila_nombre: str) -> str:
    tipo = _TIPO_TEXTO.get(sensor.tipo.value, sensor.tipo.value)
    return (
        f"El sensor {tipo} {sensor.codigo_dispositivo} de la pila {pila_nombre} "
        f"está dañado: {sensor.detalle_dano}. Se requiere su arreglo para "
        "continuar con el proceso de compostaje de la pila."
    )


def _a_notificacion(sensor: models.Sensor) -> dict:
    """Sensor dañado -> dict de NotificacionOut."""
    pila_nombre = sensor.pila.nombre if sensor.pila else None
    return {
        "id": f"sensor-danado:{sensor.id}",
        "tipo": "sensor_danado",
        "sensor_id": sensor.id,
        "sensor_codigo": sensor.codigo_dispositivo,
        "sensor_tipo": sensor.tipo.value,
        "pila_id": sensor.pila_id,
        "pila_nombre": pila_nombre,
        "ubicacion": sensor.pila.ubicacion if sensor.pila else None,
        "detalle": sensor.detalle_dano or "",
        "mensaje": _mensaje(sensor, pila_nombre or "sin pila"),
        "fecha": sensor.danado_en,
    }


@router.get("/", response_model=list[schemas.NotificacionOut])
def listar_notificaciones(
    db: Session = Depends(get_db),
    current_user: models.Usuario = Depends(security.get_current_user),
):
    """Avisos activos para administrador y estudiante.

    Hay un aviso por cada sensor dañado, el más reciente primero. El aviso
    desaparece cuando el administrador marca el sensor como reparado.
    """
    sensores = (
        db.query(models.Sensor)
        .filter(models.Sensor.danado.is_(True))
        .order_by(models.Sensor.danado_en.desc())
        .all()
    )
    return [_a_notificacion(s) for s in sensores]
