-- 06_add_fhir_column.sql
-- Agregar columna fhir_id para almacenar el ID del recurso en HAPI FHIR
\connect historiaclinica

-- Agregar columna fhir_id si no existe
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_schema = 'public'
        AND table_name = 'pacientes'
        AND column_name = 'fhir_id'
    ) THEN
        ALTER TABLE public.pacientes
        ADD COLUMN fhir_id VARCHAR(100) UNIQUE;

        RAISE NOTICE 'Columna fhir_id agregada exitosamente';
    ELSE
        RAISE NOTICE 'Columna fhir_id ya existe';
    END IF;
END $$;

-- Crear índice para búsquedas rápidas por fhir_id
CREATE INDEX IF NOT EXISTS idx_pacientes_fhir_id
ON public.pacientes(fhir_id);
