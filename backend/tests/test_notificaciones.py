"""Notificaciones: aviso cuando un sensor se daña y se requiere su arreglo."""

DETALLE = "Sin lectura desde hace 3 horas"
ID_INEXISTENTE = "00000000-0000-0000-0000-000000000000"


def _primer_sensor(client, headers):
    return client.get("/sensores/", headers=headers).json()[0]


def _reportar(client, headers, sensor_id, detalle=DETALLE):
    return client.post(
        f"/sensores/{sensor_id}/dano", json={"detalle": detalle}, headers=headers
    )


def test_sin_danos_no_hay_notificaciones(client, estudiante):
    r = client.get("/notificaciones/", headers=estudiante)
    assert r.status_code == 200
    assert r.json() == []


def test_requiere_sesion(client):
    assert client.get("/notificaciones/").status_code == 401


def test_reportar_dano_notifica_a_admin_y_estudiante(client, admin, estudiante):
    sensor = _primer_sensor(client, admin)
    r = _reportar(client, admin, sensor["id"])
    assert r.status_code == 200
    assert r.json()["danado"] is True
    assert r.json()["detalle_dano"] == DETALLE

    for headers in (admin, estudiante):
        avisos = client.get("/notificaciones/", headers=headers).json()
        assert len(avisos) == 1
        aviso = avisos[0]
        assert aviso["tipo"] == "sensor_danado"
        assert aviso["sensor_id"] == sensor["id"]
        assert aviso["sensor_codigo"] == sensor["codigo_dispositivo"]
        assert aviso["pila_nombre"] == sensor["pila_nombre"]
        assert aviso["detalle"] == DETALLE
        assert DETALLE in aviso["mensaje"]
        assert sensor["pila_nombre"] in aviso["mensaje"]
        assert "arreglo" in aviso["mensaje"]


def test_el_listado_de_sensores_indica_el_dano(client, admin):
    sensor = _primer_sensor(client, admin)
    assert sensor["danado"] is False
    _reportar(client, admin, sensor["id"])
    r = client.get(f"/sensores/{sensor['id']}", headers=admin)
    assert r.json()["danado"] is True
    assert r.json()["detalle_dano"] == DETALLE


def test_estudiante_no_puede_reportar_ni_reparar(client, admin, estudiante):
    sensor = _primer_sensor(client, admin)
    assert _reportar(client, estudiante, sensor["id"]).status_code == 403
    r = client.post(f"/sensores/{sensor['id']}/reparado", headers=estudiante)
    assert r.status_code == 403
    assert client.get("/notificaciones/", headers=admin).json() == []


def test_el_detalle_del_dano_es_obligatorio(client, admin):
    sensor_id = _primer_sensor(client, admin)["id"]
    assert _reportar(client, admin, sensor_id, "ab").status_code == 422
    assert _reportar(client, admin, sensor_id, "     ").status_code == 422
    assert client.get("/notificaciones/", headers=admin).json() == []


def test_sensor_inexistente(client, admin):
    assert _reportar(client, admin, ID_INEXISTENTE).status_code == 404
    r = client.post(f"/sensores/{ID_INEXISTENTE}/reparado", headers=admin)
    assert r.status_code == 404


def test_marcar_reparado_retira_la_notificacion(client, admin, estudiante):
    sensor_id = _primer_sensor(client, admin)["id"]
    _reportar(client, admin, sensor_id)
    r = client.post(f"/sensores/{sensor_id}/reparado", headers=admin)
    assert r.status_code == 200
    assert r.json()["danado"] is False
    assert r.json()["detalle_dano"] is None
    assert client.get("/notificaciones/", headers=estudiante).json() == []


def test_eliminar_un_sensor_danado_retira_la_notificacion(client, admin):
    sensor_id = _primer_sensor(client, admin)["id"]
    _reportar(client, admin, sensor_id)
    assert client.delete(f"/sensores/{sensor_id}", headers=admin).status_code == 204
    assert client.get("/notificaciones/", headers=admin).json() == []
