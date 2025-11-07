# project/app/fhir_client.py
"""Cliente FHIR para HAPI FHIR Server"""
import os
import requests
from typing import Optional, Dict, Any, List
from dotenv import load_dotenv
from fastapi import HTTPException

load_dotenv(override=False)

FHIR_SERVER_URL = os.getenv("FHIR_SERVER_URL", "http://hapi.fhir.org/baseR4")
FHIR_TIMEOUT = int(os.getenv("FHIR_TIMEOUT", 30))


class FHIRClient:
    def __init__(self):
        self.base_url = FHIR_SERVER_URL.rstrip('/')
        self.timeout = FHIR_TIMEOUT
        self.headers = {
            'Content-Type': 'application/fhir+json',
            'Accept': 'application/fhir+json'
        }

    def test_connection(self) -> Dict[str, Any]:
        """Prueba conexión con servidor FHIR"""
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
        """Convierte paciente local a FHIR Patient"""
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

        if paciente.get("telefono"):
            fhir_patient["telecom"].append({
                "system": "phone",
                "value": paciente.get("telefono"),
                "use": "mobile"
            })

        if paciente.get("correo"):
            fhir_patient["telecom"].append({
                "system": "email",
                "value": paciente.get("correo"),
                "use": "home"
            })

        if paciente.get("direccion"):
            fhir_patient["address"] = [{
                "use": "home",
                "text": paciente.get("direccion"),
                "type": "physical"
            }]

        return fhir_patient

    def create_patient(self, paciente: Dict[str, Any]) -> Dict[str, Any]:
        """Crea paciente en servidor FHIR"""
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

    def _map_gender(self, genero: Optional[str]) -> str:
        """Mapea género local a FHIR"""
        gender_map = {
            "M": "male",
            "F": "female",
            "O": "other",
            None: "unknown"
        }
        return gender_map.get(genero, "unknown")


# Instancia global
fhir_client = FHIRClient()


def get_fhir_client() -> FHIRClient:
    return fhir_client
