from datetime import datetime, timedelta
from typing import Optional

from sqlalchemy import func
from sqlalchemy.orm import Session

from . import analisis_service, models, pila_service

# Variable de lectura -> tipo de sensor que la mide. CO2 y NH3 no tienen un
# tipo de sensor propio, por eso su alerta no apunta a un sensor.
SENSOR_POR_VARIABLE = {
    "temperatura": models.TipoSensor.temperatura,
    "humedad": models.TipoSensor.humedad,
    "ch4_ppm": models.TipoSensor.gas_ch4,
}


def _sensores_por_pila(db: Session) -> dict[tuple[str, str], models.Sensor]:
    """(pila_id, variable) -> sensor, prefiriendo los sensores activos."""
    mapa: dict[tuple[str, str], models.Sensor] = {}
    sensores = db.query(models.Sensor).order_by(models.Sensor.activo.asc()).all()
    for sensor in sensores:  # los activos van al final y pisan a los inactivos
        for variable, tipo in SENSOR_POR_VARIABLE.items():
            if sensor.tipo == tipo:
                mapa[(sensor.pila_id, variable)] = sensor
    return mapa


def _lado_y_limite(variable: str, valor: float) -> tuple[str, float]:
    minimo, maximo = pila_service.LIMITES[variable]
    if maximo is not None and valor > maximo:
        return "maximo", maximo
    return "minimo", minimo


def _mensaje(variable: str, valor: float, lado: str, limite: float) -> str:
    accion = "supera el maximo" if lado == "maximo" else "bajo el minimo"
    return (
        f"{pila_service.NOMBRES[variable]} {accion} permitido ({valor:g} vs {limite:g})"
    )


def _ids_ultimas_lecturas(db: Session) -> set[str]:
    ids = set()
    for (pila_id,) in db.query(models.Pila.id).all():
        ultima = pila_service.ultima_lectura(db, pila_id)
        if ultima:
            ids.add(ultima.id)
    return ids


def _lecturas_del_periodo(db: Session, desde: datetime, pila_id: Optional[str]):
    consulta = db.query(models.Lectura).filter(models.Lectura.creado_en >= desde)
    if pila_id:
        consulta = consulta.filter(models.Lectura.pila_id == pila_id)
    return consulta


def listar_alertas(
    db: Session,
    desde: datetime,
    pila_id: Optional[str] = None,
    variable: Optional[str] = None,
    solo_activas: bool = False,
    limite: int = 100,
) -> list[dict]:
    """Alertas del periodo, de la mas reciente a la mas antigua."""
    sensores = _sensores_por_pila(db)
    ultimas = _ids_ultimas_lecturas(db)
    consulta = _lecturas_del_periodo(db, desde, pila_id).order_by(
        models.Lectura.creado_en.desc()
    )

    alertas: list[dict] = []
    for lectura in consulta.yield_per(500):
        for nombre in pila_service.variables_fuera_de_limite(lectura):
            if variable and nombre != variable:
                continue
            activa = lectura.id in ultimas
            if solo_activas and not activa:
                continue
            valor = float(getattr(lectura, nombre))
            lado, limite_valor = _lado_y_limite(nombre, valor)
            sensor = sensores.get((lectura.pila_id, nombre))
            alertas.append(
                {
                    "id": f"{lectura.id}:{nombre}",
                    "pila_id": lectura.pila_id,
                    "pila": lectura.pila.nombre,
                    "ubicacion": lectura.pila.ubicacion,
                    "variable": nombre,
                    "nombre": pila_service.NOMBRES[nombre],
                    "valor": valor,
                    "limite": limite_valor,
                    "lado": lado,
                    "mensaje": _mensaje(nombre, valor, lado, limite_valor),
                    "sensor_codigo": sensor.codigo_dispositivo if sensor else None,
                    "fecha": lectura.creado_en,
                    "activa": activa,
                }
            )
            if len(alertas) >= limite:
                return alertas
    return alertas


def resumen_alertas(db: Session, periodo: str) -> dict:
    """Analisis de las alertas del periodo (semana | mes | anio)."""
    desde, hasta = analisis_service.rango_periodo(periodo)
    sensores = _sensores_por_pila(db)
    pilas = {p.id: p for p in db.query(models.Pila).all()}

    por_variable: dict[str, int] = {}
    por_pila: dict[str, int] = {}
    por_sensor: dict[str, int] = {}
    por_dia: dict = {}
    total_alertas = 0
    lecturas_afectadas = 0

    consulta = db.query(models.Lectura).filter(models.Lectura.creado_en >= desde)
    for lectura in consulta.yield_per(1000):
        fuera = pila_service.variables_fuera_de_limite(lectura)
        if not fuera:
            continue
        lecturas_afectadas += 1
        dia = lectura.creado_en.date()
        for nombre in fuera:
            total_alertas += 1
            por_variable[nombre] = por_variable.get(nombre, 0) + 1
            por_pila[lectura.pila_id] = por_pila.get(lectura.pila_id, 0) + 1
            por_dia[dia] = por_dia.get(dia, 0) + 1
            sensor = sensores.get((lectura.pila_id, nombre))
            if sensor:
                por_sensor[sensor.id] = por_sensor.get(sensor.id, 0) + 1

    total_lecturas = (
        db.query(func.count(models.Lectura.id))
        .filter(models.Lectura.creado_en >= desde)
        .scalar()
        or 0
    )
    sensores_por_id = {s.id: s for s in db.query(models.Sensor).all()}

    dias = []
    dia = desde.date()
    while dia <= hasta.date():
        dias.append({"fecha": dia, "total": por_dia.get(dia, 0)})
        dia += timedelta(days=1)

    return {
        "periodo": periodo,
        "desde": desde,
        "hasta": hasta,
        "total_alertas": total_alertas,
        "alertas_activas": len(analisis_service.alertas_activas(db)),
        "total_lecturas": total_lecturas,
        "lecturas_fuera_de_limite": lecturas_afectadas,
        "porcentaje_fuera_de_limite": (
            round(lecturas_afectadas * 100 / total_lecturas, 1)
            if total_lecturas
            else 0.0
        ),
        "por_variable": [
            {"variable": v, "nombre": pila_service.NOMBRES[v], "total": n}
            for v, n in sorted(por_variable.items(), key=lambda x: -x[1])
        ],
        "por_pila": [
            {
                "pila_id": pid,
                "pila": pilas[pid].nombre,
                "ubicacion": pilas[pid].ubicacion,
                "total": n,
            }
            for pid, n in sorted(por_pila.items(), key=lambda x: -x[1])
            if pid in pilas
        ],
        "por_sensor": [
            {
                "sensor_id": sid,
                "codigo": sensores_por_id[sid].codigo_dispositivo,
                "tipo": sensores_por_id[sid].tipo.value,
                "pila": pilas[sensores_por_id[sid].pila_id].nombre,
                "total": n,
            }
            for sid, n in sorted(por_sensor.items(), key=lambda x: -x[1])
            if sid in sensores_por_id
        ],
        "por_dia": dias,
    }
