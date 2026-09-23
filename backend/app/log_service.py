import logging
from pathlib import Path

from .database import SessionLocal
from .log_model import SystemLog, NivelLog

_fallback_logger = logging.getLogger("smartcompost.fallback")
_fallback_logger.setLevel(logging.WARNING)
_fallback_path = Path(__file__).resolve().parent.parent / "fallback.log"
if not _fallback_logger.handlers:
    _handler = logging.FileHandler(_fallback_path)
    _handler.setFormatter(logging.Formatter("%(asctime)s %(levelname)s %(message)s"))
    _fallback_logger.addHandler(_handler)


def registrar_evento(
    nivel: NivelLog, mensaje: str, origen_ip: str | None = None
) -> None:
    """Inserta un registro en system_logs. Nunca lanza excepcion hacia
    arriba: un fallo al loggear no debe tumbar la request original."""
    db = SessionLocal()
    try:
        entrada = SystemLog(nivel=nivel, mensaje=mensaje[:500], origen_ip=origen_ip)
        db.add(entrada)
        db.commit()
    except Exception as exc:
        _fallback_logger.error(
            "No se pudo escribir en system_logs: %s | evento original: %s", exc, mensaje
        )
    finally:
        db.close()


def log_error_bd(mensaje: str, origen_ip: str | None = None) -> None:
    registrar_evento(NivelLog.ERROR, f"[DB] {mensaje}", origen_ip)


def log_login_fallido(correo: str, origen_ip: str | None = None) -> None:
    registrar_evento(
        NivelLog.WARNING,
        f"Intento de login fallido para correo '{correo}'",
        origen_ip,
    )


def log_info(mensaje: str, origen_ip: str | None = None) -> None:
    registrar_evento(NivelLog.INFO, mensaje, origen_ip)
