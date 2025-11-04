-- 04_distribute_table.sql
-- Conectar a la base de datos historiaclinica
\c historiaclinica

-- Crear la tabla distribuida correctamente por documento_id
SELECT create_distributed_table('gestion_medica.pacientes', 'documento_id');

