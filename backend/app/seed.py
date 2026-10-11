"""Datos de demostracion para probar pilas, analisis y perfiles.

Uso (con la base arriba):  python -m app.seed
Con Docker:  docker compose exec backend python -m app.seed

Los valores imitan la simulacion Arduino de Tinkercad (temperatura y
humedad de suelo) y agregan gases simulados, porque el prototipo virtual
no incluye sensores de gas. Es idempotente: si ya hay pilas no duplica.
"""

import math
import random
from datetime import datetime, timedelta

from sqlalchemy.orm import Session

from . import models, security
from .database import Base, SessionLocal, engine

# nombre, planta, dias desde inicio, temp base, humedad base, gas base (x CO2)
PILAS_DEMO = [
    ("Pila A-102", "Planta Norte", 40, 64.0, 55.0, 1.0),
    ("Pila B-205", "Planta Sur", 90 * 45 // 100, 33.0, 60.0, 0.5),
    ("Pila C-088", "Zona Experimental", 88, 24.0, 45.0, 0.3),
    ("Pila D-112", "Planta Norte", 55, 62.0, 52.0, 0.8),
]


def _usuario(db: Session, nombre: str, correo: str, rol, password: str):
    existente = db.query(models.Usuario).filter_by(correo=correo).first()
    if existente:
        return existente
    usuario = models.Usuario(
        nombre_completo=nombre,
        correo=correo,
        password_hash=security.hash_password(password),
        rol=rol,
    )
    db.add(usuario)
    db.flush()
    return usuario


def sembrar(db: Session, dias_historial: int = 30, semilla: int = 7) -> dict:
    admin = _usuario(
        db,
        "Admin SmartCompost",
        "admin@smartcompost.com",
        models.RolUsuario.instructor,
        "Admin12345",
    )
    _usuario(
        db,
        "Estudiante Demo",
        "estudiante@smartcompost.com",
        models.RolUsuario.aprendiz,
        "Estudiante123",
    )
    if db.query(models.Pila).count() > 0:
        db.commit()
        return {"pilas": 0, "lecturas": 0, "mensaje": "ya habia datos"}

    azar = random.Random(semilla)
    ahora = datetime.utcnow().replace(minute=0, second=0, microsecond=0)
    total_lecturas = 0

    for i, (nombre, planta, dias, t_base, h_base, f_gas) in enumerate(PILAS_DEMO):
        pila = models.Pila(
            nombre=nombre,
            ubicacion=planta,
            responsable_id=admin.id,
            fecha_inicio=ahora - timedelta(days=dias),
            dias_ciclo=90,
        )
        db.add(pila)
        db.flush()

        for tipo, sufijo in [
            (models.TipoSensor.temperatura, "TMP"),
            (models.TipoSensor.humedad, "HUM"),
            (models.TipoSensor.gas_ch4, "CH4"),
        ]:
            db.add(
                models.Sensor(
                    tipo=tipo,
                    codigo_dispositivo=f"{sufijo}-{nombre[-4:]}",
                    pila_id=pila.id,
                    # El CH4 de la pila D queda inactivo para probar el estado.
                    activo=not (tipo == models.TipoSensor.gas_ch4 and i == 3),
                )
            )

        for h in range(dias_historial * 24, -1, -1):
            momento = ahora - timedelta(hours=h)
            ciclo_dia = math.sin((momento.hour - 8) / 24 * 2 * math.pi)
            temp = t_base + 2.5 * ciclo_dia + azar.uniform(-0.6, 0.6)
            hum = h_base + 2.0 * ciclo_dia + azar.uniform(-1.0, 1.0)
            co2 = 420 + 380 * f_gas + 60 * ciclo_dia + azar.uniform(-25, 25)
            ch4 = 60 + 260 * f_gas + azar.uniform(-20, 20)
            nh3 = 6 + 14 * f_gas + azar.uniform(-1.5, 1.5)
            # Pila A: picos de temperatura y CH4 en los ultimos dias.
            if i == 0 and h < 36:
                temp += 7
                ch4 += 330
            db.add(
                models.Lectura(
                    pila_id=pila.id,
                    temperatura=round(temp, 1),
                    humedad=round(hum, 1),
                    co2_ppm=round(co2, 1),
                    ch4_ppm=round(ch4, 1),
                    nh3_ppm=round(nh3, 1),
                    creado_en=momento,
                )
            )
            total_lecturas += 1
    db.flush()

    # El estado guardado de cada pila sale de su ultima lectura.
    from . import pila_service

    for pila in db.query(models.Pila).all():
        lectura = pila_service.ultima_lectura(db, pila.id)
        madurez = pila_service.calcular_madurez(pila.fecha_inicio, pila.dias_ciclo)
        evaluacion = pila_service.evaluar_lectura(lectura)
        pila.estado = pila_service.estado_desde_semaforo(
            evaluacion["semaforo"], madurez["madurez_pct"]
        )
    db.commit()
    return {"pilas": len(PILAS_DEMO), "lecturas": total_lecturas}


if __name__ == "__main__":
    Base.metadata.create_all(bind=engine)
    with SessionLocal() as sesion:
        print(sembrar(sesion))
