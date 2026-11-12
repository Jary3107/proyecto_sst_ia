import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../models/hallazgo.dart';
import '../models/inspeccion.dart';
import '../utils/constants.dart';

/// Servicio de generación de Informes Técnicos Periciales de Inspección SST.
/// Conecta con el motor ReportLab de Modulo_SST_IA y posee generador de respaldo local en Dart.
class PdfService {
  static String get backendGenerarPdfUrl {
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      return 'http://10.0.2.2:5000/api/informes/generar_pdf';
    }
    return 'http://127.0.0.1:5000/api/informes/generar_pdf';
  }

  static String get backendPdfUrl {
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      return 'http://10.0.2.2:5000/api/inspecciones/activa/informe.pdf';
    }
    return 'http://127.0.0.1:5000/api/inspecciones/activa/informe.pdf';
  }

  Future<Uint8List> generar(Inspeccion i) async {
    // 1. Intentar enviar la inspección actual con fotos al motor ReportLab de Modulo_SST_IA
    try {
      debugPrint('[SST-IA] Solicitando PDF oficial a Modulo_SST_IA: $backendGenerarPdfUrl');
      final resp = await http
          .post(
            Uri.parse(backendGenerarPdfUrl),
            headers: {'Content-Type': 'application/json; charset=utf-8'},
            body: jsonEncode(i.toMap()),
          )
          .timeout(const Duration(seconds: 15));

      if (resp.statusCode == 200 && resp.bodyBytes.isNotEmpty) {
        debugPrint('[SST-IA] PDF pericial recibido con éxito del backend ReportLab (${resp.bodyBytes.length} bytes).');
        return resp.bodyBytes;
      }
    } catch (e) {
      debugPrint('[SST-IA] POST a backend no disponible ($e). Intentando GET...');
    }

    // 1.1 Si falló el POST, intentar GET a la inspección activa
    try {
      final respGet = await http.get(Uri.parse(backendPdfUrl)).timeout(const Duration(seconds: 8));
      if (respGet.statusCode == 200 && respGet.bodyBytes.isNotEmpty) {
        return respGet.bodyBytes;
      }
    } catch (_) {}

    // 2. Generación local de alta fidelidad con la librería pdf de Dart (Fallback 100% offline con fotos reales)
    return _generarLocal(i);
  }

  Future<Uint8List> _generarLocal(Inspeccion i) async {
    final doc = pw.Document();
    final lista = i.validados;

    // Precargar todas las imágenes de forma asíncrona (compatible con Web, Android y PC)
    final Map<String, Uint8List> fotosCargadas = {};
    for (final h in lista) {
      final key = '${h.elemento}_${h.fecha.millisecondsSinceEpoch}';

      // Prioridad 1: Foto anotada en Base64
      if (h.fotoAnotadaBase64 != null && h.fotoAnotadaBase64!.isNotEmpty) {
        try {
          final clean = (h.fotoAnotadaBase64!.contains(',')
                  ? h.fotoAnotadaBase64!.split(',').last
                  : h.fotoAnotadaBase64!)
              .replaceAll(RegExp(r'\s+'), '');
          fotosCargadas[key] = base64Decode(clean);
          continue;
        } catch (_) {}
      }

      // Prioridad 2: Archivo XFile local o Web Blob
      if (h.fotoPath != null && h.fotoPath!.isNotEmpty) {
        try {
          final bytes = await XFile(h.fotoPath!).readAsBytes();
          if (bytes.isNotEmpty) {
            fotosCargadas[key] = bytes;
            continue;
          }
        } catch (_) {}
      }
    }

    pw.Widget fila(String k, String v) => pw.Padding(
          padding: const pw.EdgeInsets.only(bottom: 3),
          child: pw.RichText(
            text: pw.TextSpan(children: [
              pw.TextSpan(text: '$k: ', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
              pw.TextSpan(text: v, style: const pw.TextStyle(fontSize: 10)),
            ]),
          ),
        );

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        header: (_) => pw.Container(
          padding: const pw.EdgeInsets.only(bottom: 6),
          margin: const pw.EdgeInsets.only(bottom: 12),
          decoration: const pw.BoxDecoration(
            border: pw.Border(bottom: pw.BorderSide(color: PdfColors.blue900, width: 1.5)),
          ),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text('Politécnico Grancolombiano · Auditoría Técnica y Pericial SST',
                  style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: PdfColors.blue900)),
              pw.Text('NTC 1461 / NSR-10 / Res. 2400 / Dec. 1072',
                  style: const pw.TextStyle(fontSize: 8.5, color: PdfColors.grey700)),
            ],
          ),
        ),
        footer: (ctx) => pw.Container(
          padding: const pw.EdgeInsets.only(top: 8),
          decoration: const pw.BoxDecoration(
            border: pw.Border(top: pw.BorderSide(color: PdfColors.grey400, width: 0.5)),
          ),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text('Sistema SST-IA · Informe Pericial Automatizado con Detección IA',
                  style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700)),
              pw.Text('Página ${ctx.pageNumber} de ${ctx.pagesCount}',
                  style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: PdfColors.blue900)),
            ],
          ),
        ),
        build: (_) => [
          // Título Principal
          pw.Container(
            padding: const pw.EdgeInsets.symmetric(vertical: 8, horizontal: 12),
            decoration: pw.BoxDecoration(
              color: PdfColors.blue900,
              borderRadius: pw.BorderRadius.circular(6),
            ),
            child: pw.Center(
              child: pw.Text(
                'INFORME TÉCNICO PERICIAL DE INSPECCIÓN Y REGISTRO FOTOGRÁFICO SST',
                textAlign: pw.TextAlign.center,
                style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: PdfColors.white),
              ),
            ),
          ),
          pw.SizedBox(height: 14),

          // Metadatos de la Inspección
          pw.Container(
            padding: const pw.EdgeInsets.all(10),
            decoration: pw.BoxDecoration(
              color: PdfColors.grey100,
              borderRadius: pw.BorderRadius.circular(6),
              border: pw.Border.all(color: PdfColors.grey300),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Row(children: [
                  pw.Expanded(child: fila('Expediente', i.codigo)),
                  pw.Expanded(child: fila('Fecha', '${i.fecha.day}/${i.fecha.month}/${i.fecha.year}')),
                ]),
                pw.Row(children: [
                  pw.Expanded(child: fila('Sede', i.sede)),
                  pw.Expanded(child: fila('Edificio', i.edificio)),
                ]),
                pw.Row(children: [
                  pw.Expanded(child: fila('Área Específica', i.area)),
                  pw.Expanded(child: fila('Auditor Responsable', i.responsable)),
                ]),
                fila('Hallazgos Validados', '${lista.length} elementos conformes / con recomendación técnica'),
              ],
            ),
          ),
          pw.SizedBox(height: 14),

          // Marco Legal
          pw.Text('Marco Normativo Aplicable:', style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 4),
          pw.Text(
            '• NTC 1461 / NTC-ISO 3864: Principios cromáticos, formas geométricas y dimensionamiento de señales.\n'
            '• NSR-10 (Títulos J y K): Protección contra incendios (NTC 2885, NTC 1669) y medios de evacuación.\n'
            '• Resolución 2400 de 1979: Estatuto de Seguridad Industrial (demarcaciones, pasillos, EPP y orden locativo).\n'
            '• Decreto 1072 de 2015: Plan de Prevención, Preparación y Respuesta ante Emergencias (Art. 2.2.4.6.25).',
            style: const pw.TextStyle(fontSize: 8.5, color: PdfColors.grey800, lineSpacing: 2),
          ),
          pw.SizedBox(height: 14),

          // Hallazgos Validados
          pw.Text('Detalle Pericial de Hallazgos y Dictamen Técnico:',
              style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: PdfColor.fromHex('#0B2A4A'))),
          pw.SizedBox(height: 8),

          for (final h in lista) ...[
            pw.Container(
              margin: const pw.EdgeInsets.only(bottom: 12),
              padding: const pw.EdgeInsets.all(10),
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: PdfColors.grey400),
                borderRadius: pw.BorderRadius.circular(6),
              ),
              child: pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  // Fotografía real con aspecto preservado
                  _construirImagenPdf(h, fotosCargadas),
                  pw.SizedBox(width: 12),
                  pw.Expanded(
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(h.elemento,
                            style: pw.TextStyle(
                                fontSize: 11, fontWeight: pw.FontWeight.bold, color: PdfColor.fromHex('#0B2A4A'))),
                        if (h.norma.isNotEmpty)
                          pw.Text('Norma: ${h.norma}',
                              style: const pw.TextStyle(fontSize: 8.5, color: PdfColors.blue800)),
                        pw.SizedBox(height: 4),
                        fila('Categoría', h.categoria),
                        fila('Ubicación', h.ubicacion),
                        fila('Condición', h.condicion),
                        if (h.alturaMontaje.isNotEmpty) fila('Altura reglamentaria', h.alturaMontaje),
                        if (h.recomendacion.isNotEmpty) ...[
                          pw.SizedBox(height: 4),
                          pw.Text('Recomendación Técnica:',
                              style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8.5)),
                          pw.Text(h.recomendacion,
                              style: const pw.TextStyle(fontSize: 8.5, color: PdfColors.grey800)),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],

          if (lista.isEmpty)
            pw.Padding(
              padding: const pw.EdgeInsets.all(20),
              child: pw.Text('Esta inspección no tiene hallazgos validados por el profesional.',
                  style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
            ),

          pw.SizedBox(height: 24),
          // Bloque de Firmas
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.center,
                children: [
                  pw.Container(width: 180, decoration: const pw.BoxDecoration(border: pw.Border(top: pw.BorderSide()))),
                  pw.SizedBox(height: 4),
                  pw.Text(i.responsable, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9)),
                  pw.Text('Auditor / Especialista SST', style: const pw.TextStyle(fontSize: 8)),
                ],
              ),
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.center,
                children: [
                  pw.Container(width: 180, decoration: const pw.BoxDecoration(border: pw.Border(top: pw.BorderSide()))),
                  pw.SizedBox(height: 4),
                  pw.Text('Coordinación de SST / Planta Física',
                      style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9)),
                  pw.Text('Recepción y Gestión Institucional', style: const pw.TextStyle(fontSize: 8)),
                ],
              ),
            ],
          ),
        ],
      ),
    );
    return doc.save();
  }

  pw.Widget _construirImagenPdf(Hallazgo h, Map<String, Uint8List> fotosCargadas) {
    final key = '${h.elemento}_${h.fecha.millisecondsSinceEpoch}';
    final bytes = fotosCargadas[key];
    if (bytes != null && bytes.isNotEmpty) {
      try {
        return pw.ClipRRect(
          horizontalRadius: 4,
          verticalRadius: 4,
          child: pw.Image(
            pw.MemoryImage(bytes),
            width: 120,
            height: 95,
            fit: pw.BoxFit.cover,
          ),
        );
      } catch (_) {}
    }
    return pw.Container(
      width: 120,
      height: 95,
      decoration: pw.BoxDecoration(
        color: PdfColors.grey300,
        borderRadius: pw.BorderRadius.circular(4),
      ),
      child: pw.Center(
        child: pw.Text(
          'Evidencia SST',
          style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700),
        ),
      ),
    );
  }
}
