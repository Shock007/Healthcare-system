\connect historiaclinica

-- ==================== EXTENSIONES ====================
CREATE EXTENSION IF NOT EXISTS citus;
CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- ==================== TABLA USUARIOS ====================
DROP TABLE IF EXISTS public.usuarios CASCADE;

CREATE TABLE public.usuarios (
    id SERIAL PRIMARY KEY,
    username VARCHAR(50) UNIQUE NOT NULL,
    password_hash VARCHAR(255) NOT NULL,
    rol VARCHAR(20) NOT NULL CHECK (rol IN ('paciente', 'medico', 'admisionista', 'resultados', 'admin')),
    nombres VARCHAR(200),
    apellidos VARCHAR(200),
    documento_vinculado VARCHAR(20),  -- Si es paciente, referencia a su historia
    activo BOOLEAN DEFAULT TRUE,
    fecha_creacion TIMESTAMP DEFAULT NOW(),
    ultimo_acceso TIMESTAMP
);
