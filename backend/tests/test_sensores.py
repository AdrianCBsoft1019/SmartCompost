"""CRUD de sensores: permisos por rol, validaciones y filtros."""

from .test_api import _primera_pila


def _nuevo(pila_id, codigo="TMP-TEST-01", tipo="temperatura"):
    return {"tipo": tipo, "codigo_dispositivo": codigo, "pila_id": pila_id}


def test_crud_sensor_completo_como_instructor(client, admin):
    pila = _primera_pila(client, admin)
    r = client.post("/sensores/", json=_nuevo(pila["id"]), headers=admin)
    assert r.status_code == 201
    sensor = r.json()
    assert sensor["activo"] is True
    assert sensor["pila_nombre"] == pila["nombre"]
    assert sensor["ubicacion"] == pila["ubicacion"]

    sid = sensor["id"]
    assert client.get(f"/sensores/{sid}", headers=admin).status_code == 200

    r = client.put(
        f"/sensores/{sid}",
        json={"activo": False, "codigo_dispositivo": "TMP-TEST-02"},
        headers=admin,
    )
    assert r.status_code == 200
    assert r.json()["activo"] is False
    assert r.json()["codigo_dispositivo"] == "TMP-TEST-02"

    assert client.delete(f"/sensores/{sid}", headers=admin).status_code == 204
    assert client.get(f"/sensores/{sid}", headers=admin).status_code == 404


def test_estudiante_solo_puede_consultar(client, admin, estudiante):
    pila = _primera_pila(client, admin)
    assert client.get("/sensores/", headers=estudiante).status_code == 200
    r = client.post("/sensores/", json=_nuevo(pila["id"]), headers=estudiante)
    assert r.status_code == 403
    sid = client.get("/sensores/", headers=estudiante).json()[0]["id"]
    assert (
        client.put(f"/sensores/{sid}", json={}, headers=estudiante).status_code == 403
    )
    assert client.delete(f"/sensores/{sid}", headers=estudiante).status_code == 403


def test_sin_token_no_hay_acceso(client):
    assert client.get("/sensores/").status_code == 401


def test_validaciones_de_crear_y_editar(client, admin):
    pila = _primera_pila(client, admin)
    # pila inexistente
    r = client.post("/sensores/", json=_nuevo("no-existe"), headers=admin)
    assert r.status_code == 404
    # codigo repetido (el seed ya crea TMP-xxxx)
    existente = client.get("/sensores/", headers=admin).json()[0]
    r = client.post(
        "/sensores/",
        json=_nuevo(pila["id"], codigo=existente["codigo_dispositivo"]),
        headers=admin,
    )
    assert r.status_code == 400
    # tipo invalido
    r = client.post("/sensores/", json=_nuevo(pila["id"], tipo="radar"), headers=admin)
    assert r.status_code == 422
    # editar con el codigo de otro sensor
    otro = client.post("/sensores/", json=_nuevo(pila["id"]), headers=admin).json()
    r = client.put(
        f"/sensores/{otro['id']}",
        json={"codigo_dispositivo": existente["codigo_dispositivo"]},
        headers=admin,
    )
    assert r.status_code == 400
    # conservar su propio codigo no es conflicto
    r = client.put(
        f"/sensores/{otro['id']}",
        json={"codigo_dispositivo": otro["codigo_dispositivo"]},
        headers=admin,
    )
    assert r.status_code == 200
    # mover a una pila inexistente
    r = client.put(f"/sensores/{otro['id']}", json={"pila_id": "x"}, headers=admin)
    assert r.status_code == 404
    # sensor inexistente
    assert client.put("/sensores/x", json={}, headers=admin).status_code == 404


def test_filtros_de_listado(client, estudiante):
    todos = client.get("/sensores/", headers=estudiante).json()
    assert len(todos) == 12  # 4 pilas x 3 sensores del seed
    inactivos = client.get("/sensores/?activo=false", headers=estudiante).json()
    assert len(inactivos) == 1 and inactivos[0]["tipo"] == "gas_ch4"
    humedad = client.get("/sensores/?tipo=humedad", headers=estudiante).json()
    assert len(humedad) == 4 and {s["tipo"] for s in humedad} == {"humedad"}
    pila_id = todos[0]["pila_id"]
    de_pila = client.get(f"/sensores/?pila_id={pila_id}", headers=estudiante).json()
    assert len(de_pila) == 3
    por_codigo = client.get("/sensores/?q=hum", headers=estudiante).json()
    assert len(por_codigo) == 4
