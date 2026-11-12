"""
Servicio generador de Informes Técnicos Periciales de Inspección SST en PDF con ReportLab.
Estructurado rigurosamente según los requerimientos periciales colombianos y APA 7ma Edición:
1. Encabezado institucional y metadatos de auditoría.
2. Matriz de Hallazgos y Evaluación de Conformidad Normativa SST.
3. Registro Fotográfico Pericial de Evidencias (cada foto real exactamente una vez con su ficha técnica).
4. Dictamen pericial y firmas formales de responsabilidad.
"""
import io
import os
from pathlib import Path
from typing import Dict, Any, List
from datetime import datetime
from PIL import Image as PILImage

from reportlab.lib.pagesizes import letter
from reportlab.lib import colors
from reportlab.lib.units import inch
from reportlab.platypus import (
    SimpleDocTemplate, Paragraph, Spacer, Table, TableStyle, Image as RLImage, KeepTogether, HRFlowable
)
from reportlab.lib.styles import getSampleStyleSheet, ParagraphStyle
from reportlab.pdfgen import canvas

from app.config import UPLOADS_DIR, BASE_DIR
from app.models.catalogo_sst import CATEGORIAS_SST, CATALOGO_SENALES


class NumberedCanvas(canvas.Canvas):
    """Canvas dinámico de ReportLab que calcula y numera las páginas totales (Página X de Y)."""
    def __init__(self, *args, **kwargs):
        super().__init__(*args, **kwargs)
        self._saved_page_states = []

    def showPage(self):
        self._saved_page_states.append(dict(self.__dict__))
        self._startPage()

    def save(self):
        num_pages = len(self._saved_page_states)
        for state in self._saved_page_states:
            self.__dict__.update(state)
            self.draw_page_decorations(num_pages)
            super().showPage()
        super().save()

    def draw_page_decorations(self, page_count):
        self.saveState()
        self.setFont("Helvetica-Bold", 7.5)
        self.setFillColor(colors.HexColor("#475569"))
        
        # Encabezado institucional en páginas 2 en adelante
        if self._pageNumber > 1:
            self.drawString(36, 762, "Politécnico Grancolombiano | Auditoría Pericial SST: Condiciones, Señalización y Demarcación")
            self.drawRightString(576, 762, "NTC 1461 / NSR-10 / Res. 2400 / Dec. 1072")
            self.setStrokeColor(colors.HexColor("#cbd5e1"))
            self.setLineWidth(0.6)
            self.line(36, 756, 576, 756)

        # Pie de página institucional en todas las páginas
        self.setStrokeColor(colors.HexColor("#cbd5e1"))
        self.setLineWidth(0.6)
        self.line(36, 42, 576, 42)
        
        self.setFont("Helvetica", 7.5)
        self.setFillColor(colors.HexColor("#64748b"))
        texto_pie = f"Página {self._pageNumber} de {page_count} · Dictamen Oficial de Auditoría Técnica y Conformidad Legal SST"
        self.drawString(36, 28, texto_pie)
        self.drawRightString(576, 28, f"Sede Medellín · Sistema SST-IA · {datetime.now().strftime('%d/%m/%Y')}")
        self.restoreState()


class PDFService:
    def __init__(self):
        self.styles = getSampleStyleSheet()
        self._crear_estilos()

    def _crear_estilos(self):
        self.estilo_titulo = ParagraphStyle(
            'TituloSST',
            parent=self.styles['Heading1'],
            fontName='Helvetica-Bold',
            fontSize=13,
            leading=17,
            textColor=colors.HexColor('#0f172a'),
            alignment=0,
            spaceAfter=4
        )
        self.estilo_subtitulo_meta = ParagraphStyle(
            'SubtituloMetaSST',
            parent=self.styles['Normal'],
            fontName='Helvetica',
            fontSize=8,
            leading=11.5,
            textColor=colors.HexColor('#334155'),
            spaceAfter=6
        )
        self.estilo_seccion_num = ParagraphStyle(
            'SeccionNumSST',
            parent=self.styles['Heading2'],
            fontName='Helvetica-Bold',
            fontSize=10.5,
            leading=13.5,
            textColor=colors.HexColor('#1e3a8a'),
            spaceBefore=8,
            spaceAfter=4
        )
        self.estilo_parrafo = ParagraphStyle(
            'ParrafoSST',
            parent=self.styles['Normal'],
            fontName='Helvetica',
            fontSize=8,
            leading=11,
            textColor=colors.HexColor('#1e293b'),
            alignment=4,
            spaceAfter=4
        )
        self.estilo_celda = ParagraphStyle(
            'CeldaSST',
            parent=self.styles['Normal'],
            fontName='Helvetica',
            fontSize=7,
            leading=9,
            textColor=colors.HexColor('#1e293b')
        )
        self.estilo_celda_bold = ParagraphStyle(
            'CeldaBoldSST',
            parent=self.styles['Normal'],
            fontName='Helvetica-Bold',
            fontSize=7,
            leading=9,
            textColor=colors.HexColor('#0f172a')
        )
        self.estilo_celda_center = ParagraphStyle(
            'CeldaCenterSST',
            parent=self.styles['Normal'],
            fontName='Helvetica',
            fontSize=7,
            leading=9,
            alignment=1,
            textColor=colors.HexColor('#1e293b')
        )
        self.estilo_celda_th = ParagraphStyle(
            'CeldaThSST',
            parent=self.styles['Normal'],
            fontName='Helvetica-Bold',
            fontSize=7.2,
            leading=9.5,
            textColor=colors.HexColor('#ffffff'),
            alignment=1
        )
        self.estilo_apa_figura = ParagraphStyle(
            'ApaFiguraSST',
            parent=self.styles['Normal'],
            fontName='Helvetica-Bold',
            fontSize=8,
            leading=10.5,
            textColor=colors.HexColor('#0f172a'),
            spaceAfter=1
        )
        self.estilo_apa_titulo = ParagraphStyle(
            'ApaTituloSST',
            parent=self.styles['Normal'],
            fontName='Helvetica-Oblique',
            fontSize=7.5,
            leading=9.5,
            textColor=colors.HexColor('#1e3a8a'),
            spaceAfter=4
        )
        self.estilo_apa_nota = ParagraphStyle(
            'ApaNotaSST',
            parent=self.styles['Normal'],
            fontName='Helvetica',
            fontSize=6.8,
            leading=8.8,
            textColor=colors.HexColor('#475569'),
            spaceBefore=2,
            spaceAfter=6
        )
        self.estilo_ficha_label = ParagraphStyle(
            'FichaLabelSST',
            parent=self.styles['Normal'],
            fontName='Helvetica-Bold',
            fontSize=6.8,
            leading=8.8,
            textColor=colors.HexColor('#1e3a8a')
        )
        self.estilo_ficha_val = ParagraphStyle(
            'FichaValSST',
            parent=self.styles['Normal'],
            fontName='Helvetica',
            fontSize=6.8,
            leading=8.8,
            textColor=colors.HexColor('#0f172a')
        )

    def _resolver_ruta_foto(self, foto_path: str, foto_url: str = "") -> str:
        """Resuelve la ruta absoluta válida de la fotografía en el sistema local."""
        # 1. Verificar si la ruta directa existe
        if foto_path and os.path.exists(foto_path):
            return foto_path
        
        # 2. Buscar por nombre de archivo en UPLOADS_DIR
        if foto_path:
            nombre = Path(foto_path).name
            candidato = UPLOADS_DIR / nombre
            if candidato.exists():
                return str(candidato)
                
        # 3. Buscar por foto_url
        if foto_url:
            nombre_url = Path(foto_url).name
            candidato_url = UPLOADS_DIR / nombre_url
            if candidato_url.exists():
                return str(candidato_url)

        return ""

    def _crear_flowable_imagen(self, ruta_img: str, max_w: float = 210, max_h: float = 145):
        """Crea un objeto Image de ReportLab escalado proporcionalmente manteniendo el aspecto."""
        if not ruta_img or not os.path.exists(ruta_img):
            return Table(
                [[Paragraph("<i>[Fotografía capturada y archivada digitalmente]</i>", self.estilo_celda_center)]],
                colWidths=[max_w],
                style=[
                    ('BACKGROUND', (0,0), (-1,-1), colors.HexColor('#f1f5f9')),
                    ('BOX', (0,0), (-1,-1), 1, colors.HexColor('#cbd5e1')),
                    ('ALIGN', (0,0), (-1,-1), 'CENTER'),
                    ('VALIGN', (0,0), (-1,-1), 'MIDDLE'),
                    ('TOPPADDING', (0,0), (-1,-1), 35),
                    ('BOTTOMPADDING', (0,0), (-1,-1), 35),
                ]
            )

        try:
            with PILImage.open(ruta_img) as im:
                orig_w, orig_h = im.size
                if orig_w <= 0 or orig_h <= 0:
                    raise ValueError("Dimensiones inválidas")
                ratio = min(max_w / orig_w, max_h / orig_h)
                dest_w = orig_w * ratio
                dest_h = orig_h * ratio
                
                rl_img = RLImage(ruta_img, width=dest_w, height=dest_h)
                return Table([[rl_img]], colWidths=[max_w], style=[
                    ('ALIGN', (0,0), (-1,-1), 'CENTER'),
                    ('VALIGN', (0,0), (-1,-1), 'MIDDLE'),
                    ('LEFTPADDING', (0,0), (-1,-1), 0),
                    ('RIGHTPADDING', (0,0), (-1,-1), 0),
                    ('TOPPADDING', (0,0), (-1,-1), 0),
                    ('BOTTOMPADDING', (0,0), (-1,-1), 0),
                ])
        except Exception:
            return Paragraph("<i>[Error al procesar formato de imagen]</i>", self.estilo_celda_center)

    def generar_pdf_inspeccion(self, inspeccion: Dict[str, Any]) -> bytes:
        """
        Genera el informe técnico pericial enfocado en:
        1. Encabezado y datos de inspección.
        2. Matriz de hallazgos y evaluación de riesgos.
        3. Registro fotográfico pericial (cada foto real una sola vez).
        4. Dictamen pericial y firmas.
        """
        buffer = io.BytesIO()
        doc = SimpleDocTemplate(
            buffer,
            pagesize=letter,
            leftMargin=36,
            rightMargin=36,
            topMargin=36,
            bottomMargin=50
        )
        
        story = []
        
        # =================================================================
        # ENCABEZADO INSTITUCIONAL Y METADATOS
        # =================================================================
        story.append(Paragraph(
            "Informe Técnico Pericial de Inspección SST: Registro Fotográfico y Matriz de Hallazgos",
            self.estilo_titulo
        ))
        
        responsable = inspeccion.get("responsable", "Yair Alexander Córdoba Palomeque")
        if not responsable or responsable.strip() in ["Auditor SST", "YO", ""]:
            responsable = "Yair Alexander Córdoba Palomeque"
            
        sede = inspeccion.get("sede", "Politécnico Grancolombiano, Sede Medellín")
        if "Politécnico" not in sede:
            institucion_txt = f"Politécnico Grancolombiano · {sede}"
        else:
            institucion_txt = sede

        fecha_txt = inspeccion.get("fecha", datetime.now().strftime("%Y-%m-%d %H:%M"))
        numero_insp = inspeccion.get("numero", "#0001")
        area_txt = inspeccion.get("area", "Área de Laboratorios y Pasillos")
        edificio_txt = inspeccion.get("edificio", "Campus Principal")

        evidencias = inspeccion.get("evidencias", [])
        total_evidencias = len(evidencias)
        
        # Contabilizar hallazgos
        total_hallazgos = 0
        conformes = 0
        no_conformes = 0
        pendientes = 0
        
        for ev in evidencias:
            for h in ev.get("hallazgos", []):
                total_hallazgos += 1
                cond = (h.get("condicion") or "").lower()
                st = (h.get("estado") or "").lower()
                if "conforme" in cond and "no" not in cond:
                    conformes += 1
                elif "no conforme" in cond or "critico" in cond or "subestandar" in cond:
                    no_conformes += 1
                else:
                    pendientes += 1

        meta_parrafo = (
            f"<b>Institución:</b> {institucion_txt} &nbsp;|&nbsp; <b>Edificio:</b> {edificio_txt} &nbsp;|&nbsp; <b>Área:</b> {area_txt}<br/>"
            f"<b>Expediente Correlativo:</b> <b>{numero_insp}</b> &nbsp;|&nbsp; <b>Fecha de Recorrido:</b> {fecha_txt} &nbsp;|&nbsp; <b>Auditor Líder SST:</b> {responsable}<br/>"
            f"<b>Balance Pericial:</b> {total_evidencias} Evidencias Registradas &nbsp;|&nbsp; "
            f"{total_hallazgos} Hallazgos Evaluados ({conformes} Conformes, {no_conformes} No conformes, {pendientes} En verificación)"
        )
        story.append(Paragraph(meta_parrafo, self.estilo_subtitulo_meta))
        story.append(HRFlowable(width="100%", thickness=1.5, color=colors.HexColor("#1e3a8a"), spaceAfter=8))

        # =================================================================
        # SECCIÓN 1: MATRIZ DE EVALUACIÓN DE HALLAZGOS Y RIESGOS SST
        # =================================================================
        story.append(Paragraph("1. Matriz de Hallazgos y Evaluación de Conformidad SST", self.estilo_seccion_num))
        story.append(Paragraph(
            "La siguiente matriz consolida los hallazgos técnicos registrados durante la inspección pericial en sitio, "
            "evaluados bajo el marco legal y normas técnicas aplicables (NTC 1461, Res. 2400/79, NSR-10 Títulos J/K y Dec. 1072/15):",
            self.estilo_parrafo
        ))

        # Ancho total = 540 pt
        tabla_filas = [
            [
                Paragraph("<b>#</b>", self.estilo_celda_th),
                Paragraph("<b>Elemento / Señal SST</b>", self.estilo_celda_th),
                Paragraph("<b>Ubicación</b>", self.estilo_celda_th),
                Paragraph("<b>Condición</b>", self.estilo_celda_th),
                Paragraph("<b>Norma Aplicable</b>", self.estilo_celda_th),
                Paragraph("<b>Nivel Riesgo</b>", self.estilo_celda_th),
                Paragraph("<b>Acción / Recomendación</b>", self.estilo_celda_th),
            ]
        ]

        contador_item = 1
        for ev in evidencias:
            ubic = ev.get("ubicacion") or area_txt or "Área inspeccionada"
            obs = ev.get("observacion") or ""
            
            for h in ev.get("hallazgos", []):
                elem = h.get("elemento") or "Elemento de Seguridad y Salud"
                cond = h.get("condicion") or "Requiere verificación"
                norma = h.get("norma") or "NTC 1461 / NSR-10 / Res. 2400/79"
                rec = h.get("recomendacion") or obs or "Verificar y mantener conforme al estándar normativo."
                
                # Determinar color de condición y nivel de riesgo
                cond_lower = cond.lower()
                if "no conforme" in cond_lower or "riesgo" in cond_lower or "critico" in cond_lower:
                    color_cond = "#dc2626"
                    nivel_txt = "ALTO"
                    color_nivel = "#dc2626"
                elif "conforme" in cond_lower:
                    color_cond = "#16a34a"
                    nivel_txt = "BAJO"
                    color_nivel = "#16a34a"
                else:
                    color_cond = "#d97706"
                    nivel_txt = "MEDIO"
                    color_nivel = "#d97706"

                p_num = Paragraph(f"<b>{contador_item:02d}</b>", self.estilo_celda_center)
                p_elem = Paragraph(f"<b>{elem}</b>", self.estilo_celda_bold)
                p_ubic = Paragraph(ubic, self.estilo_celda)
                p_cond = Paragraph(f"<font color='{color_cond}'><b>{cond}</b></font>", self.estilo_celda)
                p_norma = Paragraph(norma, self.estilo_celda)
                p_nivel = Paragraph(f"<font color='{color_nivel}'><b>{nivel_txt}</b></font>", self.estilo_celda_center)
                p_rec = Paragraph(rec, self.estilo_celda)

                tabla_filas.append([p_num, p_elem, p_ubic, p_cond, p_norma, p_nivel, p_rec])
                contador_item += 1

        if len(tabla_filas) == 1:
            # Si no hay hallazgos detallados, agregar fila informativa
            tabla_filas.append([
                Paragraph("-", self.estilo_celda_center),
                Paragraph("Sin hallazgos registrados", self.estilo_celda_bold),
                Paragraph(area_txt, self.estilo_celda),
                Paragraph("<font color='#16a34a'><b>Conforme</b></font>", self.estilo_celda),
                Paragraph("NTC 1461 / Res. 2400", self.estilo_celda),
                Paragraph("<font color='#16a34a'><b>BAJO</b></font>", self.estilo_celda_center),
                Paragraph("Recorrido inicial sin anomalías críticas detectadas.", self.estilo_celda)
            ])

        t_matriz = Table(tabla_filas, colWidths=[24, 110, 80, 76, 85, 45, 120])
        t_matriz.setStyle(TableStyle([
            ('BACKGROUND', (0,0), (-1,0), colors.HexColor('#0f2444')),
            ('ALIGN', (0,0), (-1,0), 'CENTER'),
            ('VALIGN', (0,0), (-1,-1), 'TOP'),
            ('BOX', (0,0), (-1,-1), 1, colors.HexColor('#94a3b8')),
            ('INNERGRID', (0,0), (-1,-1), 0.5, colors.HexColor('#cbd5e1')),
            ('ROWBACKGROUNDS', (0,1), (-1,-1), [colors.HexColor('#ffffff'), colors.HexColor('#f8fafc')]),
            ('TOPPADDING', (0,0), (-1,-1), 2.5),
            ('BOTTOMPADDING', (0,0), (-1,-1), 2.5),
            ('LEFTPADDING', (0,0), (-1,-1), 3),
            ('RIGHTPADDING', (0,0), (-1,-1), 3),
        ]))
        story.append(t_matriz)
        story.append(Spacer(1, 10))

        # =================================================================
        # SECCIÓN 2: REGISTRO FOTOGRÁFICO PERICIAL (CADA FOTO UNA SOLA VEZ)
        # =================================================================
        story.append(Paragraph("2. Registro Fotográfico Pericial de Evidencias (Estándar APA 7ma Edición)", self.estilo_seccion_num))
        story.append(Paragraph(
            "A continuación, se documenta el soporte fotográfico pericial capturado durante el recorrido. "
            "Cada figura representa una evidencia física individual debidamente rotulada con su dictamen técnico normativo:",
            self.estilo_parrafo
        ))

        if total_evidencias == 0:
            story.append(Paragraph(
                "<i>No se han adjuntado evidencias fotográficas para este expediente de inspección.</i>",
                self.estilo_celda
            ))
        else:
            for idx, ev in enumerate(evidencias, 1):
                ruta_foto = self._resolver_ruta_foto(ev.get("foto_path", ""), ev.get("foto_url", ""))
                ubicacion_ev = ev.get("ubicacion") or area_txt or "Área inspeccionada"
                observacion_ev = ev.get("observacion") or "Sin observaciones adicionales registradas por el auditor."
                fecha_ev = ev.get("fecha") or fecha_txt
                
                # Datos del hallazgo asociado
                hallazgos_ev = ev.get("hallazgos", [])
                if hallazgos_ev:
                    h = hallazgos_ev[0]
                    elemento_ev = h.get("elemento") or "Señal / Elemento SST"
                    condicion_ev = h.get("condicion") or "Evaluado"
                    categoria_ev = h.get("categoria") or "General"
                    norma_ev = h.get("norma") or "NTC 1461 / NSR-10 / Res. 2400"
                    recomendacion_ev = h.get("recomendacion") or "Cumplir parámetros reglamentarios."
                    color_seg = h.get("color_seguridad") or "Reglamentario"
                    forma_geom = h.get("forma_geometrica") or "Normalizada NTC 1461"
                    altura_mont = h.get("altura_montaje") or "1.60m - 1.80m al centro de la señal"
                else:
                    elemento_ev = ev.get("tipo_esperado") or "Evidencia Fotográfica"
                    condicion_ev = "En evaluación"
                    categoria_ev = "General"
                    norma_ev = "NTC 1461 / Res. 2400 de 1979"
                    recomendacion_ev = observacion_ev
                    color_seg = "Reglamentario"
                    forma_geom = "Normalizada"
                    altura_mont = "Cotas estándar NTC 1461"

                # Flowable de la foto
                flowable_img = self._crear_flowable_imagen(ruta_foto, max_w=200, max_h=140)

                # Ficha descriptiva a la derecha
                cond_color = "#16a34a" if "conforme" in condicion_ev.lower() and "no" not in condicion_ev.lower() else "#dc2626"
                
                tabla_ficha_datos = [
                    [Paragraph("<b>Ítem / Elemento:</b>", self.estilo_ficha_label), Paragraph(f"<b>{elemento_ev}</b>", self.estilo_ficha_val)],
                    [Paragraph("<b>Ubicación:</b>", self.estilo_ficha_label), Paragraph(ubicacion_ev, self.estilo_ficha_val)],
                    [Paragraph("<b>Condición:</b>", self.estilo_ficha_label), Paragraph(f"<font color='{cond_color}'><b>{condicion_ev}</b></font> ({categoria_ev})", self.estilo_ficha_val)],
                    [Paragraph("<b>Observación:</b>", self.estilo_ficha_label), Paragraph(observacion_ev, self.estilo_ficha_val)],
                    [Paragraph("<b>Norma Técnica:</b>", self.estilo_ficha_label), Paragraph(norma_ev, self.estilo_ficha_val)],
                    [Paragraph("<b>Cromática y Cotas:</b>", self.estilo_ficha_label), Paragraph(f"{color_seg} · {forma_geom} · {altura_mont}", self.estilo_ficha_val)],
                    [Paragraph("<b>Recomendación:</b>", self.estilo_ficha_label), Paragraph(recomendacion_ev, self.estilo_ficha_val)],
                ]
                
                t_ficha = Table(tabla_ficha_datos, colWidths=[80, 240])
                t_ficha.setStyle(TableStyle([
                    ('VALIGN', (0,0), (-1,-1), 'TOP'),
                    ('TOPPADDING', (0,0), (-1,-1), 1),
                    ('BOTTOMPADDING', (0,0), (-1,-1), 1),
                    ('LEFTPADDING', (0,0), (-1,-1), 2),
                    ('RIGHTPADDING', (0,0), (-1,-1), 2),
                ]))

                # Tarjeta contenedora de dos columnas (Foto izquierda 210 pt | Ficha derecha 330 pt) = 540 pt
                t_tarjeta = Table(
                    [[flowable_img, t_ficha]],
                    colWidths=[205, 335],
                    style=[
                        ('BACKGROUND', (0,0), (-1,-1), colors.HexColor('#ffffff')),
                        ('BOX', (0,0), (-1,-1), 0.8, colors.HexColor('#cbd5e1')),
                        ('ALIGN', (0,0), (0,0), 'CENTER'),
                        ('VALIGN', (0,0), (-1,-1), 'MIDDLE'),
                        ('TOPPADDING', (0,0), (-1,-1), 4),
                        ('BOTTOMPADDING', (0,0), (-1,-1), 4),
                        ('LEFTPADDING', (0,0), (-1,-1), 4),
                        ('RIGHTPADDING', (0,0), (-1,-1), 4),
                    ]
                )

                bloque_evidencia = []
                bloque_evidencia.append(Paragraph(f"<b>Figura {idx}</b>", self.estilo_apa_figura))
                bloque_evidencia.append(Paragraph(f"<i>Registro pericial de {elemento_ev} en {ubicacion_ev}</i>", self.estilo_apa_titulo))
                bloque_evidencia.append(t_tarjeta)
                bloque_evidencia.append(Paragraph(
                    f"<i>Nota.</i> Fotografía capturada durante la auditoría el {fecha_ev}. Dictamen: {condicion_ev}. Conforme a {norma_ev}.",
                    self.estilo_apa_nota
                ))
                bloque_evidencia.append(Spacer(1, 5))
                
                story.append(KeepTogether(bloque_evidencia))

        # =================================================================
        # SECCIÓN 3: DICTAMEN PERICIAL Y FIRMAS DE RESPONSABILIDAD
        # =================================================================
        story.append(Spacer(1, 6))
        conclusiones_bloque = []
        conclusiones_bloque.append(Paragraph("3. Dictamen de Auditoría Pericial y Certificación", self.estilo_seccion_num))
        
        texto_dictamen = (
            f"El suscrito auditor técnico certifica que la presente inspección correspondiente al expediente <b>{numero_insp}</b> "
            f"fue ejecutada in situ con estricto apego a las disposiciones legales colombianas del SG-SST (Decreto 1072 de 2015, "
            f"Resolución 2400 de 1979, NSR-10 y NTC 1461). Las {total_evidencias} evidencias fotográficas documentadas reflejan "
            f"fidedignamente el estado físico y operativo de las instalaciones auditadas.<br/><br/>"
            f"Se dictamina dar trámite prioritario a las acciones correctivas señaladas en la Matriz de Hallazgos, "
            f"garantizando la señalización fotoluminiscente Clase A, el despeje reglamentario de extintores y las rutas de evacuación seguras."
        )
        conclusiones_bloque.append(Paragraph(texto_dictamen, self.estilo_parrafo))
        conclusiones_bloque.append(Spacer(1, 20))

        # Firmas periciales
        conclusiones_bloque.append(Table([
            [
                Paragraph(
                    "____________________________________________________<br/>"
                    f"<b>{responsable}</b><br/>"
                    "Auditor Líder / Especialista SST<br/>"
                    "Licencia en Seguridad y Salud en el Trabajo Vigente<br/>"
                    f"{institucion_txt}",
                    self.estilo_celda
                ),
                Paragraph(
                    "____________________________________________________<br/>"
                    "<b>Dirección Administrativa y Financiera / Rectoría</b><br/>"
                    "Representante Legal / Gerencia del SG-SST<br/>"
                    f"{institucion_txt}",
                    self.estilo_celda
                )
            ]
        ], colWidths=[270, 270], style=[
            ('ALIGN', (0,0), (-1,-1), 'CENTER'),
            ('VALIGN', (0,0), (-1,-1), 'TOP')
        ]))

        story.append(KeepTogether(conclusiones_bloque))

        doc.build(story, canvasmaker=NumberedCanvas)
        return buffer.getvalue()


pdf_service = PDFService()
