"""
Modelos de dominio para el Sistema de Inspecciones de Seguridad y Salud en el Trabajo (SST-IA).
Representa entidades inmutables y esquemas de validación de datos.
"""
from typing import List, Optional, Dict, Any
from pydantic import BaseModel, Field
import uuid
from datetime import datetime

class Hallazgo(BaseModel):
    id: str = Field(default_factory=lambda: str(uuid.uuid4()))
    elemento: str
    categoria: str = "Amarillas" # Rojas, Amarillas, Azules, Verdes
    condicion: str = "Requiere verificación"
    confianza: float = 0.85
    estado: str = "pendiente" # validado, pendiente, rechazado
    recomendacion: Optional[str] = ""
    bbox: Optional[List[float]] = None # [x1, y1, x2, y2]
    clase_detectada: Optional[str] = None
    fecha_registro: str = Field(default_factory=lambda: datetime.now().strftime("%Y-%m-%d %H:%M:%S"))
    norma: Optional[str] = ""
    color_seguridad: Optional[str] = ""
    color_contraste: Optional[str] = ""
    forma_geometrica: Optional[str] = ""
    cobertura_min_color: Optional[str] = ""
    tamano_recomendado: Optional[str] = ""
    altura_montaje: Optional[str] = ""
    checklist_sst: Optional[List[str]] = None
    foto_anotada_base64: Optional[str] = None

class Evidencia(BaseModel):
    id: str = Field(default_factory=lambda: str(uuid.uuid4()))
    foto_path: str
    foto_url: Optional[str] = None
    foto_base64: Optional[str] = None
    observacion: str = ""
    ubicacion: str = ""
    tipo_esperado: Optional[str] = "General"
    fecha: str = Field(default_factory=lambda: datetime.now().strftime("%Y-%m-%d %H:%M:%S"))
    hallazgos: List[Hallazgo] = Field(default_factory=list)

class Inspeccion(BaseModel):
    id: str = Field(default_factory=lambda: str(uuid.uuid4()))
    numero: str = "#0001"
    fecha: str = Field(default_factory=lambda: datetime.now().strftime("%Y-%m-%d %H:%M"))
    sede: str = "Sede Principal"
    edificio: str = "Edificio Central"
    area: str = "Operaciones"
    responsable: str = "Auditor SST"
    estado: str = "enCurso" # enCurso, finalizada
    evidencias: List[Evidencia] = Field(default_factory=list)

    @property
    def todos_hallazgos(self) -> List[Hallazgo]:
        todos = []
        for ev in self.evidencias:
            todos.extend(ev.hallazgos)
        return todos

    @property
    def hallazgos_validados(self) -> List[Hallazgo]:
        return [h for h in self.todos_hallazgos if h.estado == "validado"]

    @property
    def hallazgos_pendientes(self) -> List[Hallazgo]:
        return [h for h in self.todos_hallazgos if h.estado == "pendiente"]

    @property
    def hallazgos_rechazados(self) -> List[Hallazgo]:
        return [h for h in self.todos_hallazgos if h.estado == "rechazado"]

    @property
    def porcentaje_cumplimiento(self) -> float:
        validados = self.hallazgos_validados
        if not validados:
            return 100.0 if not self.todos_hallazgos else 0.0
        conformes = sum(1 for h in validados if "conforme" in h.condicion.lower())
        return round((conformes / len(validados)) * 100, 1)

# Esquemas de entrada para peticiones API
class CrearInspeccionRequest(BaseModel):
    sede: str
    edificio: str
    area: str
    responsable: str

class AnalizarRequest(BaseModel):
    foto_base64: str
    observacion: Optional[str] = ""
    ubicacion: Optional[str] = ""
    tipo_esperado: Optional[str] = ""

class ActualizarHallazgoRequest(BaseModel):
    elemento: str
    categoria: str
    condicion: str
    recomendacion: Optional[str] = ""
    estado: str # validado, pendiente, rechazado
    norma: Optional[str] = ""
    color_seguridad: Optional[str] = ""
    color_contraste: Optional[str] = ""
    forma_geometrica: Optional[str] = ""
    tamano_recomendado: Optional[str] = ""
    altura_montaje: Optional[str] = ""
