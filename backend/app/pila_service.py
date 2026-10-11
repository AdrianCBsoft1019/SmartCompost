"""Reglas de negocio de las pilas (maduracion, fases y semaforo).

Se mantiene separado de los routers para poder probarlo sin base de datos
y para que Alertas (Roderick) reutilice `evaluar_valores`.
"""

import math
from collections import defaultdict
from datetime import datetime, timedelta
from typing import Optional

from sqlalchemy.orm import Session

from . import models

# Limites de seguridad. (minimo, maximo); None = sin limite en ese lado.
LIMITES: dict[str, tuple[Optional[float], Optional[float]]] = {
    "temperatura": (None, 70.0),  # >70 C mata la microbiologia util
    "humedad": (40.0, 65.0),  # % ideal para compostaje aerobio
    "co2_ppm": (None, 1000.0),
    "ch4_ppm": (None, 500.0),
    "nh3_ppm": (None, 25.0),
}

NOMBRES = {
    "temperatura": "Temperatura",
    "humedad": "Humedad",
    "co2_ppm": "CO2",
    "ch4_ppm": "Metano (CH4)",
    "nh3_ppm": "Amoniaco (NH3)",
}

# Margen para "amarillo": cerca del limite pero todavia sin superarlo.
MARGEN_ADVERTENCIA = 0.10

# Fases: (nombre, fraccion del ciclo en la que termina)
FASES = [
    ("mesofilica", 0.10),
    ("termofilica", 0.40),
    ("enfriamiento", 0.70),
    ("maduracion", 1.00),
]


def dias_transcurridos(fecha_inicio: datetime, ahora: Optional[datetime] = None) -> int:
    ahora = ahora or datetime.utcnow()
    return max(0, (ahora - fecha_inicio).days)


def calcular_madurez(
    fecha_inicio: datetime, dias_ciclo: int, ahora: Optional[datetime] = None
) -> dict:
    """Porcentaje de maduracion, fase actual y dias para la siguiente fase."""
    transcurridos = dias_transcurridos(fecha_inicio, ahora)
    fraccion = min(1.0, transcurridos / dias_ciclo)

    fase_actual, fin_fraccion = FASES[-1]
    for nombre, fin in FASES:
        if fraccion < fin:
            fase_actual, fin_fraccion = nombre, fin
            break

    dias_faltantes = max(0, math.ceil(fin_fraccion * dias_ciclo - transcurridos))
    return {
        "madurez_pct": round(fraccion * 100, 1),
        "fase": fase_actual,
        "dias_faltantes_fase": dias_faltantes,
        "dias_transcurridos": transcurridos,
    }


def _estado_variable(nombre: str, valor: float) -> str:
    minimo, maximo = LIMITES[nombre]
    if (maximo is not None and valor > maximo) or (
        minimo is not None and valor < minimo
    ):
        return "rojo"
    if maximo is not None and valor >= maximo * (1 - MARGEN_ADVERTENCIA):
        return "amarillo"
    if minimo is not None and valor <= minimo * (1 + MARGEN_ADVERTENCIA):
        return "amarillo"
    return "verde"


def evaluar_valores(valores: dict[str, Optional[float]]) -> dict:
    """Compara cada medicion con LIMITES y devuelve el semaforo global.

    rojo     -> alguna variable fuera de limites  (indicador: inseguro)
    amarillo -> alguna variable a menos de 10 % del limite (indicador: seguro)
    verde    -> todo en rango                      (indicador: seguro)
    """
    semaforo = "verde"
    violaciones: list[str] = []
    for nombre, valor in valores.items():
        if valor is None or nombre not in LIMITES:
            continue
        estado = _estado_variable(nombre, valor)
        if estado == "rojo":
            semaforo = "rojo"
            minimo, maximo = LIMITES[nombre]
            lado = "supera el maximo" if maximo and valor > maximo else "bajo el minimo"
            limite = maximo if maximo and valor > maximo else minimo
            violaciones.append(
                f"{NOMBRES[nombre]} {lado} permitido ({valor:g} vs {limite:g})"
            )
        elif estado == "amarillo" and semaforo != "rojo":
            semaforo = "amarillo"
    return {
        "semaforo": semaforo,
        "indicador": "inseguro" if semaforo == "rojo" else "seguro",
        "violaciones": violaciones,
    }


def evaluar_lectura(lectura) -> dict:
    return evaluar_valores(
        {
            "temperatura": lectura.temperatura,
            "humedad": lectura.humedad,
            "co2_ppm": lectura.co2_ppm,
            "ch4_ppm": lectura.ch4_ppm,
            "nh3_ppm": lectura.nh3_ppm,
        }
    )


def variables_fuera_de_limite(lectura) -> list[str]:
    """Nombres de las variables en rojo (para estadisticas de alteracion)."""
    fuera = []
    for nombre in LIMITES:
        valor = getattr(lectura, nombre, None)
        if valor is not None and _estado_variable(nombre, valor) == "rojo":
            fuera.append(nombre)
    return fuera


def estado_desde_semaforo(semaforo: str, madurez_pct: float) -> str:
    if madurez_pct >= 100:
        return "listo"
    return {"verde": "normal", "amarillo": "atencion", "rojo": "critico"}[semaforo]


def ultima_lectura(db: Session, pila_id: str) -> Optional[models.Lectura]:
    return (
        db.query(models.Lectura)
        .filter(models.Lectura.pila_id == pila_id)
        .order_by(models.Lectura.creado_en.desc())
        .first()
    )


def a_salida(pila: models.Pila, db: Session) -> dict:
    """Convierte una Pila ORM en el dict de PilaOut (con campos calculados)."""
    madurez = calcular_madurez(pila.fecha_inicio, pila.dias_ciclo)
    lectura = ultima_lectura(db, pila.id)
    return {
        "id": pila.id,
        "nombre": pila.nombre,
        "ubicacion": pila.ubicacion,
        "latitud": pila.latitud,
        "longitud": pila.longitud,
        "estado": pila.estado,
        "responsable_id": pila.responsable_id,
        "creado_en": pila.creado_en,
        "fecha_inicio": pila.fecha_inicio,
        "dias_ciclo": pila.dias_ciclo,
        "fase": madurez["fase"],
        "madurez_pct": madurez["madurez_pct"],
        "dias_faltantes_fase": madurez["dias_faltantes_fase"],
        "temperatura": lectura.temperatura if lectura else None,
        "humedad": lectura.humedad if lectura else None,
    }


def serie_por_hora(db: Session, pila_id: str, horas: int = 24) -> list[dict]:
    """Promedio de temperatura y humedad por hora para la grafica de 24 h."""
    desde = datetime.utcnow() - timedelta(hours=horas)
    lecturas = (
        db.query(models.Lectura)
        .filter(models.Lectura.pila_id == pila_id, models.Lectura.creado_en >= desde)
        .order_by(models.Lectura.creado_en)
        .all()
    )
    cubetas: dict[datetime, list[models.Lectura]] = defaultdict(list)
    for lectura in lecturas:
        cubetas[lectura.creado_en.replace(minute=0, second=0, microsecond=0)].append(
            lectura
        )
    serie = []
    for hora in sorted(cubetas):
        grupo = cubetas[hora]
        serie.append(
            {
                "hora": hora,
                "temperatura": round(sum(x.temperatura for x in grupo) / len(grupo), 1),
                "humedad": round(sum(x.humedad for x in grupo) / len(grupo), 1),
            }
        )
    return serie
