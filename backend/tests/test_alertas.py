"""Alertas por limites superados: listado, filtros, resumen y permisos."""

from .test_api import _primera_pila


def _lectura(client, headers, pila_id, **valores):
    datos = {"temperatura": 50, "humedad": 55}
    datos.update(valores)
    r = client.post(f"/pilas/{pila_id}/lecturas", json=datos, headers=headers)
    assert r.status_code == 201, r.text


def test_requiere_login(client):
    assert client.get("/alertas/").status_code == 401
    assert client.get("/alertas/resumen").status_code == 401


def test_estudiante_puede_consultar(client, estudiante):
    assert client.get("/alertas/", headers=estudiante).status_code == 200
    assert client.get("/alertas/resumen", headers=estudiante).status_code == 200


def test_lectura_fuera_de_limite_genera_alerta_activa(client, admin):
    pila = _primera_pila(client, admin)
    _lectura(client, admin, pila["id"], temperatura=90)

    r = client.get(f"/alertas/?pila_id={pila['id']}&solo_activas=true", headers=admin)
    assert r.status_code == 200
    alertas = r.json()
    assert len(alertas) == 1
    a = alertas[0]
    assert a["variable"] == "temperatura" and a["valor"] == 90
    assert a["limite"] == 70 and a["lado"] == "maximo" and a["activa"] is True
    assert a["pila"] == pila["nombre"]
    assert a["sensor_codigo"] is not None  # el seed tiene sensor de temperatura
    assert "supera el maximo" in a["mensaje"]

    # Una lectura nueva y normal apaga la alerta activa, pero queda en el historial.
    _lectura(client, admin, pila["id"], temperatura=50)
    activas = client.get(
        f"/alertas/?pila_id={pila['id']}&solo_activas=true", headers=admin
    ).json()
    assert activas == []
    historial = client.get(f"/alertas/?pila_id={pila['id']}", headers=admin).json()
    assert any(x["valor"] == 90 and x["activa"] is False for x in historial)


def test_humedad_baja_es_alerta_de_minimo(client, admin):
    pila = _primera_pila(client, admin)
    _lectura(client, admin, pila["id"], humedad=20)
    alertas = client.get(
        f"/alertas/?pila_id={pila['id']}&variable=humedad&solo_activas=true",
        headers=admin,
    ).json()
    assert len(alertas) == 1
    assert alertas[0]["lado"] == "minimo" and alertas[0]["limite"] == 40


def test_filtros_y_limite(client, admin):
    pila = _primera_pila(client, admin)
    for _ in range(3):
        _lectura(client, admin, pila["id"], temperatura=85, humedad=20)
    solo_temp = client.get(
        f"/alertas/?pila_id={pila['id']}&variable=temperatura", headers=admin
    ).json()
    assert solo_temp and {a["variable"] for a in solo_temp} == {"temperatura"}
    assert len(client.get("/alertas/?limite=2", headers=admin).json()) == 2


def test_parametros_invalidos(client, admin):
    assert client.get("/alertas/?periodo=siglo", headers=admin).status_code == 400
    assert client.get("/alertas/?variable=oro", headers=admin).status_code == 400
    assert client.get("/alertas/?pila_id=nada", headers=admin).status_code == 404
    assert client.get("/alertas/?limite=0", headers=admin).status_code == 422
    assert client.get("/alertas/resumen?periodo=x", headers=admin).status_code == 400


def test_resumen_es_consistente(client, admin):
    pila = _primera_pila(client, admin)
    _lectura(client, admin, pila["id"], temperatura=95, humedad=10)
    r = client.get("/alertas/resumen?periodo=semana", headers=admin).json()
    total = r["total_alertas"]
    assert total >= 2
    assert sum(v["total"] for v in r["por_variable"]) == total
    assert sum(p["total"] for p in r["por_pila"]) == total
    assert sum(d["total"] for d in r["por_dia"]) == total
    assert r["alertas_activas"] >= 2
    assert r["lecturas_fuera_de_limite"] <= r["total_lecturas"]
    assert 0 < r["porcentaje_fuera_de_limite"] <= 100
    assert len(r["por_dia"]) >= 7
    assert any(s["tipo"] == "temperatura" for s in r["por_sensor"])
    # un periodo mas largo nunca tiene menos alertas
    anio = client.get("/alertas/resumen?periodo=anio", headers=admin).json()
    assert anio["total_alertas"] >= total
