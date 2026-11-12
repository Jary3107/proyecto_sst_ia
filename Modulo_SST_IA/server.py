"""
Servidor Principal SST-IA (FastAPI + Uvicorn).
Provee:
1. Endpoint REST /analizar compatible con la app Flutter en puerto 5000.
2. API completa para el ciclo de vida de inspecciones SST y gobernanza de IA.
3. Generación y descarga directa de Informes PDF para auditorías.
4. Interfaz Web interactiva moderna para realizar inspecciones desde navegador.
"""
import os
import uuid
import base64
from pathlib import Path
from typing import Optional, Dict, Any, List

from fastapi import FastAPI, UploadFile, File, Form, HTTPException, Response
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles
from fastapi.responses import HTMLResponse, StreamingResponse, JSONResponse
from pydantic import BaseModel

from app.config import UPLOADS_DIR, BASE_DIR
from app.models.inspeccion import (
    CrearInspeccionRequest, AnalizarRequest, ActualizarHallazgoRequest,
    Inspeccion, Evidencia, Hallazgo
)
from app.models.catalogo_sst import CATEGORIAS_SST, CATALOGO_SENALES
from app.services.database import db_service
from app.services.detector_ia import detector_ia_service
from app.services.pdf_service import pdf_service
from app.services.dataset_service import dataset_service

app = FastAPI(
    title="SST-IA Backend & Web App",
    description="Sistema de Inteligencia Artificial para Inspecciones de Seguridad y Salud en el Trabajo",
    version="2.0.0"
)

# Habilitar CORS amplio para permitir conexiones desde Flutter (Mobile, Desktop, Web)
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Montar archivos estáticos
app.mount("/static", StaticFiles(directory=str(BASE_DIR / "app" / "static")), name="static")

@app.get("/api/categorias")
def obtener_categorias():
    return {"categorias": CATEGORIAS_SST}

@app.get("/api/catalogo_normas")
def obtener_catalogo_normas():
    return {
        "categorias": CATEGORIAS_SST,
        "catalogo": CATALOGO_SENALES
    }

# -------------------------------------------------------------
# 1. ENDPOINT REST /analizar (COMPATIBLE DIRECTO CON FLUTTER)
# -------------------------------------------------------------
@app.post("/analizar")
async def analizar_flutter(req: AnalizarRequest):
    """
    Endpoint consumido directamente por ServicioAnalisisIAService en la app Flutter:
    Recibe foto_base64, observacion y ubicacion.
    Devuelve elemento, categoria, condicion, confianza y recomendacion.
    """
    try:
        resultado = detector_ia_service.analizar(
            foto_base64=req.foto_base64,
            observacion=req.observacion or "",
            ubicacion=req.ubicacion or "",
            tipo_esperado=req.tipo_esperado or ""
        )
        return resultado
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Error durante el análisis SST: {str(e)}")

# -------------------------------------------------------------
# 2. GESTIÓN DE INSPECCIONES
# -------------------------------------------------------------
@app.get("/api/inspecciones")
def listar_inspecciones():
    return db_service.listar_inspecciones()

@app.get("/api/inspecciones/activa")
def obtener_inspeccion_activa():
    activa = db_service.obtener_activa()
    return activa or {"mensaje": "No hay ninguna inspección en curso activa"}

@app.get("/api/inspecciones/{inspeccion_id}")
def detalle_inspeccion(inspeccion_id: str):
    inspeccion = db_service.obtener_inspeccion(inspeccion_id)
    if not inspeccion:
        raise HTTPException(status_code=404, detail="Inspección no encontrada")
    return inspeccion

@app.post("/api/inspecciones")
def crear_inspeccion(req: CrearInspeccionRequest):
    return db_service.crear_inspeccion(
        sede=req.sede,
        edificio=req.edificio,
        area=req.area,
        responsable=req.responsable
    )

@app.post("/api/inspecciones/{inspeccion_id}/finalizar")
def finalizar_inspeccion(inspeccion_id: str):
    inspeccion = db_service.finalizar_inspeccion(inspeccion_id)
    if not inspeccion:
        raise HTTPException(status_code=404, detail="Inspección no encontrada")
    return {"mensaje": "Inspección finalizada exitosamente", "inspeccion": inspeccion}

# -------------------------------------------------------------
# 3. REGISTRO DE EVIDENCIAS Y ANÁLISIS INTEGRADO
# -------------------------------------------------------------
class RegistroEvidenciaPayload(BaseModel):
    foto_base64: str
    observacion: str = ""
    ubicacion: str = ""
    tipo_esperado: str = "General"

@app.post("/api/inspecciones/{inspeccion_id}/evidencias")
def registrar_evidencia_con_analisis(inspeccion_id: str, payload: RegistroEvidenciaPayload):
    inspeccion = db_service.obtener_inspeccion(inspeccion_id)
    if not inspeccion:
        raise HTTPException(status_code=404, detail="Inspección no encontrada")

    # Guardar archivo de imagen en static/uploads
    filename = f"evidencia_{uuid.uuid4().hex[:10]}.jpg"
    foto_path = UPLOADS_DIR / filename
    
    try:
        b64_clean = payload.foto_base64.split(",", 1)[-1]
        with open(foto_path, "wb") as f:
            f.write(base64.b64decode(b64_clean))
    except Exception as e:
        raise HTTPException(status_code=400, detail=f"Imagen inválida: {e}")

    # Ejecutar análisis con IA
    analisis = detector_ia_service.analizar(
        foto_base64=payload.foto_base64,
        foto_path=str(foto_path),
        observacion=payload.observacion,
        ubicacion=payload.ubicacion,
        tipo_esperado=payload.tipo_esperado
    )

    # Crear hallazgo preliminar con especificaciones normativas
    hallazgo = Hallazgo(
        elemento=analisis["elemento"],
        categoria=analisis["categoria"],
        condicion=analisis["condicion"],
        confianza=analisis["confianza"],
        estado="pendiente",
        recomendacion=analisis["recomendacion"],
        bbox=analisis.get("bbox"),
        norma=analisis.get("norma", ""),
        color_seguridad=analisis.get("color_seguridad", ""),
        color_contraste=analisis.get("color_contraste", ""),
        forma_geometrica=analisis.get("forma_geometrica", ""),
        cobertura_min_color=analisis.get("cobertura_min_color", ""),
        tamano_recomendado=analisis.get("tamano_recomendado", ""),
        altura_montaje=analisis.get("altura_montaje", ""),
        checklist_sst=analisis.get("checklist_sst"),
        foto_anotada_base64=analisis.get("foto_anotada_base64")
    )

    # Crear evidencia
    evidencia = Evidencia(
        foto_path=str(foto_path),
        foto_url=f"/static/uploads/{filename}",
        foto_base64=payload.foto_base64,
        observacion=payload.observacion,
        ubicacion=payload.ubicacion,
        tipo_esperado=payload.tipo_esperado,
        hallazgos=[hallazgo]
    )

    db_service.agregar_evidencia(inspeccion_id, evidencia.model_dump())

    return {
        "evidencia": evidencia.model_dump(),
        "hallazgo": hallazgo.model_dump(),
        "analisis_completo": analisis
    }

@app.delete("/api/inspecciones/{inspeccion_id}/evidencias/{evidencia_id}")
@app.post("/api/inspecciones/{inspeccion_id}/evidencias/{evidencia_id}/eliminar")
def eliminar_evidencia(inspeccion_id: str, evidencia_id: str):
    exito = db_service.eliminar_evidencia(inspeccion_id, evidencia_id)
    if not exito:
        raise HTTPException(status_code=404, detail="Evidencia no encontrada o ya eliminada")
    return {"mensaje": "Evidencia eliminada correctamente"}

@app.delete("/api/inspecciones/{inspeccion_id}")
@app.post("/api/inspecciones/{inspeccion_id}/eliminar")
def eliminar_inspeccion(inspeccion_id: str):
    exito = db_service.eliminar_inspeccion(inspeccion_id)
    if not exito:
        raise HTTPException(status_code=404, detail="Inspección no encontrada")
    return {"mensaje": "Inspección eliminada correctamente"}

# -------------------------------------------------------------
# 4. GOBERNANZA ÉTICA: VALIDACIÓN HUMANA DEL HALLAZGO
# -------------------------------------------------------------
@app.put("/api/hallazgos/{hallazgo_id}")
def actualizar_hallazgo(hallazgo_id: str, req: ActualizarHallazgoRequest):
    actualizado = db_service.actualizar_hallazgo(hallazgo_id, req.model_dump())
    if not actualizado:
        raise HTTPException(status_code=404, detail="Hallazgo no encontrado")
    return {"mensaje": "Hallazgo actualizado correctamente", "hallazgo": actualizado}

@app.delete("/api/hallazgos/{hallazgo_id}")
@app.post("/api/hallazgos/{hallazgo_id}/eliminar")
def eliminar_hallazgo(hallazgo_id: str):
    exito = db_service.eliminar_hallazgo(hallazgo_id)
    if not exito:
        raise HTTPException(status_code=404, detail="Hallazgo no encontrado")
    return {"mensaje": "Hallazgo eliminado correctamente"}

# -------------------------------------------------------------
# 5. GENERACIÓN Y DESCARGA DE INFORMES EN PDF
# -------------------------------------------------------------
@app.get("/api/inspecciones/{inspeccion_id}/informe.pdf")
def descargar_informe_pdf(inspeccion_id: str):
    if inspeccion_id == "activa":
        inspeccion = db_service.obtener_activa()
    else:
        inspeccion = db_service.obtener_inspeccion(inspeccion_id)

    if not inspeccion:
        raise HTTPException(status_code=404, detail="Inspección no encontrada")

    pdf_bytes = pdf_service.generar_pdf_inspeccion(inspeccion)
    nombre_archivo = f"Informe_SST_{inspeccion.get('numero', '0001').replace('#', '')}.pdf"
    
    return Response(
        content=pdf_bytes,
        media_type="application/pdf",
        headers={
            "Content-Disposition": f"attachment; filename={nombre_archivo}",
            "Content-Type": "application/pdf"
        }
    )

@app.post("/api/informes/generar_pdf")
def generar_informe_pdf_directo(payload: Dict[str, Any]):
    """Genera el informe pericial en PDF a partir de los datos recibidos de la app Flutter."""
    try:
        pdf_bytes = pdf_service.generar_pdf_inspeccion(payload)
        numero = str(payload.get('numero', '0001')).replace('#', '')
        nombre_archivo = f"Informe_SST_{numero}.pdf"
        return Response(
            content=pdf_bytes,
            media_type="application/pdf",
            headers={
                "Content-Disposition": f"attachment; filename={nombre_archivo}",
                "Content-Type": "application/pdf"
            }
        )
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Error generando informe PDF: {str(e)}")

# -------------------------------------------------------------
# 6. IMPORTACIÓN DE DATASET MEDIANTE cURL Y REENTRENAMIENTO
# -------------------------------------------------------------
class CurlImportPayload(BaseModel):
    curl_command: str
    nombre_dataset: Optional[str] = "dataset_sst_roboflow"

@app.post("/api/datasets/importar_curl")
def importar_dataset_curl(payload: CurlImportPayload):
    try:
        resultado = dataset_service.procesar_curl(
            payload.curl_command, 
            nombre_dataset=payload.nombre_dataset or "dataset_sst_roboflow"
        )
        return resultado
    except Exception as e:
        raise HTTPException(status_code=400, detail=str(e))

class EntrenarPayload(BaseModel):
    data_yaml_path: str
    epochs: Optional[int] = 25

@app.post("/api/datasets/entrenar")
def entrenar_modelo(payload: EntrenarPayload):
    return dataset_service.entrenar_modelo_async(
        data_yaml_path=payload.data_yaml_path,
        epochs=payload.epochs or 25
    )

@app.get("/api/datasets/estado")
def estado_entrenamiento():
    return dataset_service.estado_entrenamiento

# -------------------------------------------------------------
# 7. METADATOS Y CATÁLOGO
# -------------------------------------------------------------
@app.get("/api/categorias")
def obtener_categorias():
    return {
        "categorias": CATEGORIAS_SST,
        "catalogo_senales": CATALOGO_SENALES
    }

@app.get("/api/health")
def health_check():
    return {
        "estado": "operativo",
        "modelo_cargado": detector_ia_service.modelo_path or "No cargado (modo simulado)",
        "version": "2.0.0"
    }

# -------------------------------------------------------------
# 8. VISTA WEB SPA PRINCIPAL
# -------------------------------------------------------------
@app.get("/", response_class=HTMLResponse)
def index_page():
    template_path = BASE_DIR / "app" / "templates" / "index.html"
    if template_path.exists():
        with open(template_path, "r", encoding="utf-8") as f:
            return f.read()
    return "<h1>SST-IA Backend Operativo</h1><p>Visita /docs para la documentación interactiva Swagger.</p>"

if __name__ == "__main__":
    import uvicorn
    from app.config import HOST, PORT
    print(f"\n=========================================================")
    print(f"INICIANDO SERVIDOR SST-IA EN http://localhost:{PORT}")
    print(f"Endpoint REST Flutter: http://localhost:{PORT}/analizar")
    print(f"Interfaz Web de Inspecciones: http://localhost:{PORT}")
    print(f"Documentacion Swagger: http://localhost:{PORT}/docs")
    print(f"=========================================================\n")
    uvicorn.run("server:app", host=HOST, port=PORT, reload=False)
