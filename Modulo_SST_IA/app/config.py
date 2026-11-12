"""
Configuraciones globales de la aplicación SST-IA.
"""
import os
from pathlib import Path

BASE_DIR = Path(__file__).resolve().parent.parent

# Rutas de almacenamiento
DATA_DIR = BASE_DIR / "data"
UPLOADS_DIR = BASE_DIR / "app" / "static" / "uploads"
MODELS_DIR = BASE_DIR / "models"
DATASETS_DIR = DATA_DIR / "datasets"
DB_FILE = DATA_DIR / "inspecciones.json"
SETTINGS_FILE = DATA_DIR / "settings.json"

# Crear directorios si no existen
for d in [DATA_DIR, UPLOADS_DIR, MODELS_DIR, DATASETS_DIR]:
    d.mkdir(parents=True, exist_ok=True)

# Configuración IA
DEFAULT_YOLO_MODEL = MODELS_DIR / "sst_best.pt"
FALLBACK_YOLO_MODEL = MODELS_DIR / "yolov8n.pt"
CONFIDENCE_THRESHOLD = 0.35

# Roboflow Serverless Workflow
ROBOFLOW_API_KEY = "wFNVbgBUcGbkOi1gz6iJ"
ROBOFLOW_WORKSPACE = "yair-cordoba"
ROBOFLOW_WORKFLOW_URL = "https://serverless.roboflow.com/yair-cordoba/workflows/prohibido-celular"
ROBOFLOW_PROJECT_ID = "prohibido-celular"

# Servidor
HOST = os.getenv("HOST", "0.0.0.0")
PORT = int(os.getenv("PORT", 5000))
DEBUG = os.getenv("DEBUG", "True").lower() == "true"

