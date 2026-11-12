"""
Módulo de compatibilidad y alias para el servicio de reporte fotográfico.
Redirige directamente al servicio oficial centralizado: app/services/pdf_service.py
"""
from app.services.pdf_service import (
    pdf_service as reporte_fotografico_service,
    PDFService as ReporteFotograficoService,
    pdf_service
)

# Alias de conveniencia y compatibilidad directa para la función generadora
generar_pdf = getattr(pdf_service, "generar_pdf_inspeccion", None)

__all__ = [
    "reporte_fotografico_service",
    "ReporteFotograficoService",
    "pdf_service",
    "generar_pdf"
]
