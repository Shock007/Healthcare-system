# project/app/fhir_client.py
"""
Cliente FHIR para interactuar con HAPI FHIR Server
Maneja la conversión de datos entre el modelo local y FHIR
"""
import os
import requests
from typing import Optional, Dict, Any, List
from datetime import datetime
from dotenv import load_dotenv
from fastapi import HTTPException

load_dotenv(override=False)

FHIR_SERVER_URL = os.getenv("FHIR_SERVER_URL", "http://hapi.fhir.org/baseR4")
FHIR_TIMEOUT = int(os.getenv("FHIR_TIMEOUT", 30))


class FHIRClient:
    """Cliente para interactuar con servidor HAPI FHIR"""

    def __init__(self):
        self.base_url = FHIR_SERVER_URL.rstrip('/')
        self.timeout = FHIR_TIMEOUT
        self.headers = {
            'Content-Type': 'application/fhir+json',
            'Accept': 'application/fhir+json'
        }

    def test_connection(self) -> Dict[str, Any]:
        """Prueba la conexión con el servidor FHIR"""
        try:
            response = requests.get(
                f"{self.base_url}/metadata",
                headers=self.headers,
                timeout=self.timeout
            )
            response.raise_for_status()
            return {
                "status": "connected",
                "server": self.base_url,
                "fhir_version": response.json().get("fhirVersion", "unknown")
            }
        except requests.exceptions.RequestException as e:
            return {
                "status": "error",
                "server": self.base_url,
                "error": str(e)
            }

    def paciente_to_fhir(self, paciente: Dict[str, Any]) -> Dict[str, Any]:
        """
        Convierte un paciente del modelo local a formato FHIR Patient

        Args:
            paciente: Diccionario con datos del paciente local

        Returns:
            Recurso FHIR Patient
        """
        fhir_patient = {
            "resourceType": "Patient",
            "identifier": [{
                "use": "official",
                "system": "http://hospital.example.org/identifiers/patient",
                "value": paciente.get("documento_id")
            }],
            "active": True,
            "name": [{
                "use": "official",
                "family": paciente.get("apellido", ""),
                "given": [paciente.get("nombre", "")]
            }],
            "telecom": [],
            "gender": self._map_gender(paciente.get("genero")),
            "birthDate": paciente.get("fecha_nacimiento")
        }

        # Agregar teléfono si existe
        if paciente.get("telefono"):
            fhir_patient["telecom"].append({
                "system": "phone",
                "value": paciente.get("telefono"),
                "use": "mobile"
            })

        # Agregar email si existe
        if paciente.get("correo"):
            fhir_patient["telecom"].append({
                "system": "email",
                "value": paciente.get("correo"),
                "use": "home"
            })

        # Agregar dirección si existe
        if paciente.get("direccion"):
            fhir_patient["address"] = [{
                "use": "home",
                "text": paciente.get("direccion"),
                "type": "physical"
            }]

        return fhir_patient

    def fhir_to_paciente(self, fhir_patient: Dict[str, Any]) -> Dict[str, Any]:
        """
        Convierte un recurso FHIR Patient al modelo local

        Args:
            fhir_patient: Recurso FHIR Patient

        Returns:
            Diccionario con datos del paciente en formato local
        """
        paciente = {}

        # Extraer identificador
        if fhir_patient.get("identifier"):
            paciente["documento_id"] = fhir_patient["identifier"][0].get("value")

        # Extraer nombre
        if fhir_patient.get("name"):
            name = fhir_patient["name"][0]
            paciente["apellido"] = name.get("family", "")
            paciente["nombre"] = name.get("given", [""])[0] if name.get("given") else ""

        # Extraer fecha de nacimiento
        paciente["fecha_nacimiento"] = fhir_patient.get("birthDate")

        # Extraer género
        paciente["genero"] = self._map_gender_from_fhir(fhir_patient.get("gender"))

        # Extraer telecomunicaciones
        if fhir_patient.get("telecom"):
            for telecom in fhir_patient["telecom"]:
                if telecom.get("system") == "phone":
                    paciente["telefono"] = telecom.get("value")
                elif telecom.get("system") == "email":
                    paciente["correo"] = telecom.get("value")

        # Extraer dirección
        if fhir_patient.get("address"):
            paciente["direccion"] = fhir_patient["address"][0].get("text", "")

        # Agregar ID de FHIR si existe
        if fhir_patient.get("id"):
            paciente["fhir_id"] = fhir_patient["id"]

        return paciente

    def create_patient(self, paciente: Dict[str, Any]) -> Dict[str, Any]:
        """
        Crea un paciente en el servidor FHIR

        Args:
            paciente: Datos del paciente en formato local

        Returns:
            Respuesta del servidor con el recurso creado
        """
        try:
            fhir_patient = self.paciente_to_fhir(paciente)

            response = requests.post(
                f"{self.base_url}/Patient",
                json=fhir_patient,
                headers=self.headers,
                timeout=self.timeout
            )
            response.raise_for_status()

            return {
                "success": True,
                "fhir_id": response.json().get("id"),
                "data": response.json()
            }
        except requests.exceptions.RequestException as e:
            raise HTTPException(
                status_code=500,
                detail=f"Error al crear paciente en FHIR: {str(e)}"
            )

    def get_patient(self, fhir_id: str) -> Dict[str, Any]:
        """
        Obtiene un paciente del servidor FHIR por su ID

        Args:
            fhir_id: ID del paciente en FHIR

        Returns:
            Recurso FHIR Patient
        """
        try:
            response = requests.get(
                f"{self.base_url}/Patient/{fhir_id}",
                headers=self.headers,
                timeout=self.timeout
            )
            response.raise_for_status()
            return response.json()
        except requests.exceptions.HTTPError as e:
            if e.response.status_code == 404:
                raise HTTPException(
                    status_code=404,
                    detail=f"Paciente FHIR {fhir_id} no encontrado"
                )
            raise HTTPException(
                status_code=500,
                detail=f"Error al obtener paciente de FHIR: {str(e)}"
            )
        except requests.exceptions.RequestException as e:
            raise HTTPException(
                status_code=500,
                detail=f"Error de conexión con FHIR: {str(e)}"
            )

    def update_patient(self, fhir_id: str, paciente: Dict[str, Any]) -> Dict[str, Any]:
        """
        Actualiza un paciente en el servidor FHIR

        Args:
            fhir_id: ID del paciente en FHIR
            paciente: Datos actualizados del paciente

        Returns:
            Respuesta del servidor con el recurso actualizado
        """
        try:
            fhir_patient = self.paciente_to_fhir(paciente)
            fhir_patient["id"] = fhir_id

            response = requests.put(
                f"{self.base_url}/Patient/{fhir_id}",
                json=fhir_patient,
                headers=self.headers,
                timeout=self.timeout
            )
            response.raise_for_status()

            return {
                "success": True,
                "data": response.json()
            }
        except requests.exceptions.RequestException as e:
            raise HTTPException(
                status_code=500,
                detail=f"Error al actualizar paciente en FHIR: {str(e)}"
            )

    def search_patients(self, **params) -> List[Dict[str, Any]]:
        """
        Busca pacientes en el servidor FHIR

        Args:
            **params: Parámetros de búsqueda FHIR (name, family, identifier, etc.)

        Returns:
            Lista de recursos FHIR Patient
        """
        try:
            response = requests.get(
                f"{self.base_url}/Patient",
                params=params,
                headers=self.headers,
                timeout=self.timeout
            )
            response.raise_for_status()

            bundle = response.json()
            patients = []

            if bundle.get("entry"):
                for entry in bundle["entry"]:
                    if entry.get("resource"):
                        patients.append(entry["resource"])

            return patients
        except requests.exceptions.RequestException as e:
            raise HTTPException(
                status_code=500,
                detail=f"Error al buscar pacientes en FHIR: {str(e)}"
            )

    def _map_gender(self, genero: Optional[str]) -> str:
        """Mapea género del modelo local a FHIR"""
        gender_map = {
            "M": "male",
            "F": "female",
            "O": "other",
            None: "unknown"
        }
        return gender_map.get(genero, "unknown")

    def _map_gender_from_fhir(self, fhir_gender: Optional[str]) -> str:
        """Mapea género de FHIR al modelo local"""
        gender_map = {
            "male": "M",
            "female": "F",
            "other": "O",
            "unknown": None
        }
        return gender_map.get(fhir_gender, None)


# Instancia global del cliente FHIR
fhir_client = FHIRClient()


def get_fhir_client() -> FHIRClient:
    """Retorna la instancia del cliente FHIR"""
    return fhir_client
