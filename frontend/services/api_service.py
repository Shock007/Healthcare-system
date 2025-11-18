import requests
import json
from config import Config
from flask import session

class APIService:
    def __init__(self):
        self.base_url = Config.API_BASE_URL
        self.timeout = Config.API_TIMEOUT
    
    def _get_headers(self):
        """Retorna headers con token JWT si existe"""
        headers = {"Content-Type": "application/json"}
        if "token" in session:
            headers["Authorization"] = f"Bearer {session['token']}"
        return headers
    
    def _make_request(self, method, endpoint, data=None, params=None):
        """Realiza petición HTTP genérica"""
        url = f"{self.base_url}{endpoint}"
        headers = self._get_headers()
        
        try:
            if method == "GET":
                response = requests.get(url, headers=headers, params=params, timeout=self.timeout)
            elif method == "POST":
                response = requests.post(url, headers=headers, json=data, timeout=self.timeout)
            elif method == "PUT":
                response = requests.put(url, headers=headers, json=data, timeout=self.timeout)
            elif method == "DELETE":
                response = requests.delete(url, headers=headers, timeout=self.timeout)
            
            response.raise_for_status()
            return response.json() if response.text else None
            
        except requests.exceptions.Timeout:
            return {"error": "Timeout - API no responde"}
        except requests.exceptions.ConnectionError:
            return {"error": "No se pudo conectar con el servidor"}
        except requests.exceptions.HTTPError as e:
            return {"error": f"Error HTTP {e.response.status_code}: {e.response.text}"}
    
    # ==================== AUTENTICACIÓN ====================
    
    def login(self, username, password):
        """Autentica usuario y retorna token"""
        data = {"username": username, "password": password}
        return self._make_request("POST", Config.ENDPOINTS["login"], data=data)
    
    def get_current_user(self):
        """Obtiene info del usuario actual"""
        return self._make_request("GET", Config.ENDPOINTS["me"])
    
    # ==================== PACIENTES ====================
    
    def listar_pacientes(self, limit=20, offset=0):
        """Lista todos los pacientes"""
        params = {"limit": limit, "offset": offset}
        return self._make_request("GET", Config.ENDPOINTS["pacientes"], params=params)
    
    def obtener_paciente(self, numero_documento):
        """Obtiene paciente por número de documento"""
        endpoint = Config.ENDPOINTS["paciente_por_doc"].format(numero_documento=numero_documento)
        return self._make_request("GET", endpoint)
    
    def crear_paciente(self, datos):
        """Crea nuevo paciente"""
        return self._make_request("POST", Config.ENDPOINTS["crear_paciente"], data=datos)
    
    def actualizar_paciente(self, numero_documento, datos):
        """Actualiza paciente existente"""
        endpoint = Config.ENDPOINTS["actualizar_paciente"].format(numero_documento=numero_documento)
        return self._make_request("PUT", endpoint, data=datos)
    
    def buscar_pacientes(self, nombre=None, documento=None):
        """Busca pacientes"""
        params = {}
        if nombre:
            params["nombre"] = nombre
        if documento:
            params["documento"] = documento
        return self._make_request("GET", Config.ENDPOINTS["buscar_pacientes"], params=params)
    
    def exportar_pdf(self, numero_documento):
        """Exporta historia clínica a PDF"""
        endpoint = Config.ENDPOINTS["exportar_pdf"].format(numero_documento=numero_documento)
        # Este endpoint retorna archivo, se debe manejar diferente
        headers = self._get_headers()
        url = f"{self.base_url}{endpoint}"
        try:
            response = requests.get(url, headers=headers, timeout=self.timeout)
            response.raise_for_status()
            return response.content  # Retorna bytes del PDF
        except Exception as e:
            return None
    
    # ==================== USUARIOS ====================
    
    def listar_usuarios(self, limit=50):
        """Lista usuarios (solo admin)"""
        params = {"limit": limit}
        return self._make_request("GET", Config.ENDPOINTS["usuarios"], params=params)
    
    def crear_usuario(self, datos):
        """Crea nuevo usuario (solo admin)"""
        return self._make_request("POST", Config.ENDPOINTS["usuarios"], data=datos)
    
    # ==================== SALUD ====================
    
    def health_check(self):
        """Verifica estado del servidor"""
        return self._make_request("GET", Config.ENDPOINTS["health"])

# Instancia global
api = APIService()