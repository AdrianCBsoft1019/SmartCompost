-- Migracion para bases MySQL YA creadas antes del modulo Pilas/Analisis.
-- (Base.metadata.create_all crea tablas nuevas, pero NO agrega columnas
-- a tablas existentes.) Si prefieres, `docker compose down -v` borra todo.
--
-- La tabla `lecturas` es nueva: la crea la API sola al arrancar.

ALTER TABLE pilas
  ADD COLUMN fecha_inicio DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  ADD COLUMN dias_ciclo INT NOT NULL DEFAULT 90;
