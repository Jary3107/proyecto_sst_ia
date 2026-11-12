import 'hallazgo.dart';

class Evidencia {
  final String fotoPath;
  final String observacion, ubicacion, tipo, adicional;
  final DateTime fecha;
  final List<Hallazgo> hallazgos;

  Evidencia({
    required this.fotoPath,
    required this.observacion,
    required this.ubicacion,
    this.tipo = '',
    this.adicional = '',
    DateTime? fecha,
    List<Hallazgo>? hallazgos,
  })  : fecha = fecha ?? DateTime.now(),
        hallazgos = hallazgos ?? [];

  Map<String, dynamic> toMap() {
    String? b64;
    for (final h in hallazgos) {
      if (h.fotoAnotadaBase64 != null && h.fotoAnotadaBase64!.isNotEmpty) {
        b64 = h.fotoAnotadaBase64;
        break;
      }
    }
    return {
      'foto_path': fotoPath,
      'foto_base64': b64,
      'observacion': observacion,
      'ubicacion': ubicacion,
      'tipo': tipo,
      'adicional': adicional,
      'fecha': fecha.toIso8601String(),
      'hallazgos': hallazgos.map((h) => h.toMap()).toList(),
    };
  }

  factory Evidencia.fromMap(Map<String, dynamic> map) {
    final e = Evidencia(
      fotoPath: map['foto_path']?.toString() ?? '',
      observacion: map['observacion']?.toString() ?? '',
      ubicacion: map['ubicacion']?.toString() ?? '',
      tipo: map['tipo']?.toString() ?? '',
      adicional: map['adicional']?.toString() ?? '',
      fecha: map['fecha'] != null ? DateTime.tryParse(map['fecha']) : null,
    );
    if (map['hallazgos'] is List) {
      for (final h in map['hallazgos']) {
        if (h is Map<String, dynamic>) {
          e.hallazgos.add(Hallazgo.fromMap(h));
        }
      }
    }
    return e;
  }
}
