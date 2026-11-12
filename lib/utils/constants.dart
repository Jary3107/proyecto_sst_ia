import 'package:flutter/material.dart';

class C {
  static const navy = Color(0xFF0B2A4A);
  static const azul = Color(0xFF1565D8);
  static const gris = Color(0xFFF4F6FA);
  static const borde = Color(0xFFE2E6EE);
  static const verde = Color(0xFF1E9E63);
  static const naranja = Color(0xFFF28C0F);
  static const rojo = Color(0xFFD93025);
  static const texto2 = Color(0xFF6B7585);
}

/// URL del Backend en Render (FastAPI + YOLOv8 + ReportLab)
const String backendBaseUrl = 'https://proyecto-sst-ia.onrender.com';

const sedes = ['Campus Principal', 'Sede Norte'];
const edificios = ['Laboratorios', 'Administrativo', 'Biblioteca'];
const areas = ['Primer piso', 'Segundo piso', 'Sótano', 'Exteriores'];
const tiposSenal = ['Evacuación', 'Emergencia', 'Prohibición', 'Obligación', 'Advertencia', 'Equipos contra incendios', 'Otra'];
const categorias = [...tiposSenal, 'General'];
const condiciones = ['Conforme', 'Requiere verificación', 'Requiere revisión', 'Requiere atención', 'No conforme'];

String fFecha(DateTime d) => '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
String fHora(DateTime d) {
  final h = d.hour % 12 == 0 ? 12 : d.hour % 12;
  return '${h.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')} ${d.hour < 12 ? 'AM' : 'PM'}';
}
