from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session

from .. import models, schemas, security
from ..database import get_db

router = APIRouter(prefix="/pilas", tags=["Pilas"])


@router.post("/", response_model=schemas.PilaOut, status_code=status.HTTP_201_CREATED)
def crear_pila(
    datos: schemas.PilaCreate,
    db: Session = Depends(get_db),
    current_user: models.Usuario = Depends(security.get_current_user),
):
    nueva_pila = models.Pila(**datos.model_dump())
    db.add(nueva_pila)
    db.commit()
    db.refresh(nueva_pila)
    return nueva_pila


@router.get("/", response_model=list[schemas.PilaOut])
def listar_pilas(
    db: Session = Depends(get_db),
    current_user: models.Usuario = Depends(security.get_current_user),
):
    return db.query(models.Pila).all()


@router.get("/{pila_id}", response_model=schemas.PilaOut)
def obtener_pila(
    pila_id: str,
    db: Session = Depends(get_db),
    current_user: models.Usuario = Depends(security.get_current_user),
):
    pila = db.query(models.Pila).filter(models.Pila.id == pila_id).first()
    if not pila:
        raise HTTPException(status_code=404, detail="Pila no encontrada")
    return pila


@router.put("/{pila_id}", response_model=schemas.PilaOut)
def actualizar_pila(
    pila_id: str,
    datos: schemas.PilaUpdate,
    db: Session = Depends(get_db),
    current_user: models.Usuario = Depends(security.get_current_user),
):
    pila = db.query(models.Pila).filter(models.Pila.id == pila_id).first()
    if not pila:
        raise HTTPException(status_code=404, detail="Pila no encontrada")
    for campo, valor in datos.model_dump(exclude_unset=True).items():
        setattr(pila, campo, valor)
    db.commit()
    db.refresh(pila)
    return pila


@router.delete("/{pila_id}", status_code=status.HTTP_204_NO_CONTENT)
def eliminar_pila(
    pila_id: str,
    db: Session = Depends(get_db),
    current_user: models.Usuario = Depends(security.require_role(models.RolUsuario.instructor)),
):
    pila = db.query(models.Pila).filter(models.Pila.id == pila_id).first()
    if not pila:
        raise HTTPException(status_code=404, detail="Pila no encontrada")
    db.delete(pila)
    db.commit()
    return None
