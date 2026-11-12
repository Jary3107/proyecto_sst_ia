import 'evidencia.dart';
import 'hallazgo.dart';

enum EstadoInspeccion { enCurso, finalizada }

class Inspeccion {
  final int numero;
  final DateTime fecha;
  final String sede, edificio, area, responsable;
  EstadoInspeccion estado = EstadoInspeccion.enCurso;
  final List<Evidencia> evidencias;

  Inspeccion({
    required this.numero,
    required this.fecha,
    required this.sede,
    required this.edificio,
    required this.area,
    required this.responsable,
    EstadoInspeccion? estado,
    List<Evidencia>? evidencias,
  })  : estado = estado ?? EstadoInspeccion.enCurso,
        evidencias = evidencias ?? [];

  String get codigo => '#${numero.toString().padLeft(4, '0')}';
  List<Hallazgo> get hallazgos => evidencias.expand((e) => e.hallazgos).toList();
  List<Hallazgo> get validados => hallazgos.where((h) => h.estado != EstadoHallazgo.rechazado).toList();

  Map<String, dynamic> toMap() => {
        'numero': codigo,
        'fecha': '${fecha.day}/${fecha.month}/${fecha.year}',
        'sede': sede,
        'edificio': edificio,
        'area': area,
        'responsable': responsable,
        'estado': estado.name,
        'evidencias': evidencias.map((e) => e.toMap()).toList(),
        'hallazgos_validados_count': validados.length,
      };

  factory Inspeccion.fromMap(Map<String, dynamic> map) {
    int numParsed = 1;
    if (map['numero'] != null) {
      final s = map['numero'].toString().replaceAll('#', '');
      numParsed = int.tryParse(s) ?? 1;
    }

    final insp = Inspeccion(
      numero: numParsed,
      fecha: map['fecha'] != null ? (DateTime.tryParse(map['fecha']) ?? DateTime.now()) : DateTime.now(),
      sede: map['sede']?.toString() ?? '',
      edificio: map['edificio']?.toString() ?? '',
      area: map['area']?.toString() ?? '',
      responsable: map['responsable']?.toString() ?? '',
      estado: map['estado'] == 'finalizada' ? EstadoInspeccion.finalizada : EstadoInspeccion.enCurso,
    );

    if (map['evidencias'] is List) {
      for (final e in map['evidencias']) {
        if (e is Map<String, dynamic>) {
          insp.evidencias.add(Evidencia.fromMap(e));
        }
      }
    }
    return insp;
  }
}
