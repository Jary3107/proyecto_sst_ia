import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import '../models/evidencia.dart';
import '../models/hallazgo.dart';
import '../utils/catalogo_normas.dart';
import '../utils/constants.dart';
import 'analisis_service.dart';
import 'analisis_simulado_service.dart';

/// Servicio principal que conecta Flutter con el backend Python (Modulo_SST_IA).
/// Envía la evidencia y recibe la detección YOLO, bounding boxes, recomendación
/// pericial y especificaciones normativas de SST.
class ServicioAnalisisIAService implements AnalisisService {
  final ServicioAnalisisSimulado _fallback = ServicioAnalisisSimulado();

  String get _urlServidor => '$backendBaseUrl/analizar';

  @override
  Future<Hallazgo> analizar(Evidencia e) async {
    try {
      String fotoB64 = '';
      if (e.fotoPath.isNotEmpty) {
        final bytes = await XFile(e.fotoPath).readAsBytes();
        fotoB64 = base64Encode(bytes);
      }

      if (fotoB64.isEmpty) {
        debugPrint('[SST-IA] Foto vacía, usando fallback normativo.');
        return _fallback.analizar(e);
      }

      final payload = jsonEncode({
        'foto_base64': fotoB64,
        'observacion': e.observacion,
        'ubicacion': e.ubicacion,
        'tipo_esperado': e.tipo,
        'tipo': e.tipo,
        'adicional': e.adicional,
      });

      debugPrint('[SST-IA] Conectando a backend Render SST-IA: $_urlServidor');
      final resp = await http
          .post(
            Uri.parse(_urlServidor),
            headers: {'Content-Type': 'application/json; charset=utf-8'},
            body: payload,
          )
          .timeout(const Duration(seconds: 45));

      if (resp.statusCode == 200) {
        final data = jsonDecode(utf8.decode(resp.bodyBytes)) as Map<String, dynamic>;

        final elemento = data['elemento']?.toString() ?? 'Señal de Seguridad';
        final categoria = data['categoria']?.toString() ?? 'General';
        final condicion = data['condicion']?.toString() ?? 'Requiere verificación';
        final double confianza = (data['confianza'] as num?)?.toDouble() ?? 0.90;
        final String? fotoAnotada = data['foto_anotada_base64']?.toString();

        // Si el backend envió checklist, usarlo; sino consultar catálogo local
        List<String> checklist = [];
        if (data['checklist_sst'] is List && (data['checklist_sst'] as List).isNotEmpty) {
          checklist = (data['checklist_sst'] as List).map((i) => i.toString()).toList();
        }

        // Bounding box
        List<double>? bbox;
        if (data['bbox'] is List) {
          bbox = (data['bbox'] as List).map((v) => (v as num).toDouble()).toList();
        }

        // Si faltan datos normativos específicos, autocompletar con el catálogo oficial
        final senalRef = CatalogoNormasSST.buscarPorTexto('$elemento $categoria ${e.tipo}');

        final norma = (data['norma']?.toString().isNotEmpty == true)
            ? data['norma'].toString()
            : (senalRef?.norma ?? 'NTC 1461 / NTC-ISO 3864-1 / Res. 2400 de 1979');

        final recomendacion = (data['recomendacion']?.toString().isNotEmpty == true)
            ? data['recomendacion'].toString()
            : (senalRef?.recomendacion ??
                'Verificar conformidad técnica y fijación reglamentaria según NTC 1461.');

        if (checklist.isEmpty && senalRef != null) {
          checklist = List<String>.from(senalRef.checklistSst);
        }

        return Hallazgo(
          elemento: elemento,
          categoria: categoria,
          ubicacion: e.ubicacion.isNotEmpty ? e.ubicacion : 'Área auditada',
          descripcion: data['descripcion']?.toString() ??
              'Detección asistida por IA con modelo YOLOv8 y reglas de conformidad SST.',
          condicion: condicion,
          observacion: e.observacion,
          confianza: confianza,
          fotoPath: e.fotoPath,
          fotoAnotadaBase64: (fotoAnotada != null && fotoAnotada.isNotEmpty) ? fotoAnotada : fotoB64,
          bbox: bbox,
          norma: norma,
          colorSeguridad: data['color_seguridad']?.toString() ?? (senalRef?.colorSeguridad ?? ''),
          colorContraste: data['color_contraste']?.toString() ?? (senalRef?.colorContraste ?? ''),
          formaGeometrica: data['forma_geometrica']?.toString() ?? (senalRef?.formaGeometrica ?? ''),
          tamanoRecomendado: data['tamano_recomendado']?.toString() ?? (senalRef?.tamanoRecomendado ?? ''),
          formulaDimension: data['formula_dimension']?.toString() ?? (senalRef?.formulaDimension ?? ''),
          alturaMontaje: data['altura_montaje']?.toString() ?? (senalRef?.alturaMontaje ?? ''),
          demarcacionPiso: data['demarcacion_piso']?.toString() ?? (senalRef?.demarcacionPiso ?? ''),
          fotoluminiscencia: data['fotoluminiscencia']?.toString() ?? (senalRef?.fotoluminiscencia ?? ''),
          recomendacion: recomendacion,
          checklistSst: checklist,
          estado: EstadoHallazgo.pendiente,
        );
      } else {
        debugPrint('[SST-IA] Servidor retornó ${resp.statusCode}. Activando fallback normativo.');
        return _fallback.analizar(e);
      }
    } catch (err) {
      debugPrint('[SST-IA] Error al comunicar con backend Modulo_SST_IA ($err). Activando fallback.');
      return _fallback.analizar(e);
    }
  }
}
