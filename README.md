# 🏥 Sistema de Historia Clínica Electrónica Distribuida

> Sistema integral de gestión de historias clínicas electrónicas con arquitectura distribuida, autenticación por roles y exportación a PDF

[![FastAPI](https://img.shields.io/badge/FastAPI-0.120.4-009688?logo=fastapi)](https://fastapi.tiangolo.com/)
[![PostgreSQL](https://img.shields.io/badge/PostgreSQL-Citus_12.1-336791?logo=postgresql)](https://www.citusdata.com/)
[![Kubernetes](https://img.shields.io/badge/Kubernetes-Minikube-326CE5?logo=kubernetes)](https://minikube.sigs.k8s.io/)
[![Python](https://img.shields.io/badge/Python-3.10-3776AB?logo=python)](https://www.python.org/)
[![Flask](https://img.shields.io/badge/Flask-2.3.3-000000?logo=flask)](https://flask.palletsprojects.com/)

---

## 📋 Tabla de Contenidos

- [Descripción del Proyecto](#-descripción-del-proyecto)
- [Características Principales](#-características-principales)
- [Arquitectura del Sistema](#-arquitectura-del-sistema)
- [Requisitos Previos](#-requisitos-previos)
- [Instalación y Despliegue](#-instalación-y-despliegue)
- [Configuración de Acceso](#-configuración-de-acceso)
- [Uso del Sistema](#-uso-del-sistema)
- [Autenticación y Roles](#-autenticación-y-roles)
- [API Endpoints](#-api-endpoints)
- [Exportación a PDF](#-exportación-a-pdf)
- [Estructura del Proyecto](#-estructura-del-proyecto)
- [Documentación Técnica](#-documentación-técnica)
- [Troubleshooting](#-troubleshooting)

---

## 🎯 Descripción del Proyecto

**Sistema de Historia Clínica Electrónica Distribuida** es una solución completa para la gestión de historias clínicas médicas, diseñada con arquitectura de microservicios y base de datos distribuida. El sistema permite el acceso seguro desde cualquier dispositivo (escritorio, tablet, smartphone) mediante autenticación OAuth2 + JWT, con control de acceso basado en roles y exportación de historias clínicas en formato PDF.

### 🎓 Contexto Académico

Este proyecto fue desarrollado como parte de la asignatura **"Sistemas distribuidos"**, implementando las mejores prácticas en:

- Arquitectura distribuida con fragmentación de datos
- Seguridad mediante OAuth2 + JWT
- Orquestación con Kubernetes
- Patrones de diseño de microservicios
- Control de acceso basado en roles (RBAC)

---

## ✨ Características Principales

### 🎯 Funcionalidades Core

- ✅ **Base de Datos Distribuida**: PostgreSQL + Citus con fragmentación por `numero_documento` (32 shards)
- ✅ **API REST Completa**: FastAPI con validación Pydantic y documentación automática
- ✅ **Sistema de Roles**: 5 roles diferenciados con permisos granulares
- ✅ **Autenticación Robusta**: OAuth2 + JWT con tokens de 30 minutos + bcrypt
- ✅ **CRUD Completo**: Operaciones sobre pacientes con control de acceso
- ✅ **Exportación PDF**: Generación de historias clínicas con WeasyPrint
- ✅ **Acceso Multi-dispositivo**: Desde red local (smartphones, tablets, PCs)
- ✅ **57 Campos Clínicos**: Modelo completo según estándares colombianos
- ✅ **Orquestación**: Kubernetes (Minikube) con alta disponibilidad
- ✅ **Interfaces Gráficas**: 7 vistas HTML diferenciadas por rol

### 🛡️ Seguridad

- 🔐 Autenticación con base de datos usando bcrypt
- 🔑 Tokens JWT con expiración configurable
- 👥 Control de acceso basado en roles (RBAC)
- 📝 Validación de permisos por endpoint
- 🔒 Secrets de Kubernetes para credenciales sensibles
- 🚫 Protección contra acceso no autorizado

### 🌐 Accesibilidad

- 📱 Acceso desde dispositivos móviles en red local
- 💻 Interfaz web responsiva con Bootstrap 5
- 🔗 NodePort configurado para acceso externo
- 📡 Port forwarding automático para red local
- ⚡ Configuración automatizada con scripts

---

## 🏗️ Arquitectura del Sistema

### Diagrama de Componentes

```
┌─────────────────────────────────────────────────────────────┐
│                   CAPA DE PRESENTACIÓN                       │
│  ┌──────────┐  ┌──────────┐  ┌──────────────────────────┐  │
│  │Swagger UI│  │  ReDoc   │  │  Interfaces Web (Flask)  │  │
│  └────┬─────┘  └────┬─────┘  └────────────┬─────────────┘  │
│       └─────────────┴──────────────────────┘                │
│                       │ HTTP/REST                            │
└───────────────────────┼─────────────────────────────────────┘
                        │
┌───────────────────────▼─────────────────────────────────────┐
│                  CAPA DE APLICACIÓN                          │
│  ┌─────────────────────────────────────────────────────┐    │
│  │         FastAPI Middleware (Python 3.10)            │    │
│  │  ┌──────────┐  ┌──────────┐  ┌───────────────┐     │    │
│  │  │   JWT    │  │   CRUD   │  │  WeasyPrint   │     │    │
│  │  │  OAuth2  │  │  + RBAC  │  │  PDF Export   │     │    │
│  │  └──────────┘  └──────────┘  └───────────────┘     │    │
│  │                                                      │    │
│  │  Endpoints Principales:                             │    │
│  │  • POST /token → Autenticación                      │    │
│  │  • GET /me → Usuario actual                         │    │
│  │  • GET /pacientes → Listar (RBAC)                   │    │
│  │  • POST /pacientes → Crear                          │    │
│  │  • GET /pacientes/{doc}/pdf → Exportar              │    │
│  └──────────────────────────────────────────────────────┘   │
│                       │ psycopg2                             │
└───────────────────────┼─────────────────────────────────────┘
                        │
┌───────────────────────▼─────────────────────────────────────┐
│                    CAPA DE DATOS                             │
│  ┌─────────────────────────────────────────────────────┐    │
│  │       Citus Coordinator (PostgreSQL 12.1)           │    │
│  │                                                      │    │
│  │  Tablas:                                            │    │
│  │  • usuarios (con bcrypt)                            │    │
│  │  • pacientes (57 campos, distribuida, 32 shards)    │    │
│  │                                                      │    │
│  │  Extensiones: citus, pgcrypto                       │    │
│  └───────┬─────────────────────────────┬────────────────┘   │
│          │                             │                     │
│    ┌─────▼──────┐              ┌──────▼─────┐              │
│    │  Worker 1  │              │  Worker 2  │              │
│    └────────────┘              └────────────┘              │
└─────────────────────────────────────────────────────────────┘
                        │
┌───────────────────────▼─────────────────────────────────────┐
│              CAPA DE INFRAESTRUCTURA                         │
│  ┌─────────────────────────────────────────────────────┐    │
│  │    Kubernetes (Minikube) - Namespace: citus        │    │
│  │                                                      │    │
│  │  Services:                 Deployments:             │    │
│  │  • citus-coordinator       • coordinator (1 pod)    │    │
│  │  • citus-worker            • workers (2 pods)       │    │
│  │  • middleware-service      • middleware (1 pod)     │    │
│  │    (NodePort: 30800)                                │    │
│  │                                                      │    │
│  │  Secrets: app-secrets (credenciales cifradas)      │    │
│  └─────────────────────────────────────────────────────┘    │
└─────────────────────────────────────────────────────────────┘
```

### 🔐 Flujo de Autenticación OAuth2 + JWT

```
┌─────────┐                                    ┌─────────┐
│ Cliente │                                    │   API   │
└────┬────┘                                    └────┬────┘
     │                                              │
     │  POST /token                                 │
     │  {username, password}                        │
     ├─────────────────────────────────────────────>│
     │                                              │
     │                                   ┌──────────▼──────────┐
     │                                   │ 1. Consultar BD     │
     │                                   │ 2. Verificar bcrypt │
     │                                   │ 3. Generar JWT      │
     │                                   └──────────┬──────────┘
     │                                              │
     │  200 OK + {access_token, user}               │
     │<─────────────────────────────────────────────┤
     │                                              │
     │  GET /pacientes                              │
     │  Authorization: Bearer <token>               │
     ├─────────────────────────────────────────────>│
     │                                              │
     │                                   ┌──────────▼──────────┐
     │                                   │ 1. Validar JWT      │
     │                                   │ 2. Verificar rol    │
     │                                   │ 3. Ejecutar query   │
     │                                   └──────────┬──────────┘
     │                                              │
     │  200 OK + [{pacientes}]                      │
     │<─────────────────────────────────────────────┤
```

### 🗄️ Fragmentación de Datos en Citus

**Estrategia**: Fragmentación por `numero_documento` (hash distribution)

**Justificación**:
- ✅ Alta cardinalidad (cada documento es único)
- ✅ Distribución uniforme entre workers
- ✅ Consultas por documento son muy frecuentes
- ✅ Evita hot spots y cuellos de botella

**Configuración**:
```sql
SELECT create_distributed_table('public.pacientes', 'numero_documento');
-- Resultado: 32 shards distribuidos entre coordinator y 2 workers
```

---

## 📦 Requisitos Previos

### Software Necesario

| Software | Versión Mínima | Verificación |
|----------|----------------|--------------|
| **Minikube** | v1.30+ | `minikube version` |
| **kubectl** | v1.28+ | `kubectl version --client` |
| **Docker** | v20.10+ | `docker --version` |
| **Python** | 3.10+ | `python3 --version` |
| **curl** | Cualquiera | `curl --version` |

### Recursos de Hardware

| Recurso | Mínimo | Recomendado |
|---------|--------|-------------|
| **CPU** | 4 cores | 8 cores |
| **RAM** | 4 GB | 8 GB |
| **Disco** | 10 GB libre | 20 GB libre |

### Instalación Rápida (Arch Linux)

```bash
# Minikube
sudo pacman -S minikube

# kubectl
sudo pacman -S kubectl

# Docker
sudo pacman -S docker
sudo systemctl enable --now docker
sudo usermod -aG docker $USER

# Python 3.10
sudo pacman -S python python-pip
```

---

## 🚀 Instalación y Despliegue

### Opción 1: Despliegue Automatizado Completo (Recomendado)

El script `inicializador.sh` ejecuta **todos los pasos** de forma secuencial:

```bash
# Clonar repositorio
git clone <URL_DEL_REPOSITORIO>
cd Historia-Clinica-Distribuida

# Dar permisos de ejecución
chmod +x inicializador.sh

# Ejecutar instalación completa
./inicializador.sh
```

**⏱️ Tiempo estimado**: 10-15 minutos

**¿Qué hace este script?**

1. ✅ Verifica requisitos (Minikube, kubectl, Docker, Python)
2. ✅ Inicia Minikube con recursos adecuados
3. ✅ Crea namespace `citus`
4. ✅ Despliega Citus (1 coordinator + 2 workers)
5. ✅ Configura base de datos `historiaclinica`
6. ✅ Crea tablas `usuarios` y `pacientes` (57 campos)
7. ✅ Inserta usuarios y pacientes de prueba
8. ✅ Construye imagen Docker del middleware
9. ✅ Crea Kubernetes secrets
10. ✅ Despliega middleware con NodePort
11. ✅ Configura exposición a red local
12. ✅ **Lanza servidor frontend automáticamente**

**Salida esperada**:

```
================================================================
  ✓ Backend listo y expuesto en http://192.168.1.X:8000
  🚀 El frontend se lanzará a continuación en http://localhost:5000
================================================================

🏥 FRONTEND - SISTEMA DE HISTORIA CLÍNICA
================================================================

URLs disponibles:
   • http://localhost:5000/              (Login)
   • http://localhost:5000/medico.html   (Panel Médico)
   • http://localhost:5000/paciente.html (Panel Paciente)

Backend (FastAPI):
   • http://192.168.1.X:8000/docs

✅ Servidor listo.
```

### Opción 2: Despliegue Manual por Pasos

Si prefieres control total sobre cada fase:

#### Paso 1: Configurar Backend

```bash
cd backend/project
chmod +x setup.sh
./setup.sh 2>&1 | tee setup_log.txt
```

#### Paso 2: Habilitar NodePort

```bash
chmod +x enable_nodeport.sh
./enable_nodeport.sh 2>&1 | tee nodeport_setup.log
```

#### Paso 3: Exponer a Red Local (Host)

```bash
chmod +x expose_to_network.sh
./expose_to_network.sh
```

#### Paso 4: Exponer a Red Real (Dispositivos Móviles)

```bash
chmod +x expose_to_real_network.sh
./expose_to_real_network.sh
```

#### Paso 5: Lanzar Frontend

```bash
cd ../../frontend
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
python3 prueba.py
```

---

## 🌐 Configuración de Acceso

### Acceso Local (Port-Forward)

```bash
kubectl port-forward -n citus service/middleware-citus-service 8000:8000 &
```

**URLs**:
- Backend API: `http://localhost:8000`
- Swagger UI: `http://localhost:8000/docs`
- Frontend: `http://localhost:5000`

### Acceso desde Red Local (NodePort)

Después de ejecutar `enable_nodeport.sh`:

```bash
# Obtener IP de Minikube
minikube ip
# Ejemplo: 192.168.49.2

# Acceder desde cualquier PC en la red
curl http://192.168.49.2:30800/health
```

**URLs**:
- Backend: `http://192.168.49.2:30800`
- Swagger: `http://192.168.49.2:30800/docs`

### Acceso desde Dispositivos Móviles

Después de ejecutar `expose_to_real_network.sh`:

```bash
# El script detecta automáticamente tu IP local
# Ejemplo salida:
# IP de red local detectada: 192.168.1.100
```

**Desde smartphone/tablet**:

1. Conecta el dispositivo a la **misma red WiFi**
2. Abre el navegador
3. Navega a `http://192.168.1.100:8000/docs`

**URLs disponibles**:
- Backend: `http://192.168.1.100:8000`
- Frontend: `http://192.168.1.100:5000`

---

## 💻 Uso del Sistema

### Login

**URL**: `http://localhost:5000/login.html`

**Usuarios de Prueba**:

| Username | Contraseña | Rol | Descripción |
|----------|-----------|-----|-------------|
| `admin` | `admin` | Admin | Administrador del sistema |
| `dr_rodriguez` | `password123` | Médico | Dr. Carlos Rodríguez |
| `dra_martinez` | `password123` | Médico | Dra. Ana Martínez |
| `admisionista1` | `password123` | Admisionista | María González |
| `resultados1` | `password123` | Resultados | Pedro López |
| `paciente_juan` | `password123` | Paciente | Juan Pérez (doc: 12345) |
| `paciente_maria` | `password123` | Paciente | María Gómez (doc: 67890) |

### Flujo de Trabajo Típico

#### Como Médico:

1. Login → Redirige a `medico.html`
2. **Buscar paciente**: Por documento o nombre
3. **Ver historia clínica**: Click en "Ver"
4. **Editar historia**: Click en "Editar" → Actualizar campos
5. **Exportar PDF**: Click en "Descargar PDF"

#### Como Admisionista:

1. Login → Redirige a `admisionista.html`
2. **Registrar nuevo paciente**: Click en "Registrar Nuevo Paciente"
3. Completar formulario (campos obligatorios: documento, nombre, fecha nacimiento, sexo)
4. **Guardar**: Sistema crea historia clínica

#### Como Paciente:

1. Login → Redirige a `paciente.html`
2. **Ver mi historia**: Solo lectura de datos propios
3. **Descargar PDF**: Click en "Descargar Historia en PDF"

---

## 🔐 Autenticación y Roles

### Sistema de Roles

El sistema implementa **RBAC (Role-Based Access Control)** con 5 roles:

| Rol | Permisos | Descripción |
|-----|----------|-------------|
| **👑 Admin** | Acceso total | Gestión de usuarios, todas las historias, estadísticas |
| **👨‍⚕️ Médico** | Lectura/Escritura | Acceso completo a historias, crear y modificar |
| **📋 Admisionista** | Crear/Actualizar | Registro de nuevos pacientes, datos básicos |
| **🧪 Resultados** | Agregar resultados | Ingresar resultados de exámenes |
| **🙍 Paciente** | Solo lectura propia | Ver únicamente su propia historia |

### Matriz de Permisos

| Acción | Admin | Médico | Admisionista | Resultados | Paciente |
|--------|-------|--------|--------------|------------|----------|
| Ver cualquier historia | ✅ | ✅ | ✅ | ✅ | ❌ |
| Ver propia historia | ✅ | ✅ | ✅ | ✅ | ✅ |
| Crear paciente | ✅ | ✅ | ✅ | ❌ | ❌ |
| Actualizar paciente | ✅ | ✅ | ❌ | ❌ | ❌ |
| Eliminar paciente | ✅ | ❌ | ❌ | ❌ | ❌ |
| Gestionar usuarios | ✅ | ❌ | ❌ | ❌ | ❌ |
| Ver estadísticas | ✅ | ❌ | ❌ | ❌ | ❌ |
| Exportar PDF | ✅ | ✅ | ✅ | ✅ | ✅ (propio) |

### Obtener Token JWT

```bash
curl -X POST http://localhost:8000/token \
  -H "Content-Type: application/json" \
  -d '{
    "username": "admin",
    "password": "admin"
  }'
```

**Respuesta**:

```json
{
  "access_token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
  "token_type": "bearer",
  "expires_in": 1800,
  "user": {
    "id": 1,
    "username": "admin",
    "rol": "admin",
    "nombres": "Administrador",
    "apellidos": "Sistema"
  }
}
```

### Usar Token en Requests

```bash
TOKEN="eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9..."

curl http://localhost:8000/pacientes \
  -H "Authorization: Bearer $TOKEN"
```

---

## 📡 API Endpoints

### Documentación Interactiva

- **Swagger UI**: `http://localhost:8000/docs`
- **ReDoc**: `http://localhost:8000/redoc`
- **OpenAPI JSON**: `http://localhost:8000/openapi.json`

### Endpoints Públicos

| Método | Endpoint | Descripción |
|--------|----------|-------------|
| `GET` | `/` | Información general de la API |
| `GET` | `/health` | Estado del sistema y BD |
| `POST` | `/token` | Autenticación (retorna JWT) |

### Endpoints Protegidos - Pacientes

| Método | Endpoint | Roles | Descripción |
|--------|----------|-------|-------------|
| `GET` | `/pacientes` | Staff | Listar pacientes (resumido) |
| `GET` | `/pacientes/{doc}` | Staff, Paciente (propio) | Historia clínica completa |
| `POST` | `/pacientes` | Admisionista, Médico, Admin | Crear paciente |
| `PUT` | `/pacientes/{doc}` | Médico, Admin | Actualizar paciente |
| `DELETE` | `/pacientes/{doc}` | Admin | Eliminar (lógico) |
| `GET` | `/pacientes/buscar/query` | Staff | Buscar por nombre/documento |
| `GET` | `/pacientes/{doc}/pdf` | Staff, Paciente (propio) | Exportar PDF |

### Endpoints Protegidos - Usuarios

| Método | Endpoint | Roles | Descripción |
|--------|----------|-------|-------------|
| `GET` | `/me` | Todos | Usuario actual |
| `GET` | `/usuarios` | Admin | Listar usuarios |
| `POST` | `/usuarios` | Admin | Crear usuario |

### Endpoints Protegidos - Estadísticas

| Método | Endpoint | Roles | Descripción |
|--------|----------|-------|-------------|
| `GET` | `/estadisticas` | Admin | Estadísticas generales |

### Ejemplos de Uso

#### Crear Paciente

```bash
TOKEN="<tu_token>"

curl -X POST http://localhost:8000/pacientes \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "tipo_documento": "CC",
    "numero_documento": "98765432",
    "primer_apellido": "García",
    "primer_nombre": "Laura",
    "fecha_nacimiento": "1992-08-20",
    "sexo": "F",
    "celular": "3201234567"
  }'
```

#### Buscar Paciente

```bash
curl "http://localhost:8000/pacientes/buscar/query?nombre=Laura" \
  -H "Authorization: Bearer $TOKEN"
```

#### Actualizar Paciente

```bash
curl -X PUT http://localhost:8000/pacientes/98765432 \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "telefono": "3109876543",
    "motivo_consulta": "Control mensual"
  }'
```

---

## 📄 Exportación a PDF

### Generar PDF desde API

```bash
curl http://localhost:8000/pacientes/12345/pdf \
  -H "Authorization: Bearer $TOKEN" \
  --output historia_12345.pdf
```

### Características del PDF

- ✅ Encabezado profesional con logo
- ✅ 57 campos organizados por secciones
- ✅ Datos completos del paciente
- ✅ Signos vitales con formato visual
- ✅ Diagnósticos y tratamientos
- ✅ Pie de página con info legal
- ✅ Formato Letter (8.5" × 11")
- ✅ Protegido por autenticación

### Secciones del PDF

1. **Identificación del Paciente** (23 campos)
2. **Datos de Atención Médica** (17 campos)
3. **Antecedentes** (5 campos)
4. **Signos Vitales** (9 campos)
5. **Examen Físico y Diagnóstico** (9 campos)
6. **Conducta y Tratamiento** (7 campos)
7. **Procedimientos y Resultados** (7 campos)
8. **Evolución y Egreso** (3 campos)
9. **Datos del Profesional** (8 campos)

### Desde Interfaz Web

1. Login → Panel correspondiente
2. Buscar paciente
3. Click en **"Descargar PDF"** o **"📄 PDF"**
4. El navegador descarga automáticamente

---

## 📁 Estructura del Proyecto

```
Historia-Clinica-Distribuida/
│
├── backend/
│   └── project/
│       ├── app/
│       │   ├── __init__.py
│       │   ├── main.py              # FastAPI app principal
│       │   ├── auth.py              # OAuth2 + JWT + RBAC
│       │   ├── database.py          # Conexión Citus
│       │   ├── models.py            # Modelos Pydantic (57 campos)
│       │   └── pdf_generator.py     # WeasyPrint PDFs
│       │
│       ├── infra/
│       │   ├── citus-deployment.yaml           # Citus coordinator + workers
│       │   ├── app-deployment.yaml             # Middleware (ClusterIP)
│       │   ├── app-deployment-nodeport.yaml    # Middleware (NodePort)
│       │   └── initdb/                         # Scripts SQL inicialización
│       │       ├── 01_create_extension.sql
│       │       ├── 06_create_usuarios.sql
│       │       ├── 07_create_pacientes_completo.sql
│       │       └── 08_insert_data_complete.sql
│       │
│       ├── Dockerfile               # Imagen middleware
│       ├── requirements.txt         # Dependencias Python (backend)
│       ├── setup.sh                 # Instalación completa backend ⚡
│       ├── enable_nodeport.sh       # Configurar NodePort
│       ├── expose_to_network.sh     # Exponer a host
│       └── expose_to_real_network.sh # Exponer a red real
│
├── frontend/
│   ├── templates/                   # Vistas HTML
│   │   ├── login.html               # Página de login
│   │   ├── medico.html              # Panel médico
│   │   ├── paciente.html            # Panel paciente
│   │   ├── admisionista.html        # Panel admisionista
│   │   ├── resultados.html          # Panel resultados
│   │   ├── panel_admin.html         # Panel admin
│   │   ├── gestionar_usuarios.html  # Gestión usuarios
│   │   ├── reportes.html            # Reportes y estadísticas
│   │   ├── registrar_paciente.html  # Formulario 57 campos
│   │   ├── ver_historia_clinica.html # Vista completa HC
│   │   ├── editar_historia_clinica.html # Edición HC
│   │   └── historia_pdf.html        # Visor PDF
│   │
│   ├── static/
│   │   ├── js/
│   │   │   └── config.js            # Configuración API + utilidades
│   │   └── css/
│   │       └── style.css
│   │
│   ├── prueba.py                    # Servidor Flask
│   └── requirements.txt             # Dependencias Python (frontend)
│
├── inicializador.sh                 # 🚀 Script unificado TODO-EN-UNO
├── README.md                        # Este archivo
└── .gitignore
```

---

## 📚 Documentación Técnica

### Modelo de Datos - Tabla `pacientes` (57 Campos)

#### 1. Identificación del Paciente (23 campos)

| Campo | Tipo | Obligatorio | Descripción |
|-------|------|-------------|-------------|
| `tipo_documento` | VARCHAR(20) | ✅ | CC, TI, CE, PA, RC |
| `numero_documento` | VARCHAR(20) | ✅ | **Clave de distribución** |
| `primer_apellido` | VARCHAR(100) | ✅ | Apellido paterno |
| `segundo_apellido` | VARCHAR(100) | ❌ | Apellido materno |
| `primer_nombre` | VARCHAR(100) | ✅ | Nombre principal |
