import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/evidencia.dart';
import '../models/hallazgo.dart';
import '../models/inspeccion.dart';
import '../utils/constants.dart';

/// Estado de la aplicación para inspecciones y hallazgos SST.
class AppState extends ChangeNotifier {
  final String profesional = 'Alejandro Torres';
  final List<Inspeccion> inspecciones = [];
  Inspeccion? actual;
  bool _cargandoBackend = false;

  Inspeccion crear({
    required DateTime fecha,
    required String sede,
    required String edificio,
    required String area,
    required String responsable,
  }) {
    final i = Inspeccion(
      numero: inspecciones.length + 1,
      fecha: fecha,
      sede: sede,
      edificio: edificio,
      area: area,
      responsable: responsable,
    );
    inspecciones.insert(0, i);
    actual = i;
    notifyListeners();
    return i;
  }

  void abrir(Inspeccion i) {
    actual = i;
    notifyListeners();
  }

  void guardarHallazgo(Evidencia e, Hallazgo h) {
    if (actual == null) {
      if (inspecciones.isNotEmpty) {
        actual = inspecciones.first;
      } else {
        actual = crear(
          fecha: DateTime.now(),
          sede: 'Politécnico Grancolombiano, Sede Medellín',
          edificio: 'Campus Principal',
          area: 'Área General de Recorrido',
          responsable: profesional,
        );
      }
    }
    if (!actual!.evidencias.contains(e)) {
      actual!.evidencias.add(e);
    }
    if (!e.hallazgos.contains(h)) {
      e.hallazgos.add(h);
    }
    notifyListeners();
  }

  void finalizar() {
    actual?.estado = EstadoInspeccion.finalizada;
    notifyListeners();
  }

  void notificar() => notifyListeners();

  Future<void> cargarDesdeBackend() async {
    if (_cargandoBackend) return;
    _cargandoBackend = true;
    try {
      final resp = await http
          .get(Uri.parse('$backendBaseUrl/api/inspecciones'))
          .timeout(const Duration(seconds: 12));
      if (resp.statusCode == 200) {
        final list = jsonDecode(utf8.decode(resp.bodyBytes));
        if (list is List && list.isNotEmpty) {
          for (final item in list) {
            if (item is Map<String, dynamic>) {
              final insp = Inspeccion.fromMap(item);
              if (!inspecciones.any((ex) => ex.codigo == insp.codigo)) {
                inspecciones.add(insp);
              }
            }
          }
          if (actual == null && inspecciones.isNotEmpty) {
            actual = inspecciones.first;
          }
          notifyListeners();
        }
      }
    } catch (_) {
      // Si el backend no responde o está en reposo, continuar sin interrumpir
    } finally {
      _cargandoBackend = false;
    }
  }
}
