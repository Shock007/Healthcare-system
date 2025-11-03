-- 01_create_pacientes.sql
CREATE TABLE IF NOT EXISTS pacientes (
    id SERIAL,
    documento_id INT NOT NULL,
    nombre TEXT,
    apellido TEXT,
    fecha_nacimiento DATE,
    PRIMARY KEY (documento_id, id)
);

SELECT create_distributed_table('pacientes', 'documento_id');
