def _primera_pila(client, headers):
    return client.get("/pilas/", headers=headers).json()[0]


def test_listado_y_filtros_de_pilas(client, estudiante):
    todas = client.get("/pilas/", headers=estudiante).json()
    assert len(todas) == 4
    norte = client.get("/pilas/?ubicacion=Planta Norte", headers=estudiante).json()
    assert {p["nombre"] for p in norte} == {"Pila A-102", "Pila D-112"}
    busqueda = client.get("/pilas/?q=C-088", headers=estudiante).json()
    assert len(busqueda) == 1 and busqueda[0]["fase"] == "maduracion"


def test_crud_pila_solo_instructor(client, admin, estudiante):
    datos = {"nombre": "Pila Nueva", "ubicacion": "Planta Sur", "dias_ciclo": 60}
    assert client.post("/pilas/", json=datos, headers=estudiante).status_code == 403
    r = client.post("/pilas/", json=datos, headers=admin)
    assert r.status_code == 201 and r.json()["madurez_pct"] == 0.0
    pid = r.json()["id"]
    r = client.put(f"/pilas/{pid}", json={"nombre": "Pila Editada"}, headers=admin)
    assert r.json()["nombre"] == "Pila Editada"
    assert client.put(f"/pilas/{pid}", json={}, headers=estudiante).status_code == 403
    assert client.delete(f"/pilas/{pid}", headers=admin).status_code == 204
    assert client.get(f"/pilas/{pid}", headers=admin).status_code == 404


def test_lectura_critica_actualiza_estado(client, admin):
    pila = _primera_pila(client, admin)
    r = client.post(
        f"/pilas/{pila['id']}/lecturas",
        json={"temperatura": 78, "humedad": 55, "ch4_ppm": 100},
        headers=admin,
    )
    assert r.status_code == 201
    assert r.json()["evaluacion"]["semaforo"] == "rojo"
    assert client.get(f"/pilas/{pila['id']}", headers=admin).json()["estado"] in (
        "critico",
        "listo",
    )


def test_detalle_de_pila(client, estudiante):
    pila = _primera_pila(client, estudiante)
    r = client.get(f"/pilas/{pila['id']}/detalle", headers=estudiante)
    assert r.status_code == 200
    d = r.json()
    assert len(d["serie_24h"]) >= 20
    assert d["evaluacion"]["indicador"] in ("seguro", "inseguro")
    assert d["gases"]["co2_ppm"] is not None


def test_analisis_por_periodo_y_pdf(client, estudiante):
    for periodo in ("semana", "mes", "anio"):
        r = client.get(f"/analisis/resumen?periodo={periodo}", headers=estudiante)
        assert r.status_code == 200
        assert r.json()["promedios"]["temperatura"] is not None
    assert (
        client.get("/analisis/resumen?periodo=siglo", headers=estudiante).status_code
        == 400
    )
    r = client.get("/analisis/resumen?periodo=semana", headers=estudiante).json()
    assert len(r["comparativa"]) == 4
    assert len(r["sensores_por_planta"]) == 3
    assert r["alertas_activas"], "la pila A-102 debe tener alertas activas"
    pdf = client.get("/analisis/reporte.pdf?periodo=mes", headers=estudiante)
    assert pdf.status_code == 200 and pdf.content.startswith(b"%PDF")


def test_filtros_sensores_y_pilas(client, estudiante):
    sensores = client.get("/analisis/sensores", headers=estudiante).json()
    inactivos = sum(p["inactivos"] for p in sensores)
    assert inactivos == 1
    assert client.get("/analisis/pilas", headers=estudiante).status_code == 200


def test_perfil_propio_y_gestion_de_usuarios(client, admin, estudiante):
    r = client.put(
        "/usuarios/me", json={"nombre_completo": "Nombre Nuevo"}, headers=estudiante
    )
    assert r.json()["nombre_completo"] == "Nombre Nuevo"
    r = client.put(
        "/usuarios/me", json={"password_nueva": "OtraClave123"}, headers=estudiante
    )
    assert r.status_code == 400  # falta la contrasena actual

    assert client.get("/usuarios/", headers=estudiante).status_code == 403
    nuevo = client.post(
        "/usuarios/",
        json={
            "nombre_completo": "Ana Perez",
            "correo": "ana@smartcompost.com",
            "password": "ClaveSegura1",
            "rol": "instructor",
        },
        headers=admin,
    )
    assert nuevo.status_code == 201 and nuevo.json()["rol"] == "instructor"
    uid = nuevo.json()["id"]
    r = client.put(f"/usuarios/{uid}", json={"rol": "aprendiz"}, headers=admin)
    assert r.json()["rol"] == "aprendiz"
    assert client.delete(f"/usuarios/{uid}", headers=admin).status_code == 204
    yo = client.get("/usuarios/me", headers=admin).json()
    assert client.delete(f"/usuarios/{yo['id']}", headers=admin).status_code == 400
