"""Estadisticas para la Vista de Analisis (admin y estudiante).

Todo se calcula en el servidor a partir de `lecturas`, `pilas` y `sensores`,
para que la web y el PDF muestren exactamente las mismas cifras.
"""

from datetime import datetime, timedelta
from typing import Optional

from sqlalchemy import func
from sqlalchemy.orm import Session

from . import models, pila_service

PERIODOS = {"semana": 7, "mes": 30, "anio": 365}

# Variable que mide cada tipo de sensor (para contar alteraciones).
VARIABLE_POR_SENSOR = {
    models.TipoSensor.temperatura: "temperatura",
    models.TipoSensor.humedad: "humedad",
    models.TipoSensor.gas_ch4: "ch4_ppm",
}


def rango_periodo(periodo: str) -> tuple[datetime, datetime]:
    if periodo not in PERIODOS:
        raise ValueError("Periodo invalido: usa semana, mes o anio")
    hasta = datetime.utcnow()
    return hasta - timedelta(days=PERIODOS[periodo]), hasta


def _redondear(valor: Optional[float]) -> Optional[float]:
    return None if valor is None else round(float(valor), 1)


def promedios_globales(db: Session, desde: datetime) -> tuple[dict, int]:
    fila = (
        db.query(
            func.avg(models.Lectura.temperatura),
            func.avg(models.Lectura.humedad),
            func.avg(models.Lectura.co2_ppm),
            func.avg(models.Lectura.ch4_ppm),
            func.avg(models.Lectura.nh3_ppm),
            func.count(models.Lectura.id),
        )
        .filter(models.Lectura.creado_en >= desde)
        .one()
    )
    claves = ["temperatura", "humedad", "co2_ppm", "ch4_ppm", "nh3_ppm"]
    promedios = {k: _redondear(v) for k, v in zip(claves, fila[:5])}
    return promedios, int(fila[5])


def conteo_fuera_de_limite(
    db: Session, desde: datetime
) -> tuple[dict[str, int], dict[str, dict[str, int]]]:
    """Cuenta lecturas fuera de limite: total por pila y por pila+variable."""
    por_pila: dict[str, int] = {}
    por_variable: dict[str, dict[str, int]] = {}
    consulta = db.query(models.Lectura).filter(models.Lectura.creado_en >= desde)
    for lectura in consulta.yield_per(1000):
        fuera = pila_service.variables_fuera_de_limite(lectura)
        if not fuera:
            continue
        por_pila[lectura.pila_id] = por_pila.get(lectura.pila_id, 0) + 1
        acumulado = por_variable.setdefault(lectura.pila_id, {})
        for variable in fuera:
            acumulado[variable] = acumulado.get(variable, 0) + 1
    return por_pila, por_variable


def comparativa_pilas(db: Session, desde: datetime, fuera_por_pila: dict) -> list[dict]:
    stats = {
        fila[0]: fila
        for fila in db.query(
            models.Lectura.pila_id,
            func.avg(models.Lectura.temperatura),
            func.max(models.Lectura.temperatura),
            func.avg(models.Lectura.humedad),
        )
        .filter(models.Lectura.creado_en >= desde)
        .group_by(models.Lectura.pila_id)
        .all()
    }
    salida = []
    for pila in db.query(models.Pila).order_by(models.Pila.nombre).all():
        madurez = pila_service.calcular_madurez(pila.fecha_inicio, pila.dias_ciclo)
        fila = stats.get(pila.id)
        salida.append(
            {
                "pila_id": pila.id,
                "nombre": pila.nombre,
                "ubicacion": pila.ubicacion,
                "estado": pila.estado,
                "fase": madurez["fase"],
                "temperatura_prom": _redondear(fila[1]) if fila else None,
                "temperatura_max": _redondear(fila[2]) if fila else None,
                "humedad_prom": _redondear(fila[3]) if fila else None,
                "madurez_pct": madurez["madurez_pct"],
                "lecturas_fuera_limite": fuera_por_pila.get(pila.id, 0),
            }
        )
    return salida


def alertas_activas(db: Session) -> list[dict]:
    """Una alerta por cada pila cuya ULTIMA lectura esta fuera de limites."""
    alertas = []
    for pila in db.query(models.Pila).all():
        lectura = pila_service.ultima_lectura(db, pila.id)
        if not lectura:
            continue
        evaluacion = pila_service.evaluar_lectura(lectura)
        for mensaje in evaluacion["violaciones"]:
            alertas.append(
                {"pila_id": pila.id, "pila": pila.nombre, "mensaje": mensaje}
            )
    return alertas


def tendencia_gases(db: Session, dias: int = 7) -> list[dict]:
    """Promedio diario de gases de los ultimos `dias` dias."""
    desde = datetime.utcnow() - timedelta(days=dias)
    dia = func.date(models.Lectura.creado_en)
    filas = (
        db.query(
            dia,
            func.avg(models.Lectura.co2_ppm),
            func.avg(models.Lectura.ch4_ppm),
            func.avg(models.Lectura.nh3_ppm),
        )
        .filter(models.Lectura.creado_en >= desde)
        .group_by(dia)
        .order_by(dia)
        .all()
    )
    return [
        {
            "fecha": str(f[0]),
            "co2_ppm": _redondear(f[1]),
            "ch4_ppm": _redondear(f[2]),
            "nh3_ppm": _redondear(f[3]),
        }
        for f in filas
    ]


def sensores_por_planta(db: Session, alteraciones: Optional[dict] = None) -> list[dict]:
    """Agrupa sensores por ubicacion (planta) con su estado activo/inactivo."""
    alteraciones = alteraciones or {}
    plantas: dict[str, list[dict]] = {}
    for sensor in db.query(models.Sensor).all():
        pila = sensor.pila
        variable = VARIABLE_POR_SENSOR.get(sensor.tipo)
        cuenta = alteraciones.get(pila.id, {}).get(variable, 0) if variable else 0
        plantas.setdefault(pila.ubicacion or "Sin ubicacion", []).append(
            {
                "id": sensor.id,
                "codigo": sensor.codigo_dispositivo,
                "tipo": sensor.tipo.value,
                "pila": pila.nombre,
                "activo": bool(sensor.activo),
                "alteraciones": cuenta,
            }
        )
    return [
        {
            "planta": planta,
            "total": len(lista),
            "activos": sum(1 for s in lista if s["activo"]),
            "inactivos": sum(1 for s in lista if not s["activo"]),
            "sensores": lista,
        }
        for planta, lista in sorted(plantas.items())
    ]


def resumen(db: Session, periodo: str) -> dict:
    desde, hasta = rango_periodo(periodo)
    promedios, total = promedios_globales(db, desde)
    fuera_pila, fuera_variable = conteo_fuera_de_limite(db, desde)
    return {
        "periodo": periodo,
        "desde": desde,
        "hasta": hasta,
        "promedios": promedios,
        "total_lecturas": total,
        "comparativa": comparativa_pilas(db, desde, fuera_pila),
        "alertas_activas": alertas_activas(db),
        "tendencia_semanal": tendencia_gases(db, 7),
        "sensores_por_planta": sensores_por_planta(db, fuera_variable),
    }
