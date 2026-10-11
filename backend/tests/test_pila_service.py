from datetime import datetime, timedelta

from app import pila_service


def test_madurez_en_mitad_del_ciclo():
    inicio = datetime.utcnow() - timedelta(days=45)
    r = pila_service.calcular_madurez(inicio, 90)
    assert r["madurez_pct"] == 50.0
    assert r["fase"] == "enfriamiento"
    assert r["dias_faltantes_fase"] == 18  # fase termina al 70 % = dia 63


def test_madurez_nunca_pasa_de_100():
    inicio = datetime.utcnow() - timedelta(days=500)
    r = pila_service.calcular_madurez(inicio, 90)
    assert r["madurez_pct"] == 100.0
    assert r["fase"] == "maduracion"
    assert r["dias_faltantes_fase"] == 0


def test_semaforo_verde():
    r = pila_service.evaluar_valores({"temperatura": 55, "humedad": 55, "co2_ppm": 500})
    assert r["semaforo"] == "verde" and r["indicador"] == "seguro"


def test_semaforo_amarillo_cerca_del_limite():
    r = pila_service.evaluar_valores({"temperatura": 66, "humedad": 55})
    assert r["semaforo"] == "amarillo" and r["indicador"] == "seguro"


def test_semaforo_rojo_por_temperatura_y_humedad_baja():
    r = pila_service.evaluar_valores({"temperatura": 75, "humedad": 30})
    assert r["semaforo"] == "rojo" and r["indicador"] == "inseguro"
    assert len(r["violaciones"]) == 2


def test_valores_nulos_se_ignoran():
    r = pila_service.evaluar_valores({"temperatura": 50, "co2_ppm": None})
    assert r["semaforo"] == "verde"


def test_estado_listo_cuando_madurez_100():
    assert pila_service.estado_desde_semaforo("verde", 100) == "listo"
    assert pila_service.estado_desde_semaforo("rojo", 40) == "critico"
