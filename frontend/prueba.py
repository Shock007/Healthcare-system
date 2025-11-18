"""
prueba.py - OPCIÓN A: Servidor Simple de Archivos Estáticos
============================================================

Esta opción sirve los archivos HTML directamente sin procesamiento backend.
Todo el procesamiento se hace en el navegador con JavaScript llamando a FastAPI.

VENTAJAS:
- Simple y ligero
- Sin lógica de backend en Flask
- Todo el estado en el navegador (sessionStorage)

DESVENTAJAS:
- No hay server-side rendering (SSR)
- No hay sessions del servidor

USO:
python prueba.py
Luego abrir: http://localhost:5000
"""

from flask import Flask, send_from_directory, redirect
import os

app = Flask(__name__)

# Rutas base
BASE_DIR = os.path.dirname(os.path.abspath(__file__))
TEMPLATES_DIR = os.path.join(BASE_DIR, 'templates')
STATIC_DIR = os.path.join(BASE_DIR, 'static')

# ==================== CONFIGURACIÓN ====================
app.config['TEMPLATES_AUTO_RELOAD'] = True

# ==================== RUTAS ====================

@app.route('/')
def index():
    """Redirige al login"""
    return redirect('/login.html')

@app.route('/<path:filename>')
def serve_template(filename):
    """
    Sirve cualquier archivo HTML desde templates/
    Ejemplos:
    - /login.html
    - /medico.html
    - /registrar_paciente.html
    """
    if filename.endswith('.html'):
        return send_from_directory(TEMPLATES_DIR, filename)
    else:
        return "Archivo no encontrado", 404

@app.route('/static/<path:filename>')
def serve_static(filename):
    """
    Sirve archivos estáticos (CSS, JS, imágenes)
    Ejemplo: /static/js/config.js
    """
    return send_from_directory(STATIC_DIR, filename)

@app.route('/templates/<path:filename>')
def serve_template_alt(filename):
    """
    Ruta alternativa para templates
    Por si algún HTML hace referencia a /templates/
    """
    return send_from_directory(TEMPLATES_DIR, filename)

# ==================== MANEJO DE ERRORES ====================

@app.errorhandler(404)
def not_found(error):
    return """
    <html>
    <head>
        <title>404 - No Encontrado</title>
        <style>
            body { font-family: Arial; text-align: center; padding: 50px; }
            h1 { color: #e74c3c; }
        </style>
    </head>
    <body>
        <h1>404 - Página no encontrada</h1>
        <p>El archivo que buscas no existe.</p>
        <a href="/">Volver al inicio</a>
    </body>
    </html>
    """, 404

# ==================== INFORMACIÓN DE INICIO ====================


def show_info():
    """Muestra información al iniciar el servidor"""
    print("\n" + "="*60)
    print("🏥 SERVIDOR DE FRONTEND - HISTORIA CLÍNICA ELECTRÓNICA")
    print("="*60)
    print("\n📂 Directorios configurados:")
    print(f"   Templates: {TEMPLATES_DIR}")
    print(f"   Static: {STATIC_DIR}")
    print("\n🌐 URLs disponibles:")
    print("   - http://localhost:5000/")
    print("   - http://localhost:5000/login.html")
    print("   - http://localhost:5000/medico.html")
    print("   - http://localhost:5000/static/js/config.js")
    print("\n⚙️  Configuración del Backend API:")
    print("   - Editar en: static/js/config.js")
    print("   - Variable: API_CONFIG.BASE_URL")
    print("\n✅ Servidor listo. Presiona Ctrl+C para detener.")
    print("="*60 + "\n")

# ==================== INICIAR SERVIDOR ====================

if __name__ == '__main__':
    # Verificar que existen los directorios
    if not os.path.exists(TEMPLATES_DIR):
        print(f"❌ ERROR: No se encuentra el directorio {TEMPLATES_DIR}")
        exit(1)
    
    if not os.path.exists(STATIC_DIR):
        print(f"⚠️  ADVERTENCIA: No se encuentra {STATIC_DIR}")
        print("   Creando directorio...")
        os.makedirs(STATIC_DIR, exist_ok=True)
        os.makedirs(os.path.join(STATIC_DIR, 'js'), exist_ok=True)
        os.makedirs(os.path.join(STATIC_DIR, 'css'), exist_ok=True)
        os.makedirs(os.path.join(STATIC_DIR, 'img'), exist_ok=True)
    
    # Iniciar servidor
    show_info()
    app.run(
        host='0.0.0.0',  # Accesible desde toda la red local
        port=5000,
        debug=True,
        use_reloader=True
    )