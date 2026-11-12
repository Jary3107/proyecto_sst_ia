import 'dart:convert';
import 'package:image_picker/image_picker.dart';
import '../models/evidencia.dart';
import '../models/hallazgo.dart';
import '../utils/catalogo_normas.dart';
import 'analisis_service.dart';

/// Servicio de fallback local cuando el backend en Python (Modulo_SST_IA) no está disponible.
/// Aplica el Catálogo Normativo oficial SST para deducir la señal y los parámetros legales.
class ServicioAnalisisSimulado implements AnalisisService {
  @override
  Future<Hallazgo> analizar(Evidencia e) async {
    await Future.delayed(const Duration(milliseconds: 1200));

    // Cargar la imagen en Base64 para que siempre aparezca en el informe PDF
    String? fotoB64;
    if (e.fotoPath.isNotEmpty) {
      try {
        final bytes = await XFile(e.fotoPath).readAsBytes();
        fotoB64 = base64Encode(bytes);
      } catch (_) {}
    }

    final texto = '${e.tipo} ${e.observacion} ${e.ubicacion} ${e.adicional}';
    final senal = CatalogoNormasSST.buscarPorTexto(texto);

    if (senal != null) {
      return Hallazgo(
        elemento: senal.elemento,
        categoria: senal.categoria,
        ubicacion: e.ubicacion.isNotEmpty ? e.ubicacion : 'Área auditada',
        descripcion: 'Inspección técnica de conformidad según ${senal.norma}.',
        condicion: senal.condicionDefault,
        observacion: e.observacion,
        confianza: 0.94,
        fotoPath: e.fotoPath,
        fotoAnotadaBase64: fotoB64,
        norma: senal.norma,
        colorSeguridad: senal.colorSeguridad,
        colorContraste: senal.colorContraste,
        formaGeometrica: senal.formaGeometrica,
        tamanoRecomendado: senal.tamanoRecomendado,
        formulaDimension: senal.formulaDimension,
        alturaMontaje: senal.alturaMontaje,
        demarcacionPiso: senal.demarcacionPiso,
        fotoluminiscencia: senal.fotoluminiscencia,
        recomendacion: senal.recomendacion,
        checklistSst: List<String>.from(senal.checklistSst),
        estado: EstadoHallazgo.pendiente,
      );
    }

    // Diagnóstico genérico si no coincide con ninguna específica
    return Hallazgo(
      elemento: e.tipo.isNotEmpty ? e.tipo : 'Señalización de Seguridad',
      categoria: 'General',
      ubicacion: e.ubicacion.isNotEmpty ? e.ubicacion : 'Área auditada',
      descripcion: 'Elemento de señalización y seguridad locativa en recorrido de inspección.',
      condicion: 'Requiere verificación',
      observacion: e.observacion,
      confianza: 0.82,
      fotoPath: e.fotoPath,
      fotoAnotadaBase64: fotoB64,
      norma: 'NTC 1461 / NTC-ISO 3864 / Res. 2400 de 1979',
      colorSeguridad: 'Según categoría',
      colorContraste: 'Blanco / Negro',
      formaGeometrica: 'Estandarizada',
      tamanoRecomendado: 'S >= d² / 2000',
      formulaDimension: 'S >= d² / 2000',
      alturaMontaje: '1.60m a 1.80m sobre el NPT',
      demarcacionPiso: 'Franjas de 10 cm si corresponde a despeje de equipos',
      fotoluminiscencia: 'Clase A o B según tránsito',
      recomendacion:
          'Verificar conformidad dimensional y cromática con la norma NTC 1461. Asegurar correcta visibilidad a la distancia máxima de observación.',
      checklistSst: [
        '1. Señal perfectamente visible desde todos los ángulos de aproximación.',
        '2. Altura de montaje reglamentaria entre 1.60m y 1.80m.',
        '3. Ausencia de obstáculos frontales en un radio de 1 metro.',
        '4. Buen estado físico sin desprendimientos ni pérdida de color.',
      ],
      estado: EstadoHallazgo.pendiente,
    );
  }
}
