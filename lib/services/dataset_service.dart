import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../utils/constants.dart';

class EstadoEntrenamiento {
  final bool enProgreso;
  final int progreso;
  final String mensaje;
  final String? ultimoModelo;
  final String? error;

  const EstadoEntrenamiento({
    required this.enProgreso,
    required this.progreso,
    required this.mensaje,
    this.ultimoModelo,
    this.error,
  });

  factory EstadoEntrenamiento.fromMap(Map<String, dynamic> map) =>
      EstadoEntrenamiento(
        enProgreso: map['en_progreso'] == true,
        progreso: (map['progreso'] as num?)?.toInt() ?? 0,
        mensaje: map['mensaje']?.toString() ?? 'Listo',
        ultimoModelo: map['ultimo_modelo']?.toString(),
        error: map['error']?.toString(),
      );
}

class EstadoServidorIA {
  final bool operativo;
  final String modeloCargado;
  final String version;
  final String url;

  const EstadoServidorIA({
    required this.operativo,
    required this.modeloCargado,
    required this.version,
    required this.url,
  });
}

class DatasetIAService {
  static String get baseUrl => backendBaseUrl;

  /// Verifica la salud y el modelo cargado actualmente en Modulo_SST_IA
  Future<EstadoServidorIA> verificarSalud() async {
    final url = '$baseUrl/api/health';
    try {
      final resp = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 4));
      if (resp.statusCode == 200) {
        final data = jsonDecode(utf8.decode(resp.bodyBytes));
        return EstadoServidorIA(
          operativo: true,
          modeloCargado: data['modelo_cargado'] ?? 'sst_best.pt',
          version: data['version'] ?? '2.0.0',
          url: baseUrl,
        );
      }
    } catch (_) {}
    return EstadoServidorIA(
      operativo: false,
      modeloCargado: 'Desconectado (Simulador local activo)',
      version: '1.0.0',
      url: baseUrl,
    );
  }

  /// Envía un comando cURL de Roboflow / YOLO para descargar y descomprimir el dataset en el backend
  Future<Map<String, dynamic>> importarDatasetCurl({
    required String curlCommand,
    String nombreDataset = 'dataset_sst_roboflow',
  }) async {
    final url = '$baseUrl/api/datasets/importar_curl';
    try {
      final resp = await http
          .post(
            Uri.parse(url),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'curl_command': curlCommand,
              'nombre_dataset': nombreDataset,
            }),
          )
          .timeout(const Duration(minutes: 3));

      if (resp.statusCode == 200) {
        return jsonDecode(utf8.decode(resp.bodyBytes)) as Map<String, dynamic>;
      } else {
        final err = jsonDecode(utf8.decode(resp.bodyBytes));
        throw Exception(err['detail'] ?? 'Error al procesar el cURL (${resp.statusCode})');
      }
    } catch (e) {
      throw Exception('Fallo de conexión al importar dataset: $e');
    }
  }

  /// Inicia el reentrenamiento asíncrono de YOLOv8
  Future<Map<String, dynamic>> iniciarEntrenamiento({
    required String dataYamlPath,
    int epochs = 25,
  }) async {
    final url = '$baseUrl/api/datasets/entrenar';
    try {
      final resp = await http
          .post(
            Uri.parse(url),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'data_yaml_path': dataYamlPath,
              'epochs': epochs,
            }),
          )
          .timeout(const Duration(seconds: 15));

      if (resp.statusCode == 200) {
        return jsonDecode(utf8.decode(resp.bodyBytes)) as Map<String, dynamic>;
      } else {
        final err = jsonDecode(utf8.decode(resp.bodyBytes));
        throw Exception(err['detail'] ?? 'Error al iniciar entrenamiento');
      }
    } catch (e) {
      throw Exception('Fallo de conexión al entrenar modelo: $e');
    }
  }

  /// Consulta el estado y progreso en tiempo real del entrenamiento
  Future<EstadoEntrenamiento> consultarEstadoEntrenamiento() async {
    final url = '$baseUrl/api/datasets/estado';
    try {
      final resp = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 4));
      if (resp.statusCode == 200) {
        final data = jsonDecode(utf8.decode(resp.bodyBytes));
        return EstadoEntrenamiento.fromMap(data);
      }
    } catch (_) {}
    return const EstadoEntrenamiento(
      enProgreso: false,
      progreso: 0,
      mensaje: 'Servidor no responde',
      error: 'Sin conexión',
    );
  }
}
