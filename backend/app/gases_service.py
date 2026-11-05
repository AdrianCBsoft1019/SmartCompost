"""Conversion de las lecturas crudas de los MQ (0-1023 del Arduino) a ppm.

Formula de los sensores MQ:
    Rs  = RL * (1023 - adc) / adc       (resistencia del sensor, kOhm)
    ppm = a * (Rs / R0) ** b
`a` y `b` salen de las curvas del datasheet. R0 es la resistencia del
sensor en aire limpio y se calibra para cada sensor con GET /iot/calibracion
(ver firmware/GUIA_CONEXIONES.md). Los valores son aproximados: sirven para
tendencias y alertas, no como instrumento de laboratorio.
"""

import os
from typing import Optional

# Resistencia de carga del modulo (la de la plaquita, normalmente 10 kOhm;
# algunos MQ-135 traen 1 kOhm, marcada "102").
RL_KOHM = float(os.getenv("MQ_RL_KOHM", "10"))
MQ2_R0_KOHM = float(os.getenv("MQ2_R0_KOHM", "10"))
MQ135_R0_KOHM = float(os.getenv("MQ135_R0_KOHM", "10"))

# gas -> (a, b)
CURVAS = {
    "ch4": (3840.0, -2.69),  # MQ-2, metano
    "co2": (110.47, -2.862),  # MQ-135, dioxido de carbono (sobre el ambiente)
    "nh3": (102.2, -2.473),  # MQ-135, amoniaco
}
CO2_AMBIENTE_PPM = 400.0
PPM_MAXIMO = 100000.0

# Rs/R0 en aire limpio segun el datasheet (para calibrar R0)
FACTOR_AIRE_LIMPIO = {"mq2": 9.83, "mq135": 3.6}


def resistencia_sensor(adc: Optional[int], rl: float = RL_KOHM) -> Optional[float]:
    if adc is None or adc <= 0:
        return None
    adc = min(adc, 1022)
    return rl * (1023 - adc) / adc


def _ppm(adc: Optional[int], r0: float, gas: str) -> Optional[float]:
    rs = resistencia_sensor(adc)
    if rs is None or r0 <= 0:
        return None
    a, b = CURVAS[gas]
    return min(a * (rs / r0) ** b, PPM_MAXIMO)


def _redondear(valor: Optional[float]) -> Optional[float]:
    return None if valor is None else round(valor, 1)


def gases_desde_crudos(mq2: Optional[int], mq135: Optional[int]) -> dict:
    """Lecturas crudas -> campos de gas de la tabla lecturas."""
    co2 = _ppm(mq135, MQ135_R0_KOHM, "co2")
    return {
        "ch4_ppm": _redondear(_ppm(mq2, MQ2_R0_KOHM, "ch4")),
        "co2_ppm": _redondear(None if co2 is None else co2 + CO2_AMBIENTE_PPM),
        "nh3_ppm": _redondear(_ppm(mq135, MQ135_R0_KOHM, "nh3")),
    }


def r0_en_aire_limpio(adc: Optional[int], sensor: str) -> Optional[float]:
    """R0 a partir de una lectura cruda tomada en aire limpio."""
    rs = resistencia_sensor(adc)
    if rs is None:
        return None
    return round(rs / FACTOR_AIRE_LIMPIO[sensor], 2)
