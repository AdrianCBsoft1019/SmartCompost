from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session

from .. import models, schemas, security
from ..database import get_db

router = APIRouter(prefix="/usuarios", tags=["Usuarios"])


@router.get("/", response_model=list[schemas.UsuarioOut])
def listar_usuarios(
    db: Session = Depends(get_db),
    current_user: models.Usuario = Depends(
        security.require_role(models.RolUsuario.instructor)
    ),
):
    """Solo el rol instructor puede listar todos los usuarios (HU-10.2)."""
    return db.query(models.Usuario).all()


@router.get("/{usuario_id}", response_model=schemas.UsuarioOut)
def obtener_usuario(
    usuario_id: str,
    db: Session = Depends(get_db),
    current_user: models.Usuario = Depends(security.get_current_user),
):
    usuario = db.query(models.Usuario).filter(models.Usuario.id == usuario_id).first()
    if not usuario:
        raise HTTPException(status_code=404, detail="Usuario no encontrado")
    return usuario


@router.patch("/{usuario_id}/rol", response_model=schemas.UsuarioOut)
def actualizar_rol(
    usuario_id: str,
    datos: schemas.UsuarioUpdateRol,
    db: Session = Depends(get_db),
    current_user: models.Usuario = Depends(
        security.require_role(models.RolUsuario.instructor)
    ),
):
    usuario = db.query(models.Usuario).filter(models.Usuario.id == usuario_id).first()
    if not usuario:
        raise HTTPException(status_code=404, detail="Usuario no encontrado")
    usuario.rol = datos.rol
    db.commit()
    db.refresh(usuario)
    return usuario


@router.delete("/{usuario_id}", status_code=204)
def desactivar_usuario(
    usuario_id: str,
    db: Session = Depends(get_db),
    current_user: models.Usuario = Depends(
        security.require_role(models.RolUsuario.instructor)
    ),
):
    usuario = db.query(models.Usuario).filter(models.Usuario.id == usuario_id).first()
    if not usuario:
        raise HTTPException(status_code=404, detail="Usuario no encontrado")
    usuario.activo = False
    db.commit()
    return None
