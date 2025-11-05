# 🏥 Sistema de Historia Clínica Distribuida
Tragedy
Sistema de gestión de historias clínicas basado en arquitectura distribuida con Citus, FastAPI y Kubernetes.

## 📋 Tabla de Contenidos

- [Características](#características)
- [Arquitectura](#arquitectura)
- [Requisitos](#requisitos)
- [Instalación](#instalación)
- [Uso](#uso)
- [API Endpoints](#api-endpoints)
- [Pruebas](#pruebas)
- [Desarrollo](#desarrollo)
- [Troubleshooting](#troubleshooting)

---

## ✨ Características

- ✅ **Base de datos distribuida** con Citus (PostgreSQL)
- ✅ **API REST** con FastAPI
- ✅ **Autenticación JWT** para seguridad
- ✅ **Despliegue en Kubernetes** (Minikube)
- ✅ **Fragmentación por documento_id** para escalabilidad
- ✅ **Dockerizado** para portabilidad
- ✅ **Tests automatizados**

---

## 🏗️ Arquitectura

```
┌─────────────────┐
│   Cliente Web   │
└────────┬────────┘
         │ HTTP/JWT
         ▼
┌─────────────────────────────────┐
│  Middleware (FastAPI)           │
│  - /token (autenticación)       │
│  - /paciente/{id}               │
│  - /pacientes                   │
└────────┬────────────────────────┘
         │ SQL
         ▼
┌─────────────────────────────────┐
│  Citus Coordinator              │
│  (PostgreSQL distribuido)       │
└────┬────────────────────────┬───┘
     │                        │
     ▼                        ▼
┌──────────┐            ┌──────────┐
│ Worker 1 │            │ Worker 2 │
└──────────┘            └──────────┘
```

### Componentes

- **FastAPI Middleware**: API REST con autenticación JWT
- **Citus Coordinator**: Nodo coordinador de la base de datos distribuida
- **Citus Workers**: Nodos trabajadores (2 réplicas)
- **Kubernetes**: Orquestación de contenedores
- **Docker**: Contenedorización de aplicaciones

---

## 📦 Requisitos

### Software necesario:

- **Minikube** v1.30+
- **kubectl** v1.28+
- **Docker** v20.10+
- **Python** 3.10+

### Recursos mínimos:

- CPU: 4 cores
- RAM: 4 GB
- Disco: 10 GB

---

## 🚀 Instalación

### Instalación Automática (Recomendada)

```bash
# 1. Clonar repositorio
git clone https://github.com/tu-usuario/Historia-Clinica-Distribuida.git
cd Historia-Clinica-Distribuida

# 2. Ejecutar script de instalación
chmod +x project/setup.sh
./project/setup.sh
```

El script automáticamente:
- ✅ Inicia Minikube
- ✅ Despliega Citus (coordinator + workers)
- ✅ Configura base de datos distribuida
- ✅ Construye y despliega el middleware
- ✅ Inserta datos de prueba

### Instalación Manual

<details>
<summary>Ver pasos manuales</summary>

```bash
# 1. Iniciar Minikube
minikube start --cpus=4 --memory=4096 --driver=docker

# 2. Crear namespace
kubectl create namespace citus

# 3. Desplegar Citus
kubectl apply -f project/citus-deployment.yaml

# 4. Esperar a que los pods estén listos
kubectl wait --for=condition=ready pod -l app=citus-coordinator -n citus --timeout=300s

# 5. Configurar base de datos
COORDINATOR_POD=$(kubectl get pod -n citus -l app=citus-coordinator -o jsonpath="{.items[0].metadata.name}")

kubectl exec -n citus $COORDINATOR_POD -- psql -U postgres -c "CREATE DATABASE historiaclinica;"
kubectl exec -n citus $COORDINATOR_POD -- psql -U postgres -d historiaclinica -c "CREATE EXTENSION IF NOT EXISTS citus;"

# 6. Crear tabla distribuida
kubectl exec -n citus $COORDINATOR_POD -- psql -U postgres -d historiaclinica <<EOF
CREATE TABLE public.pacientes (
    id SERIAL,
    documento_id VARCHAR(20) NOT NULL,
    nombre VARCHAR(100) NOT NULL,
    apellido VARCHAR(100),
    fecha_nacimiento DATE,
    telefono VARCHAR(20),
    direccion TEXT,
    correo VARCHAR(100),
    genero VARCHAR(10),
    tipo_sangre VARCHAR(5),
    fecha_registro TIMESTAMP DEFAULT NOW(),
    PRIMARY KEY (documento_id, id)
);

SELECT create_distributed_table('public.pacientes', 'documento_id');
EOF

# 7. Construir imagen Docker
cd project
docker build -t middleware-citus:1.0 .
minikube image load middleware-citus:1.0

# 8. Crear secrets
kubectl create secret generic app-secrets \
  --from-literal=POSTGRES_HOST=citus-coordinator \
  --from-literal=POSTGRES_PORT=5432 \
  --from-literal=POSTGRES_DB=historiaclinica \
  --from-literal=POSTGRES_USER=postgres \
  --from-literal=POSTGRES_PASSWORD=password \
  --from-literal=SECRET_KEY=20240902734 \
  -n citus

# 9. Desplegar middleware
kubectl apply -f infra/app-deployment.yaml
```

</details>

---

## 💻 Uso

### Acceder a la API

```bash
# 1. Port-forward
kubectl port-forward -n citus service/middleware-citus-service 8000:8000 &

# 2. Probar API
curl http://localhost:8000/health
```

### Obtener Token JWT

```bash
curl -X POST http://localhost:8000/token \
  -H "Content-Type: application/json" \
  -d '{"username":"admin","password":"admin"}'

# Respuesta:
# {
#   "access_token": "eyJhbGci...",
#   "token_type": "bearer"
# }
```

### Consultar Paciente

```bash
TOKEN="tu_token_aqui"

curl http://localhost:8000/paciente/1 \
  -H "Authorization: Bearer $TOKEN"

# Respuesta:
# {
#   "id": 1,
#   "documento_id": "12345",
#   "nombre": "Juan",
#   "apellido": "Pérez",
#   "fecha_nacimiento": "1995-04-12",
#   ...
# }
```

### Documentación Interactiva (Swagger)

Abre en tu navegador: http://localhost:8000/docs

---

## 📡 API Endpoints

### Públicos

| Método | Endpoint | Descripción |
|--------|----------|-------------|
| GET | `/` | Mensaje de bienvenida |
| GET | `/health` | Estado del sistema |
| POST | `/token` | Obtener token JWT |

### Protegidos (requieren JWT)

| Método | Endpoint | Descripción |
|--------|----------|-------------|
| GET | `/paciente/{id}` | Obtener paciente por ID |
| GET | `/pacientes?limit=10` | Listar pacientes |

### Ejemplo de Autenticación

```bash
# 1. Obtener token
TOKEN=$(curl -s -X POST http://localhost:8000/token \
  -H "Content-Type: application/json" \
  -d '{"username":"admin","password":"admin"}' \
  | jq -r '.access_token')

# 2. Usar token
curl http://localhost:8000/pacientes \
  -H "Authorization: Bearer $TOKEN"
```

---

## 🧪 Pruebas

### Ejecutar Tests Automatizados

```bash
chmod +x project/test_api.sh
./project/test_api.sh
```

### Tests Incluidos

- ✅ Disponibilidad de la API
- ✅ Health check
- ✅ Generación de JWT
- ✅ Protección de endpoints (401)
- ✅ Obtención de paciente con token
- ✅ Listado de pacientes
- ✅ Manejo de 404
- ✅ Rechazo de token inválido
- ✅ Rechazo de credenciales incorrectas

### Salida Esperada

```
========================================
  ✓ TODAS LAS PRUEBAS COMPLETADAS
========================================

Resumen:
  ✓ Health check funcional
  ✓ Autenticación JWT operativa
  ✓ Endpoints protegidos correctamente
  ✓ CRUD de pacientes funcional
  ✓ Manejo de errores apropiado

Sistema listo para Semana 2!
```

---

## 🛠️ Desarrollo

### Estructura del Proyecto

```
project/
├── app/
│   ├── main.py          # FastAPI app
│   ├── database.py      # Conexión BD
│   ├── auth.py          # JWT auth
│   ├── models.py        # Pydantic models
│   └── schemas.py       # Request/Response schemas
├── infra/
│   ├── app-deployment.yaml
│   ├── secrets.yaml
│   └── initdb/          # Scripts SQL
├── .env                 # Variables de entorno
├── Dockerfile           # Imagen Docker
├── requirements.txt     # Dependencias Python
├── setup.sh            # Script de instalación
└── test_api.sh         # Tests automatizados
```

### Variables de Entorno

```bash
# .env
POSTGRES_HOST=citus-coordinator
POSTGRES_PORT=5432
POSTGRES_DB=historiaclinica
POSTGRES_USER=postgres
POSTGRES_PASSWORD=password

SECRET_KEY=20240902734
ALGORITHM=HS256
ACCESS_TOKEN_EXPIRE_MINUTES=30
```

### Reconstruir Imagen

```bash
cd project
docker build -t middleware-citus:1.0 .
minikube image load middleware-citus:1.0

# Reiniciar deployment
kubectl rollout restart deployment/middleware-citus -n citus
```

---

## 🔧 Troubleshooting

### Problema: Pods no inician

```bash
# Ver estado de pods
kubectl get pods -n citus

# Ver logs
kubectl logs -n citus <pod-name>

# Describir pod
kubectl describe pod -n citus <pod-name>
```

### Problema: No se puede conectar a la API

```bash
# Verificar port-forward
ps aux | grep port-forward

# Reiniciar port-forward
pkill -f "port-forward.*8000"
kubectl port-forward -n citus service/middleware-citus-service 8000:8000 &
```

### Problema: Base de datos vacía

```bash
# Conectarse a la BD
kubectl exec -it -n citus <coordinator-pod> -- psql -U postgres -d historiaclinica

# Verificar tablas
\dt

# Verificar datos
SELECT * FROM public.pacientes;
```

### Reiniciar Todo

```bash
# Eliminar namespace
kubectl delete namespace citus

# Re-ejecutar setup
./project/setup.sh
```

---

## 👥 Equipo

- **Integrante A (Backend & DevSecOps)**: Infraestructura, Middleware, Base de datos
- **Integrante B (Frontend & UX)**: Interfaces, Diseño, Experiencia de usuario

---

## 📝 Licencia

Este proyecto es parte de un trabajo académico.

---

## 🎯 Estado del Proyecto

- [x] **Semana 1**: Infraestructura + Middleware base ✅
- [ ] **Semana 2**: Interfaces completas + Roles + PDF
- [ ] **Semana 3**: Documentación + Sustentación

---

## 📚 Referencias

- [Citus Documentation](https://docs.citusdata.com/)
- [FastAPI Documentation](https://fastapi.tiangolo.com/)
- [Kubernetes Documentation](https://kubernetes.io/docs/)
- [JWT.io](https://jwt.io/)
