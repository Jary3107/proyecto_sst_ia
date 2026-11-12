enum EstadoHallazgo { validado, pendiente, rechazado }

class Hallazgo {
  String elemento;
  String categoria;
  String ubicacion;
  String descripcion;
  String condicion;
  String observacion;
  double confianza; // 0..1
  EstadoHallazgo estado;
  final DateTime fecha;
  final String? fotoPath;
  String? fotoAnotadaBase64;
  List<double>? bbox;

  // Parámetros normativos SST oficiales (NTC 1461, Res. 2400/79, NSR-10, Dec. 1072/15)
  String norma;
  String colorSeguridad;
  String colorContraste;
  String formaGeometrica;
  String tamanoRecomendado;
  String formulaDimension;
  String alturaMontaje;
  String demarcacionPiso;
  String fotoluminiscencia;
  String recomendacion;
  List<String> checklistSst;
  List<bool> checklistVerificados;

  Hallazgo({
    required this.elemento,
    required this.categoria,
    required this.ubicacion,
    required this.descripcion,
    required this.condicion,
    required this.observacion,
    required this.confianza,
    this.estado = EstadoHallazgo.pendiente,
    this.fotoPath,
    this.fotoAnotadaBase64,
    this.bbox,
    this.norma = '',
    this.colorSeguridad = '',
    this.colorContraste = '',
    this.formaGeometrica = '',
    this.tamanoRecomendado = '',
    this.formulaDimension = '',
    this.alturaMontaje = '',
    this.demarcacionPiso = '',
    this.fotoluminiscencia = '',
    this.recomendacion = '',
    List<String>? checklistSst,
    List<bool>? checklistVerificados,
    DateTime? fecha,
  })  : fecha = fecha ?? DateTime.now(),
        checklistSst = checklistSst ?? [],
        checklistVerificados = checklistVerificados ??
            List<bool>.filled((checklistSst?.length ?? 0), false);

  Map<String, dynamic> toMap() => {
        'elemento': elemento,
        'categoria': categoria,
        'ubicacion': ubicacion,
        'descripcion': descripcion,
        'condicion': condicion,
        'observacion': observacion,
        'confianza': confianza,
        'estado': estado.name,
        'fecha': fecha.toIso8601String(),
        'fotoPath': fotoPath,
        'foto_anotada_base64': fotoAnotadaBase64,
        'bbox': bbox,
        'norma': norma,
        'color_seguridad': colorSeguridad,
        'color_contraste': colorContraste,
        'forma_geometrica': formaGeometrica,
        'tamano_recomendado': tamanoRecomendado,
        'formula_dimension': formulaDimension,
        'altura_montaje': alturaMontaje,
        'demarcacion_piso': demarcacionPiso,
        'fotoluminiscencia': fotoluminiscencia,
        'recomendacion': recomendacion,
        'checklist_sst': checklistSst,
        'checklist_verificados': checklistVerificados,
      };

  factory Hallazgo.fromMap(Map<String, dynamic> map) {
    final rawChecklist = map['checklist_sst'];
    final List<String> checklist = rawChecklist is List
        ? rawChecklist.map((e) => e.toString()).toList()
        : [];

    final rawVerificados = map['checklist_verificados'];
    final List<bool> verificados = rawVerificados is List
        ? rawVerificados.map((e) => e == true).toList()
        : List<bool>.filled(checklist.length, false);

    final rawBbox = map['bbox'];
    List<double>? bbox;
    if (rawBbox is List && rawBbox.isNotEmpty) {
      bbox = rawBbox.map((e) => (e as num).toDouble()).toList();
    }

    EstadoHallazgo est = EstadoHallazgo.pendiente;
    if (map['estado'] == 'validado') {
      est = EstadoHallazgo.validado;
    } else if (map['estado'] == 'rechazado') {
      est = EstadoHallazgo.rechazado;
    }

    return Hallazgo(
      elemento: map['elemento']?.toString() ?? 'Señal de Seguridad',
      categoria: map['categoria']?.toString() ?? 'General',
      ubicacion: map['ubicacion']?.toString() ?? '',
      descripcion: map['descripcion']?.toString() ?? '',
      condicion: map['condicion']?.toString() ?? 'Requiere verificación',
      observacion: map['observacion']?.toString() ?? '',
      confianza: (map['confianza'] as num?)?.toDouble() ?? 0.85,
      estado: est,
      fotoPath: map['fotoPath']?.toString() ?? map['foto_path']?.toString(),
      fotoAnotadaBase64: map['foto_anotada_base64']?.toString() ?? map['fotoAnotadaBase64']?.toString(),
      bbox: bbox,
      norma: map['norma']?.toString() ?? '',
      colorSeguridad: map['color_seguridad']?.toString() ?? '',
      colorContraste: map['color_contraste']?.toString() ?? '',
      formaGeometrica: map['forma_geometrica']?.toString() ?? '',
      tamanoRecomendado: map['tamano_recomendado']?.toString() ?? '',
      formulaDimension: map['formula_dimension']?.toString() ?? '',
      alturaMontaje: map['altura_montaje']?.toString() ?? '',
      demarcacionPiso: map['demarcacion_piso']?.toString() ?? '',
      fotoluminiscencia: map['fotoluminiscencia']?.toString() ?? '',
      recomendacion: map['recomendacion']?.toString() ?? '',
      checklistSst: checklist,
      checklistVerificados: verificados,
      fecha: map['fecha'] != null ? DateTime.tryParse(map['fecha']) : null,
    );
  }
}
