"""
Servicio de persistencia local en JSON para inspecciones y hallazgos SST.
Mantiene el estado reactivo similar a AppState en la arquitectura Flutter.
"""
import json
import threading
from typing import List, Optional, Dict, Any
from app.config import DB_FILE
from app.models.inspeccion import Inspeccion, Evidencia, Hallazgo

_lock = threading.Lock()

class DatabaseService:
    def __init__(self):
        self._inicializar()

    def _inicializar(self):
        with _lock:
            if not DB_FILE.exists():
                with open(DB_FILE, "w", encoding="utf-8") as f:
                    json.dump([], f, indent=2, ensure_ascii=False)

    def _leer_todos(self) -> List[Dict[str, Any]]:
        with _lock:
            if not DB_FILE.exists():
                return []
            try:
                with open(DB_FILE, "r", encoding="utf-8") as f:
                    return json.load(f)
            except Exception:
                return []

    def _escribir_todos(self, items: List[Dict[str, Any]]):
        with _lock:
            with open(DB_FILE, "w", encoding="utf-8") as f:
                json.dump(items, f, indent=2, ensure_ascii=False)

    def listar_inspecciones(self) -> List[Dict[str, Any]]:
        """Retorna todas las inspecciones ordenadas de la más reciente a la más antigua."""
        items = self._leer_todos()
        # Enriquecer con conteos computados para el dashboard
        for item in items:
            total_h = 0
            validados = 0
            pendientes = 0
            rechazados = 0
            for ev in item.get("evidencias", []):
                for h in ev.get("hallazgos", []):
                    total_h += 1
                    st = h.get("estado", "pendiente")
                    if st == "validado":
                        validados += 1
                    elif st == "pendiente":
                        pendientes += 1
                    elif st == "rechazado":
                        rechazados += 1
            item["total_hallazgos"] = total_h
            item["validados_count"] = validados
            item["pendientes_count"] = pendientes
            item["rechazados_count"] = rechazados
        return items

    def obtener_inspeccion(self, inspeccion_id: str) -> Optional[Dict[str, Any]]:
        items = self._leer_todos()
        for item in items:
            if item.get("id") == inspeccion_id:
                return item
        return None

    def obtener_activa(self) -> Optional[Dict[str, Any]]:
        items = self._leer_todos()
        for item in items:
            if item.get("estado") == "enCurso":
                return item
        return None

    def crear_inspeccion(self, sede: str, edificio: str, area: str, responsable: str) -> Dict[str, Any]:
        items = self._leer_todos()
        # Finalizar cualquier inspección anterior que estuviese en curso
        for item in items:
            if item.get("estado") == "enCurso":
                item["estado"] = "finalizada"
        numero = f"#{len(items) + 1:04d}"
        nueva = Inspeccion(
            numero=numero,
            sede=sede.strip(),
            edificio=edificio.strip(),
            area=area.strip(),
            responsable=responsable.strip(),
            estado="enCurso",
            evidencias=[]
        )
        data = nueva.model_dump()
        items.insert(0, data) # insertar al principio como única activa
        self._escribir_todos(items)
        return data

    def finalizar_inspeccion(self, inspeccion_id: str) -> Optional[Dict[str, Any]]:
        items = self._leer_todos()
        for item in items:
            if item.get("id") == inspeccion_id:
                item["estado"] = "finalizada"
                self._escribir_todos(items)
                return item
        return None

    def agregar_evidencia(self, inspeccion_id: str, evidencia_dict: Dict[str, Any]) -> Optional[Dict[str, Any]]:
        items = self._leer_todos()
        for item in items:
            if item.get("id") == inspeccion_id:
                if "evidencias" not in item:
                    item["evidencias"] = []
                item["evidencias"].append(evidencia_dict)
                self._escribir_todos(items)
                return item
        return None

    def actualizar_hallazgo(self, hallazgo_id: str, actualizacion: Dict[str, Any]) -> Optional[Dict[str, Any]]:
        items = self._leer_todos()
        modificado = False
        hallazgo_actualizado = None
        
        for item in items:
            for ev in item.get("evidencias", []):
                for h in ev.get("hallazgos", []):
                    if h.get("id") == hallazgo_id:
                        h.update(actualizacion)
                        hallazgo_actualizado = h
                        modificado = True
                        break
                if modificado:
                    break
            if modificado:
                break
                
        if modificado:
            self._escribir_todos(items)
            return hallazgo_actualizado
        return None

    def eliminar_evidencia(self, inspeccion_id: str, evidencia_id: str) -> bool:
        """Elimina una evidencia fotográfica / seguimiento de la inspección."""
        items = self._leer_todos()
        for item in items:
            if item.get("id") == inspeccion_id:
                evidencias = item.get("evidencias", [])
                longitud_inicial = len(evidencias)
                item["evidencias"] = [ev for ev in evidencias if ev.get("id") != evidencia_id]
                if len(item["evidencias"]) < longitud_inicial:
                    self._escribir_todos(items)
                    return True
        return False

    def eliminar_hallazgo(self, hallazgo_id: str) -> bool:
        """Elimina un hallazgo específico buscando a través de todas las inspecciones."""
        items = self._leer_todos()
        encontrado = False
        for item in items:
            for ev in item.get("evidencias", []):
                hallazgos = ev.get("hallazgos", [])
                long_ini = len(hallazgos)
                ev["hallazgos"] = [h for h in hallazgos if h.get("id") != hallazgo_id]
                if len(ev["hallazgos"]) < long_ini:
                    encontrado = True
                    break
            if encontrado:
                break
        if encontrado:
            self._escribir_todos(items)
            return True
        return False

    def eliminar_inspeccion(self, inspeccion_id: str) -> bool:
        """Elimina una inspección completa y todo su historial."""
        items = self._leer_todos()
        long_ini = len(items)
        items = [i for i in items if i.get("id") != inspeccion_id]
        if len(items) < long_ini:
            self._escribir_todos(items)
            return True
        return False

db_service = DatabaseService()
