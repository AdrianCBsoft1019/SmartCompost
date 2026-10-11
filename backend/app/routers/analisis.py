from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session

from .. import analisis_service, models, schemas, security
from ..database import get_db

router = APIRouter(prefix="/analisis", tags=["Analisis"])


def _periodo_valido(periodo: str) -> str:
    if periodo not in analisis_service.PERIODOS:
        raise HTTPException(
            status_code=400, detail="Periodo invalido: usa semana, mes o anio"
        )
    return periodo


@router.get("/resumen", response_model=schemas.AnalisisResumenOut)
def resumen_analisis(
    periodo: str = "semana",
    db: Session = Depends(get_db),
    current_user: models.Usuario = Depends(security.get_current_user),
):
    """Vista de Analisis completa. Disponible para instructor y aprendiz
    (el aprendiz solo consulta: no hay endpoints de escritura aqui)."""
    return analisis_service.resumen(db, _periodo_valido(periodo))


@router.get("/sensores", response_model=list[schemas.PlantaSensores])
def filtro_sensores(
    periodo: str = "semana",
    db: Session = Depends(get_db),
    current_user: models.Usuario = Depends(security.get_current_user),
):
    """Filtro 'Sensores': sensores por planta + estadisticas de alteracion."""
    desde, _ = analisis_service.rango_periodo(_periodo_valido(periodo))
    _, por_variable = analisis_service.conteo_fuera_de_limite(db, desde)
    return analisis_service.sensores_por_planta(db, por_variable)


@router.get("/pilas", response_model=list[schemas.ComparativaPila])
def filtro_pilas(
    periodo: str = "semana",
    db: Session = Depends(get_db),
    current_user: models.Usuario = Depends(security.get_current_user),
):
    """Filtro 'Pilas': cada pila con su estado y promedios del periodo."""
    desde, _ = analisis_service.rango_periodo(_periodo_valido(periodo))
    por_pila, _ = analisis_service.conteo_fuera_de_limite(db, desde)
    return analisis_service.comparativa_pilas(db, desde, por_pila)
