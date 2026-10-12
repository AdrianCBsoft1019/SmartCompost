from typing import Optional

from fastapi import APIRouter, Depends, HTTPException, Query, Response
from sqlalchemy.orm import Session

from .. import ( alertas_service, analisis_service, models, pila_service, reporte_alertas_pdf, security,)
from ..database import get_db
from ..schemas_alertas import AlertaOut, AlertasResumenOut

router = APIRouter(prefix="/alertas", tags=["Alertas"])


def _periodo_valido(periodo: str) -> str:
    if periodo not in analisis_service.PERIODOS:
        raise HTTPException(
            status_code=400, detail="Periodo invalido: usa semana, mes o anio"
        )
    return periodo


@router.get("/", response_model=list[AlertaOut])
def listar_alertas(
    periodo: str = "semana",
    pila_id: Optional[str] = None,
    variable: Optional[str] = None,
    solo_activas: bool = False,
    limite: int = Query(default=100, ge=1, le=500),
    db: Session = Depends(get_db),
    current_user: models.Usuario = Depends(security.get_current_user),
):
    """Alertas por limites superados. Disponible para instructor y aprendiz
    (solo lectura). Filtros: periodo, pila_id, variable y solo_activas."""
    desde, _ = analisis_service.rango_periodo(_periodo_valido(periodo))
    if variable and variable not in pila_service.LIMITES:
        raise HTTPException(
            status_code=400,
            detail="Variable invalida: " + ", ".join(pila_service.LIMITES),
        )
    if pila_id and not db.query(models.Pila).filter(models.Pila.id == pila_id).first():
        raise HTTPException(status_code=404, detail="Pila no encontrada")
    return alertas_service.listar_alertas(
        db, desde, pila_id, variable, solo_activas, limite
    )


@router.get("/resumen", response_model=AlertasResumenOut)
def resumen_alertas(
    periodo: str = "semana",
    db: Session = Depends(get_db),
    current_user: models.Usuario = Depends(security.get_current_user),
):
    """Analisis de las alertas: totales, por variable, pila, sensor y dia."""
    return alertas_service.resumen_alertas(db, _periodo_valido(periodo))


@router.get("/reporte.pdf")
def descargar_reporte(
    periodo: str = "semana",
    db: Session = Depends(get_db),
    current_user: models.Usuario = Depends(security.get_current_user),
):
    """Boton 'Descargar PDF' de la vista de Alertas."""
    _periodo_valido(periodo)
    desde, _ = analisis_service.rango_periodo(periodo)
    resumen = alertas_service.resumen_alertas(db, periodo)
    activas = alertas_service.listar_alertas(db, desde, solo_activas=True, limite=100)
    recientes = alertas_service.listar_alertas(db, desde, limite=50)
    return Response(
        content=reporte_alertas_pdf.generar_pdf(resumen, activas, recientes),
        media_type="application/pdf",
        headers={
            "Content-Disposition": f'attachment; filename="alertas_{periodo}.pdf"'
        },
    )
