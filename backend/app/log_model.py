import enum
import uuid
from datetime import datetime

from sqlalchemy import Column, String, DateTime, Enum

from .database import Base


def gen_uuid():
    return str(uuid.uuid4())


UUID = lambda **kwargs: String(36)  # noqa: E731


class NivelLog(str, enum.Enum):
    INFO = "INFO"
    WARNING = "WARNING"
    ERROR = "ERROR"


class SystemLog(Base):
    __tablename__ = "system_logs"

    id = Column(UUID(as_uuid=False), primary_key=True, default=gen_uuid)
    fecha_hora = Column(DateTime, default=datetime.utcnow, nullable=False)
    nivel = Column(Enum(NivelLog), nullable=False, default=NivelLog.INFO)
    origen_ip = Column(String(45), nullable=True)  #
    mensaje = Column(String(500), nullable=False)
