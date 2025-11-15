-- ========================================
-- TABLA PACIENTES COMPLETA - 57 CAMPOS
-- VERSIÓN CORREGIDA (sin columnas calculadas problemáticas)
-- ========================================

\connect historiaclinica

DROP TABLE IF EXISTS public.pacientes CASCADE;

CREATE TABLE public.pacientes (
    id SERIAL,

    -- ==================== DATOS DE IDENTIFICACIÓN (23 campos) ====================
    tipo_documento VARCHAR(20) NOT NULL,
    numero_documento VARCHAR(20) NOT NULL UNIQUE,
    primer_apellido VARCHAR(100) NOT NULL,
    segundo_apellido VARCHAR(100),
    primer_nombre VARCHAR(100) NOT NULL,
    segundo_nombre VARCHAR(100),
    fecha_nacimiento DATE NOT NULL,
    sexo VARCHAR(10) NOT NULL CHECK (sexo IN ('M', 'F', 'Otro')),
    genero VARCHAR(50),
    grupo_sanguineo VARCHAR(5) CHECK (grupo_sanguineo IN ('A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-')),
    factor_rh VARCHAR(10),
    estado_civil VARCHAR(20) CHECK (estado_civil IN ('Soltero', 'Casado', 'Union Libre', 'Divorciado', 'Viudo')),
    direccion_residencia TEXT,
    municipio VARCHAR(100),
    departamento VARCHAR(100),
    telefono VARCHAR(20),
    celular VARCHAR(20),
    correo_electronico VARCHAR(100),
    ocupacion VARCHAR(100),
    entidad VARCHAR(100),
    regimen_afiliacion VARCHAR(50) CHECK (regimen_afiliacion IN ('Contributivo', 'Subsidiado', 'Especial', 'No afiliado')),
    tipo_usuario VARCHAR(50),

    -- ==================== DATOS ADMINISTRATIVOS DE ATENCIÓN (17 campos) ====================
    fecha_atencion TIMESTAMP DEFAULT NOW(),
    tipo_atencion VARCHAR(50) CHECK (tipo_atencion IN ('Urgencias', 'Consulta Externa', 'Hospitalizacion', 'Cirugia', 'Procedimiento')),
    motivo_consulta TEXT,
    enfermedad_actual TEXT,
    antecedentes_personales TEXT,
    antecedentes_familiares TEXT,
    alergias_conocidas TEXT,
    habitos TEXT,
    medicamentos_actuales TEXT,

    -- Signos vitales (9 campos)
    tension_arterial VARCHAR(20),
    frecuencia_cardiaca INTEGER,
    frecuencia_respiratoria INTEGER,
    temperatura DECIMAL(4,2),
    saturacion_oxigeno INTEGER,
    peso DECIMAL(5,2),
    talla DECIMAL(5,2),

    -- ==================== EXAMEN Y DIAGNÓSTICO (9 campos) ====================
    examen_fisico_general TEXT,
    examen_fisico_sistemas TEXT,
    impresion_diagnostica TEXT,
    codigos_cie10 TEXT,
    conducta_plan TEXT,
    recomendaciones TEXT,
    medicos_interconsultados TEXT,
    procedimientos_realizados TEXT,
    resultados_examenes TEXT,

    -- ==================== CIERRE Y SEGUIMIENTO (7 campos) ====================
    diagnostico_definitivo TEXT,
    evolucion_medica TEXT,
    tratamiento_instaurado TEXT,
    formulacion_medica TEXT,
    educacion_paciente TEXT,
    referencia_contrarreferencia TEXT,
    estado_egreso VARCHAR(50) CHECK (estado_egreso IN ('Mejorado', 'Igual', 'Empeorado', 'Fallecido', 'Remitido')),

    -- ==================== DATOS DEL PROFESIONAL (8 campos) ====================
    nombre_profesional VARCHAR(200),
    tipo_profesional VARCHAR(50),
    registro_medico VARCHAR(50),
    cargo_servicio VARCHAR(100),
    firma_profesional TEXT,
    firma_paciente TEXT,
    fecha_cierre TIMESTAMP,
    responsable_registro VARCHAR(200),

    -- ==================== METADATOS ====================
    fecha_registro TIMESTAMP DEFAULT NOW(),
    ultima_actualizacion TIMESTAMP DEFAULT NOW(),
    activo BOOLEAN DEFAULT TRUE,

    PRIMARY KEY (numero_documento, id)
);

-- Índices
CREATE INDEX idx_pacientes_nombres ON public.pacientes(primer_nombre, primer_apellido);
CREATE INDEX idx_pacientes_fecha_nac ON public.pacientes(fecha_nacimiento);
CREATE INDEX idx_pacientes_tipo_atencion ON public.pacientes(tipo_atencion);
CREATE INDEX idx_pacientes_fecha_atencion ON public.pacientes(fecha_atencion);
CREATE INDEX idx_pacientes_profesional ON public.pacientes(nombre_profesional);

-- Distribuir tabla
SELECT create_distributed_table('public.pacientes', 'numero_documento');

-- Crear vista con campos calculados (alternativa a columnas generadas)
CREATE OR REPLACE VIEW public.pacientes_view AS
SELECT
    *,
    DATE_PART('year', AGE(fecha_nacimiento))::INTEGER AS edad,
    CASE
        WHEN talla > 0 THEN ROUND((peso / POWER(talla/100, 2))::NUMERIC, 2)
        ELSE NULL
    END AS imc
FROM public.pacientes;

-- Verificar
SELECT * FROM citus_tables WHERE table_name::text = 'pacientes';
