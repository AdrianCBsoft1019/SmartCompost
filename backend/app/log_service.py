"""
Servicio de trazabilidad. Escribe en la tabla `system_logs` cada vez que:
  - ocurre un error de conexion/consulta a la base de datos, o
  - se produce un intento de login fallido (password incorrecto).

Usa una sesion propia y de corta duracion (independiente de la sesion
de la request que fallo) para maximizar la probabilidad de que el
registro sí se guarde incluso si la operacion original fallo a mitad
de camino. Si el propio intento de escribir el log falla (por ejemplo,
la base de datos esta completamente caida), se hace un fallback a un
archivo de log local para no perder la evidencia del incidente.
"""
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


def registrar_evento(nivel: NivelLog, mensaje: str, origen_ip: str | None = None) -> None:
    """Inserta un registro en system_logs. Nunca lanza excepcion hacia
    arriba: un fallo al loggear no debe tumbar la request original."""
    db = SessionLocal()
    try:
        entrada = SystemLog(nivel=nivel, mensaje=mensaje[:500], origen_ip=origen_ip)
        db.add(entrada)
        db.commit()
    except Exception as exc:  # noqa: BLE001 - logging defensivo a proposito
        # Fallback: si ni siquiera se puede escribir en system_logs
        # (ej. la BD esta totalmente caida), no perdemos el evento.
        _fallback_logger.error("No se pudo escribir en system_logs: %s | evento original: %s", exc, mensaje)
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
