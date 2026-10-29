-- Aviso de sensor danado. Ejecutar UNA vez en bases que ya existian.
-- Sirve igual en MySQL y en SQLite (cada columna en su propia sentencia).
-- Si empiezas con una base nueva, create_all ya crea estas columnas.

ALTER TABLE sensores ADD COLUMN danado BOOLEAN NOT NULL DEFAULT 0;
ALTER TABLE sensores ADD COLUMN detalle_dano VARCHAR(255);
ALTER TABLE sensores ADD COLUMN danado_en DATETIME;
