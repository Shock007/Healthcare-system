-- Índices para usuarios
CREATE INDEX idx_usuarios_username ON public.usuarios(username);
CREATE INDEX idx_usuarios_rol ON public.usuarios(rol);
CREATE INDEX idx_usuarios_documento ON public.usuarios(documento_vinculado);

-- Insertar usuarios de prueba (password: todos usan "password123")
-- Hash generado con: SELECT crypt('password123', gen_salt('bf'))
INSERT INTO public.usuarios (username, password_hash, rol, nombres, apellidos, documento_vinculado) VALUES
('admin', crypt('admin', gen_salt('bf')), 'admin', 'Administrador', 'Sistema', NULL),
('dr_rodriguez', crypt('password123', gen_salt('bf')), 'medico', 'Carlos', 'Rodríguez', NULL),
('dra_martinez', crypt('password123', gen_salt('bf')), 'medico', 'Ana', 'Martínez', NULL),
('admisionista1', crypt('password123', gen_salt('bf')), 'admisionista', 'María', 'González', NULL),
('resultados1', crypt('password123', gen_salt('bf')), 'resultados', 'Pedro', 'López', NULL),
('paciente_juan', crypt('password123', gen_salt('bf')), 'paciente', 'Juan', 'Pérez', '12345'),
('paciente_maria', crypt('password123', gen_salt('bf')), 'paciente', 'María', 'Gómez', '67890');

-- ==================== TABLA PACIENTES (Incluir el schema completo anterior) ====================
-- Ver artifact anterior para el schema completo

-- ==================== DATOS DE PRUEBA ====================
INSERT INTO public.pacientes (
    tipo_documento, numero_documento,
    primer_apellido, segundo_apellido, primer_nombre, segundo_nombre,
    fecha_nacimiento, sexo, genero,
    grupo_sanguineo, factor_rh, estado_civil,
    direccion_residencia, municipio, departamento,
    telefono, celular, correo_electronico,
    ocupacion, entidad, regimen_afiliacion, tipo_usuario,
    tipo_atencion, motivo_consulta, enfermedad_actual,
    tension_arterial, frecuencia_cardiaca, frecuencia_respiratoria,
    temperatura, saturacion_oxigeno, peso, talla,
    impresion_diagnostica, nombre_profesional, tipo_profesional
) VALUES
(
    'CC', '12345',
    'Pérez', 'Gómez', 'Juan', 'Carlos',
    '1995-04-12', 'M', 'Masculino',
    'O+', 'Positivo', 'Soltero',
    'Calle 123 #45-67', 'Sincelejo', 'Sucre',
    '2774500', '3001234567', 'juanp@example.com',
    'Ingeniero', 'Nueva EPS', 'Contributivo', 'Afiliado',
    'Consulta Externa', 'Control de rutina', 'Paciente asintomático que acude a control médico preventivo',
    '120/80', 72, 16,
    36.5, 98, 75.0, 175.0,
    'Paciente sano, control preventivo', 'Dr. Carlos Rodríguez', 'Médico General'
),
(
    'CC', '67890',
    'Gómez', 'Martínez', 'María', 'Fernanda',
    '1989-09-30', 'F', 'Femenino',
    'A+', 'Positivo', 'Casado',
    'Carrera 45 #12-34', 'Sincelejo', 'Sucre',
    '2774501', '3109876543', 'mariag@example.com',
    'Docente', 'Sanitas EPS', 'Contributivo', 'Afiliado',
    'Consulta Externa', 'Dolor abdominal', 'Paciente refiere dolor abdominal de 2 días de evolución',
    '110/70', 78, 18,
    36.8, 97, 62.0, 165.0,
    'Gastritis aguda', 'Dra. Ana Martínez', 'Médico General'
),
(
    'CC', '11111',
    'López', 'Torres', 'Pedro', 'Antonio',
    '1992-06-15', 'M', 'Masculino',
    'B+', 'Positivo', 'Union Libre',
    'Avenida 80 #20-10', 'Sincelejo', 'Sucre',
    '2774502', '3201112233', 'pedro@example.com',
    'Comerciante', 'Coosalud', 'Subsidiado', 'Subsidiado',
    'Urgencias', 'Trauma en pierna derecha', 'Paciente con trauma en miembro inferior derecho por caída',
    '130/85', 88, 20,
    37.0, 96, 80.0, 172.0,
    'Esguince grado II tobillo derecho', 'Dr. Carlos Rodríguez', 'Médico Urgencias'
);
