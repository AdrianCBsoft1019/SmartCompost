-- Foto de perfil. Ejecutar UNA vez en bases que ya existian.
-- Sirve igual en MySQL y en SQLite (cada columna en su propia sentencia).
-- Si empiezas con una base nueva, create_all ya crea estas columnas.

ALTER TABLE usuarios ADD COLUMN foto LONGBLOB;
ALTER TABLE usuarios ADD COLUMN foto_tipo VARCHAR(30);
