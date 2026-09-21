"""
HU-10 - Acceso por roles.

Criterios de aceptacion cubiertos:
1) Se validan credenciales (login).
2) Instructor dispone de administracion/configuracion (ver require_role).
3) Aprendiz accede al modo permitido.
4) Contrasenas no se almacenan en texto plano (bcrypt).
"""
from fastapi import APIRouter, Depends, HTTPException, Request, status
from sqlalchemy.orm import Session

from .. import models, schemas, security
from ..database import get_db
from ..log_service import log_login_fallido

router = APIRouter(prefix="/auth", tags=["Autenticacion"])


@router.post("/register", response_model=schemas.UsuarioOut, status_code=status.HTTP_201_CREATED)
def registrar_usuario(datos: schemas.UsuarioRegistro, db: Session = Depends(get_db)):
    existente = db.query(models.Usuario).filter(models.Usuario.correo == datos.correo).first()
    if existente:
        raise HTTPException(status_code=400, detail="Ya existe un usuario con ese correo")

    nuevo_usuario = models.Usuario(
        nombre_completo=datos.nombre_completo,
        correo=datos.correo,
        password_hash=security.hash_password(datos.password),
        rol=datos.rol,
    )
    db.add(nuevo_usuario)
    db.commit()
    db.refresh(nuevo_usuario)
    return nuevo_usuario


@router.post("/login", response_model=schemas.Token)
def iniciar_sesion(datos: schemas.UsuarioLogin, request: Request, db: Session = Depends(get_db)):
    usuario = db.query(models.Usuario).filter(models.Usuario.correo == datos.correo).first()

    if not usuario or not security.verify_password(datos.password, usuario.password_hash):
        # Modulo Transversal: registra el intento fallido en system_logs
        # (no distinguimos "correo no existe" de "password incorrecta"
        # en la respuesta al cliente, por seguridad, pero sí en el log).
        log_login_fallido(correo=datos.correo, origen_ip=request.client.host if request.client else None)
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Correo o contrasena incorrectos",
        )
    if not usuario.activo:
        raise HTTPException(status_code=403, detail="Usuario inactivo")

    access_token = security.create_access_token(data={"sub": usuario.id, "rol": usuario.rol.value})
    return schemas.Token(access_token=access_token, usuario=usuario)


@router.get("/me", response_model=schemas.UsuarioOut)
def obtener_perfil(current_user: models.Usuario = Depends(security.get_current_user)):
    return current_user
