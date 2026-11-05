import pytest

from app import gases_service

CLAVE = "clave-de-prueba"


@pytest.fixture()
def dispositivo(client, admin, monkeypatch):
    """Registra el sensor del ESP32 en la primera pila, como en la pagina."""
    monkeypatch.setenv("IOT_API_KEY", CLAVE)
    pila = client.get("/pilas/", headers=admin).json()[0]
    r = client.post(
        "/sensores/",
        json={
            "tipo": "temperatura",
            "codigo_dispositivo": "ESP32-01",
            "pila_id": pila["id"],
        },
        headers=admin,
    )
    assert r.status_code == 201, r.text
    return {"pila": pila, "sensor": r.json()}


def _linea_uno(**cambios):
    """Lo que manda el Arduino UNO + el codigo que agrega el ESP32."""
    datos = {
        "codigo_dispositivo": "ESP32-01",
        "humedad": 55,
        "temperatura": 58.4,
        "mq2": 310,
        "mq135": 420,
        "gas": 420,
        "riego": 0,
        "volteo": 1,
        "emergenciaGas": 0,
        "alarma": 0,
        "estado": "VOLTEANDO",
        "motivoVolteo": "periodico",
    }
    datos.update(cambios)
    return datos


def test_esp32_registra_lectura_en_su_pila(client, admin, dispositivo):
    r = client.post("/iot/lecturas", json=_linea_uno(), headers={"X-API-Key": CLAVE})
    assert r.status_code == 201, r.text
    lectura = r.json()["lectura"]
    assert lectura["pila_id"] == dispositivo["pila"]["id"]
    assert lectura["temperatura"] == 58.4 and lectura["humedad"] == 55
    assert lectura["co2_ppm"] > 400 and lectura["nh3_ppm"] > 0
    assert lectura["ch4_ppm"] > 0

    pila = client.get(f"/pilas/{dispositivo['pila']['id']}", headers=admin).json()
    assert pila["temperatura"] == 58.4


def test_esp32_lectura_critica_cambia_estado(client, admin, dispositivo):
    r = client.post(
        "/iot/lecturas",
        json=_linea_uno(temperatura=80),
        headers={"X-API-Key": CLAVE},
    )
    assert r.json()["evaluacion"]["semaforo"] == "rojo"
    pila = client.get(f"/pilas/{dispositivo['pila']['id']}", headers=admin).json()
    assert pila["estado"] in ("critico", "listo")


def test_esp32_rechazos(client, admin, dispositivo, monkeypatch):
    url = "/iot/lecturas"
    assert client.post(url, json=_linea_uno()).status_code == 401
    malo = {"X-API-Key": "otra"}
    assert client.post(url, json=_linea_uno(), headers=malo).status_code == 401

    ok = {"X-API-Key": CLAVE}
    desconocido = _linea_uno(codigo_dispositivo="NO-EXISTE")
    assert client.post(url, json=desconocido, headers=ok).status_code == 404
    # DS18B20 desconectado devuelve -127 C: no se guarda
    assert (
        client.post(url, json=_linea_uno(temperatura=-127), headers=ok).status_code
        == 422
    )

    sensor_id = dispositivo["sensor"]["id"]
    client.put(f"/sensores/{sensor_id}", json={"activo": False}, headers=admin)
    assert client.post(url, json=_linea_uno(), headers=ok).status_code == 409

    monkeypatch.delenv("IOT_API_KEY")
    assert client.post(url, json=_linea_uno(), headers=ok).status_code == 503


def test_calibracion_r0(client, dispositivo):
    r = client.get("/iot/calibracion?mq2=120&mq135=200", headers={"X-API-Key": CLAVE})
    assert r.status_code == 200
    assert r.json()["mq2_r0_kohm"] > 0 and r.json()["mq135_r0_kohm"] > 0


def test_conversion_de_gases():
    assert gases_service.gases_desde_crudos(None, 0) == {
        "ch4_ppm": None,
        "co2_ppm": None,
        "nh3_ppm": None,
    }
    poco = gases_service.gases_desde_crudos(100, 100)
    mucho = gases_service.gases_desde_crudos(800, 800)
    assert mucho["ch4_ppm"] > poco["ch4_ppm"]
    assert mucho["co2_ppm"] > poco["co2_ppm"]
