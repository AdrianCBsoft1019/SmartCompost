"""Prueba de carga de SmartCompost.

Cada usuario simulado inicia sesion una vez y luego consulta la API.
Requiere haber cargado los datos de prueba:
    docker compose exec --index 1 backend python -m app.seed
"""

from locust import HttpUser, between, task


class UsuarioSmartCompost(HttpUser):
    wait_time = between(1, 2)

    def on_start(self):
        respuesta = self.client.post(
            "/auth/login",
            json={"correo": "estudiante@smartcompost.com", "password": "Estudiante123"},
        )
        token = respuesta.json().get("access_token", "") if respuesta.ok else ""
        self.client.headers["Authorization"] = f"Bearer {token}"

    @task(3)
    def salud(self):
        self.client.get("/api/health")

    @task(2)
    def listar_pilas(self):
        self.client.get("/pilas/")

    @task(1)
    def resumen_alertas(self):
        self.client.get("/alertas/resumen?periodo=semana")
