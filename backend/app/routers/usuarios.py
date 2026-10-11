from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session

from .. import models, schemas, security
from ..database import get_db

router = APIRouter(prefix="/usuarios", tags=["Usuarios"])

solo_instructor = security.require_role(models.RolUsuario.instructor)


def _buscar_usuario(db: Session, usuario_id: str) -> models.Usuario:
    usuario = db.query(models.Usuario).filter(models.Usuario.id == usuario_id).first()
    if not usuario:
        raise HTTPException(status_code=404, detail="Usuario no encontrado")
    return usuario


def _validar_correo_libre(db: Session, correo: str, excepto_id: str | None = None):
    query = db.query(models.Usuario).filter(models.Usuario.correo == correo)
    if excepto_id:
        query = query.filter(models.Usuario.id != excepto_id)
    if query.first():
        raise HTTPException(
            status_code=400, detail="Ya existe un usuario con ese correo"
        )


@router.get("/", response_model=list[schemas.UsuarioOut])
def listar_usuarios(
    db: Session = Depends(get_db),
    current_user: models.Usuario = Depends(solo_instructor),
):
    """Solo el rol instructor puede listar todos los usuarios (HU-10.2)."""
    return db.query(models.Usuario).order_by(models.Usuario.creado_en).all()


@router.post("/", response_model=schemas.UsuarioOut, status_code=201)
def crear_usuario(
    datos: schemas.UsuarioCreate,
    db: Session = Depends(get_db),
    current_user: models.Usuario = Depends(solo_instructor),
):
    """El instructor crea un perfil y le asigna el rol directamente."""
    _validar_correo_libre(db, datos.correo)
    nuevo = models.Usuario(
        nombre_completo=datos.nombre_completo,
        correo=datos.correo,
        password_hash=security.hash_password(datos.password),
        rol=datos.rol,
    )
    db.add(nuevo)
    db.commit()
    db.refresh(nuevo)
    return nuevo


@router.get("/me", response_model=schemas.UsuarioOut)
def mi_perfil(current_user: models.Usuario = Depends(security.get_current_user)):
    return current_user


@router.put("/me", response_model=schemas.UsuarioOut)
def editar_mi_perfil(
    datos: schemas.PerfilUpdate,
    db: Session = Depends(get_db),
    current_user: models.Usuario = Depends(security.get_current_user),
):
    """Edicion del propio perfil (clic en el logo de usuario).

    No permite cambiar el rol: eso solo lo hace el instructor.
    Para cambiar la contrasena hay que enviar la actual.
    """
    if datos.nombre_completo:
        current_user.nombre_completo = datos.nombre_completo
    if datos.correo and datos.correo != current_user.correo:
        _validar_correo_libre(db, datos.correo, current_user.id)
        current_user.correo = datos.correo
    if datos.password_nueva:
        if not datos.password_actual or not security.verify_password(
            datos.password_actual, current_user.password_hash
        ):
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="La contrasena actual no es correcta",
            )
        current_user.password_hash = security.hash_password(datos.password_nueva)
    db.commit()
    db.refresh(current_user)
    return current_user


@router.get("/{usuario_id}", response_model=schemas.UsuarioOut)
def obtener_usuario(
    usuario_id: str,
    db: Session = Depends(get_db),
    current_user: models.Usuario = Depends(solo_instructor),
):
    return _buscar_usuario(db, usuario_id)


@router.put("/{usuario_id}", response_model=schemas.UsuarioOut)
def actualizar_usuario(
    usuario_id: str,
    datos: schemas.UsuarioUpdate,
    db: Session = Depends(get_db),
    current_user: models.Usuario = Depends(solo_instructor),
):
    usuario = _buscar_usuario(db, usuario_id)
    cambios = datos.model_dump(exclude_unset=True)

    if usuario.id == current_user.id and (
        cambios.get("activo") is False
        or ("rol" in cambios and cambios["rol"] != current_user.rol)
    ):
        raise HTTPException(
            status_code=400,
            detail="No puedes desactivarte ni quitarte tu propio rol de instructor",
        )
    if "correo" in cambios and cambios["correo"] != usuario.correo:
        _validar_correo_libre(db, cambios["correo"], usuario.id)

    password = cambios.pop("password", None)
    for campo, valor in cambios.items():
        setattr(usuario, campo, valor)
    if password:
        usuario.password_hash = security.hash_password(password)
    db.commit()
    db.refresh(usuario)
    return usuario


@router.patch("/{usuario_id}/rol", response_model=schemas.UsuarioOut)
def actualizar_rol(
    usuario_id: str,
    datos: schemas.UsuarioUpdateRol,
    db: Session = Depends(get_db),
    current_user: models.Usuario = Depends(solo_instructor),
):
    usuario = _buscar_usuario(db, usuario_id)
    if usuario.id == current_user.id and datos.rol != current_user.rol:
        raise HTTPException(status_code=400, detail="No puedes cambiar tu propio rol")
    usuario.rol = datos.rol
    db.commit()
    db.refresh(usuario)
    return usuario


@router.delete("/{usuario_id}", status_code=204)
def desactivar_usuario(
    usuario_id: str,
    db: Session = Depends(get_db),
    current_user: models.Usuario = Depends(solo_instructor),
):
    """Baja logica: el usuario queda inactivo y no puede iniciar sesion.

    No se borra la fila porque las pilas lo referencian como responsable.
    """
    usuario = _buscar_usuario(db, usuario_id)
    if usuario.id == current_user.id:
        raise HTTPException(status_code=400, detail="No puedes desactivarte a ti mismo")
    usuario.activo = False
    db.commit()
    return None
