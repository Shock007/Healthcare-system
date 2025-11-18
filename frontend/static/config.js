/**
 * config.js - Configuración Global del Frontend
 * Colocar en: frontend/static/js/config.js
 * 
 * Uso en los HTMLs:
 * <script src="../static/js/config.js"></script>
 */

// ==================== CONFIGURACIÓN DE LA API ====================
const API_CONFIG = {
    // 🔧 CAMBIAR SEGÚN TU ENTORNO:
    
    // Opción 1: Desarrollo local con kubectl port-forward
    // BASE_URL: 'http://localhost:8000',
    
    // Opción 2: Minikube con NodePort (IP de Minikube)
    //BASE_URL: 'http://192.168.49.2:30800',
    
    // Opción 3: Red local con IP de tu VM
     BASE_URL: 'http://181.51.89.56:30800',
    
    // Opción 4: Producción
    // BASE_URL: 'https://api.tudominio.com',
};

// ==================== UTILIDADES ====================
const API_UTILS = {
    /**
     * Obtiene el token almacenado
     */
    getToken() {
        return sessionStorage.getItem('token');
    },

    /**
     * Obtiene el usuario almacenado
     */
    getUser() {
        const user = sessionStorage.getItem('user');
        return user ? JSON.parse(user) : null;
    },

    /**
     * Verifica si el usuario está autenticado
     */
    isAuthenticated() {
        return !!this.getToken() && !!this.getUser();
    },

    /**
     * Cierra la sesión
     */
    logout() {
        sessionStorage.clear();
        window.location.href = 'login.html';
    },

    /**
     * Hace una petición autenticada a la API
     */
    async fetch(endpoint, options = {}) {
        const token = this.getToken();
        
        const defaultOptions = {
            headers: {
                'Content-Type': 'application/json',
                ...(token && { 'Authorization': `Bearer ${token}` }),
            },
        };

        const mergedOptions = {
            ...defaultOptions,
            ...options,
            headers: {
                ...defaultOptions.headers,
                ...options.headers,
            },
        };

        const url = `${API_CONFIG.BASE_URL}${endpoint}`;
        
        try {
            const response = await fetch(url, mergedOptions);
            
            // Si el token expiró (401), redirigir al login
            if (response.status === 401) {
                this.logout();
                return null;
            }
            
            return response;
        } catch (error) {
            console.error('Error en petición:', error);
            throw error;
        }
    },

    /**
     * Verifica permisos de rol
     */
    hasRole(roles) {
        const user = this.getUser();
        if (!user) return false;
        
        if (Array.isArray(roles)) {
            return roles.includes(user.rol);
        }
        
        return user.rol === roles;
    },

    /**
     * Redirige si no tiene el rol requerido
     */
    requireRole(roles, redirectUrl = 'login.html') {
        if (!this.hasRole(roles)) {
            alert('Acceso denegado');
            window.location.href = redirectUrl;
            return false;
        }
        return true;
    },

    /**
     * Formatea una fecha
     */
    formatDate(dateString) {
        if (!dateString) return 'N/A';
        const date = new Date(dateString);
        return date.toLocaleDateString('es-CO');
    },

    /**
     * Formatea una fecha y hora
     */
    formatDateTime(dateString) {
        if (!dateString) return 'N/A';
        const date = new Date(dateString);
        return date.toLocaleString('es-CO');
    },

    /**
     * Descarga un blob como archivo
     */
    downloadBlob(blob, filename) {
        const url = window.URL.createObjectURL(blob);
        const a = document.createElement('a');
        a.href = url;
        a.download = filename;
        document.body.appendChild(a);
        a.click();
        window.URL.revokeObjectURL(url);
        a.remove();
    },

    /**
     * Muestra un mensaje de alerta
     */
    showAlert(message, type = 'info') {
        // Crear alerta de Bootstrap
        const alertDiv = document.createElement('div');
        alertDiv.className = `alert alert-${type} alert-dismissible fade show`;
        alertDiv.setAttribute('role', 'alert');
        alertDiv.innerHTML = `
            ${message}
            <button type="button" class="btn-close" data-bs-dismiss="alert"></button>
        `;

        // Buscar o crear contenedor de alertas
        let container = document.getElementById('alertContainer');
        if (!container) {
            container = document.createElement('div');
            container.id = 'alertContainer';
            container.style.cssText = 'position: fixed; top: 20px; right: 20px; z-index: 9999; max-width: 400px;';
            document.body.appendChild(container);
        }

        container.appendChild(alertDiv);

        // Auto-eliminar después de 5 segundos
        setTimeout(() => {
            alertDiv.remove();
        }, 5000);
    }
};

// ==================== EXPORTAR ====================
// Para usar en otros archivos:
// const API_URL = API_CONFIG.BASE_URL;
// const { fetch, getUser, hasRole } = API_UTILS;

console.log('✅ Configuración global cargada');
console.log('📡 API URL:', API_CONFIG.BASE_URL);