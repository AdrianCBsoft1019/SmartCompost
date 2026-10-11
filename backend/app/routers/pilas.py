from datetime import datetime, timedelta
from typing import Optional

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session

from .. import models, pila_service, schemas, security
from ..database import get_db

router = APIRouter(prefix="/pilas", tags=["Pilas"])

solo_instructor = security.require_role(models.RolUsuario.instructor)


def _buscar_pila(db: Session, pila_id: str) -> models.Pila:
    pila = db.query(models.Pila).filter(models.Pila.id == pila_id).first()
    if not pila:
        raise HTTPException(status_code=404, detail="Pila no encontrada")
    return pila


def _validar_responsable(db: Session, responsable_id: Optional[str]) -> None:
    if not responsable_id:
        return
    existe = (
        db.query(models.Usuario).filter(models.Usuario.id == responsable_id).first()
    )
    if not existe:
        raise HTTPException(status_code=404, detail="El responsable indicado no existe")


@router.post("/", response_model=schemas.PilaOut, status_code=status.HTTP_201_CREATED)
def crear_pila(
    datos: schemas.PilaCreate,
    db: Session = Depends(get_db),
    current_user: models.Usuario = Depends(solo_instructor),
):
    _validar_responsable(db, datos.responsable_id)
    valores = datos.model_dump(exclude_none=True)
    nueva_pila = models.Pila(**valores)
    db.add(nueva_pila)
    db.commit()
    db.refresh(nueva_pila)
    return pila_service.a_salida(nueva_pila, db)


@router.get("/", response_model=list[schemas.PilaOut])
def listar_pilas(
    q: Optional[str] = None,
    fase: Optional[str] = None,
    ubicacion: Optional[str] = None,
    estado: Optional[str] = None,
    db: Session = Depends(get_db),
    current_user: models.Usuario = Depends(security.get_current_user),
):
    """Listado con filtros: q (nombre), fase, ubicacion y estado."""
    query = db.query(models.Pila)
    if q:
        query = query.filter(models.Pila.nombre.ilike(f"%{q}%"))
    if ubicacion:
        query = query.filter(models.Pila.ubicacion == ubicacion)
    if estado:
        query = query.filter(models.Pila.estado == estado)
    salida = [pila_service.a_salida(p, db) for p in query.all()]
    if fase:
        # La fase se calcula (no se guarda), por eso se filtra en memoria.
        salida = [p for p in salida if p["fase"] == fase]
    return salida


@router.post(
    "/{pila_id}/lecturas",
    response_model=schemas.LecturaEvaluadaOut,
    status_code=status.HTTP_201_CREATED,
)
def registrar_lectura(
    pila_id: str,
    datos: schemas.LecturaCreate,
    db: Session = Depends(get_db),
    current_user: models.Usuario = Depends(security.get_current_user),
):
    """Flujo end-to-end: la lectura se guarda, se evalua contra los limites
    y el estado de la pila se actualiza (normal / atencion / critico / listo).
    """
    pila = _buscar_pila(db, pila_id)
    if datos.sensor_id:
        sensor = (
            db.query(models.Sensor)
            .filter(
                models.Sensor.id == datos.sensor_id, models.Sensor.pila_id == pila_id
            )
            .first()
        )
        if not sensor:
            raise HTTPException(
                status_code=404, detail="El sensor no pertenece a esta pila"
            )

    lectura = models.Lectura(pila_id=pila_id, **datos.model_dump())
    db.add(lectura)

    evaluacion = pila_service.evaluar_lectura(lectura)
    madurez = pila_service.calcular_madurez(pila.fecha_inicio, pila.dias_ciclo)
    pila.estado = pila_service.estado_desde_semaforo(
        evaluacion["semaforo"], madurez["madurez_pct"]
    )
    db.commit()
    db.refresh(lectura)
    return {"lectura": lectura, "evaluacion": evaluacion}


@router.get("/{pila_id}", response_model=schemas.PilaOut)
def obtener_pila(
    pila_id: str,
    db: Session = Depends(get_db),
    current_user: models.Usuario = Depends(security.get_current_user),
):
    return pila_service.a_salida(_buscar_pila(db, pila_id), db)


@router.get("/{pila_id}/detalle", response_model=schemas.PilaDetalleOut)
def detalle_pila(
    pila_id: str,
    db: Session = Depends(get_db),
    current_user: models.Usuario = Depends(security.get_current_user),
):
    """Todo lo que necesita la vista de detalle en una sola peticion."""
    pila = _buscar_pila(db, pila_id)
    lectura = pila_service.ultima_lectura(db, pila_id)
    if lectura:
        evaluacion = pila_service.evaluar_lectura(lectura)
    else:
        evaluacion = {"semaforo": "verde", "indicador": "seguro", "violaciones": []}
    madurez = pila_service.calcular_madurez(pila.fecha_inicio, pila.dias_ciclo)
    return {
        "pila": pila_service.a_salida(pila, db),
        "evaluacion": evaluacion,
        "gases": {
            "co2_ppm": lectura.co2_ppm if lectura else None,
            "ch4_ppm": lectura.ch4_ppm if lectura else None,
            "nh3_ppm": lectura.nh3_ppm if lectura else None,
        },
        "serie_24h": pila_service.serie_por_hora(db, pila_id, 24),
        "dias_transcurridos": madurez["dias_transcurridos"],
    }


@router.get("/{pila_id}/lecturas", response_model=list[schemas.LecturaOut])
def listar_lecturas(
    pila_id: str,
    horas: int = 24,
    db: Session = Depends(get_db),
    current_user: models.Usuario = Depends(security.get_current_user),
):
    _buscar_pila(db, pila_id)
    desde = datetime.utcnow() - timedelta(hours=max(1, min(horas, 24 * 365)))
    return (
        db.query(models.Lectura)
        .filter(models.Lectura.pila_id == pila_id, models.Lectura.creado_en >= desde)
        .order_by(models.Lectura.creado_en)
        .all()
    )


@router.put("/{pila_id}", response_model=schemas.PilaOut)
def actualizar_pila(
    pila_id: str,
    datos: schemas.PilaUpdate,
    db: Session = Depends(get_db),
    current_user: models.Usuario = Depends(solo_instructor),
):
    pila = _buscar_pila(db, pila_id)
    cambios = datos.model_dump(exclude_unset=True)
    if "responsable_id" in cambios:
        _validar_responsable(db, cambios["responsable_id"])
    for campo, valor in cambios.items():
        setattr(pila, campo, valor)
    db.commit()
    db.refresh(pila)
    return pila_service.a_salida(pila, db)


@router.delete("/{pila_id}", status_code=status.HTTP_204_NO_CONTENT)
def eliminar_pila(
    pila_id: str,
    db: Session = Depends(get_db),
    current_user: models.Usuario = Depends(solo_instructor),
):
    pila = _buscar_pila(db, pila_id)
    db.delete(pila)
    db.commit()
    return None
