import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/evidencia.dart';
import '../models/hallazgo.dart';
import '../services/app_state.dart';
import '../utils/constants.dart';
import '../widgets/widgets.dart';
import 'revisar_hallazgo_screen.dart';

class ResultadoIAScreen extends StatefulWidget {
  final Evidencia evidencia;
  final Hallazgo hallazgo;
  const ResultadoIAScreen(this.evidencia, this.hallazgo, {super.key});

  @override
  State<ResultadoIAScreen> createState() => _ResultadoIAScreenState();
}

class _ResultadoIAScreenState extends State<ResultadoIAScreen> {
  bool _mostrarAnotada = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<AppState>().guardarHallazgo(widget.evidencia, widget.hallazgo);
      }
    });
  }

  void _aprobarDirecto(BuildContext context) {
    widget.hallazgo.estado = EstadoHallazgo.validado;
    context.read<AppState>().guardarHallazgo(widget.evidencia, widget.hallazgo);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Hallazgo "${widget.hallazgo.elemento}" aprobado e incluido en el informe.'),
        backgroundColor: C.verde,
      ),
    );
    Navigator.popUntil(context, (r) => r.settings.name == 'inspeccion' || r.isFirst);
  }

  void _rechazar(BuildContext context) {
    widget.hallazgo.estado = EstadoHallazgo.rechazado;
    context.read<AppState>().guardarHallazgo(widget.evidencia, widget.hallazgo);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Hallazgo rechazado. No se incluirá en el informe pericial.')),
    );
    Navigator.popUntil(context, (r) => r.settings.name == 'inspeccion' || r.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    final h = widget.hallazgo;
    final tieneAnotada = h.fotoAnotadaBase64 != null && h.fotoAnotadaBase64!.isNotEmpty;
    final esDesktop = MediaQuery.of(context).size.width >= 850;

    // Sección visual de imagen con toggle
    Widget seccionImagen = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Stack(
          children: [
            Foto(
              _mostrarAnotada && tieneAnotada ? null : h.fotoPath,
              base64Str: _mostrarAnotada && tieneAnotada ? h.fotoAnotadaBase64 : null,
              height: esDesktop ? 320 : 180,
              width: double.infinity,
            ),
            if (tieneAnotada)
              Positioned(
                top: 10,
                right: 10,
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.7),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _botonToggle('Detección IA', _mostrarAnotada, () => setState(() => _mostrarAnotada = true)),
                      _botonToggle('Original', !_mostrarAnotada, () => setState(() => _mostrarAnotada = false)),
                    ],
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 14),
        ConfidenceBar(h.confianza),
        const SizedBox(height: 14),
        const AvisoPreliminar(),
        const SizedBox(height: 16),
        AppButton(
          'Aprobar y Guardar en Informe',
          icon: Icons.check_circle_outline,
          estilo: EstiloBoton.primario,
          onPressed: () => _aprobarDirecto(context),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: AppButton(
                'Rechazar',
                estilo: EstiloBoton.peligro,
                onPressed: () => _rechazar(context),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: AppButton(
                'Editar Parámetros',
                icon: Icons.edit_note,
                estilo: EstiloBoton.contorno,
                onPressed: () => ir(context, RevisarHallazgoScreen(widget.evidencia, h)),
              ),
            ),
          ],
        ),
      ],
    );

    // Sección de datos normativos y recomendaciones
    Widget seccionDatos = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Norma Legal
        if (h.norma.isNotEmpty)
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFEFF6FF),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFBFDBFE)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.verified, color: C.azul, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Norma Técnica Aplicable:',
                        style: TextStyle(fontWeight: FontWeight.w700, fontSize: 11.5, color: C.navy),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        h.norma,
                        style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: Color(0xFF1E3A8A)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        const SizedBox(height: 12),

        const Etiqueta('Diagnóstico Preliminar'),
        Dato('Elemento detectado', h.elemento),
        Dato('Categoría normativa', h.categoria),
        Dato('Ubicación en sede', h.ubicacion),
        Dato('Condición observada', h.condicion),

        // Especificaciones Normativas
        if (h.alturaMontaje.isNotEmpty || h.colorSeguridad.isNotEmpty) ...[
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Parámetros Normativos Técnicos:',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: C.navy),
                ),
                const SizedBox(height: 6),
                if (h.colorSeguridad.isNotEmpty)
                  _lineaParametro('Colores:', '${h.colorSeguridad} / ${h.colorContraste}'),
                if (h.formaGeometrica.isNotEmpty) _lineaParametro('Forma:', h.formaGeometrica),
                if (h.alturaMontaje.isNotEmpty) _lineaParametro('Altura montaje:', h.alturaMontaje),
                if (h.tamanoRecomendado.isNotEmpty) _lineaParametro('Dimensión:', h.tamanoRecomendado),
                if (h.demarcacionPiso.isNotEmpty) _lineaParametro('Demarcación piso:', h.demarcacionPiso),
              ],
            ),
          ),
        ],
        const SizedBox(height: 12),

        // Recomendación del modelo
        if (h.recomendacion.isNotEmpty)
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFF0FDF4),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFBBF7D0)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.lightbulb_outline, color: C.verde, size: 18),
                    SizedBox(width: 8),
                    Text(
                      'Recomendación Técnica Oficial:',
                      style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: C.navy),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  h.recomendacion,
                  style: const TextStyle(fontSize: 12, color: Color(0xFF166534), height: 1.3),
                ),
              ],
            ),
          ),
      ],
    );

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('Resultado de Detección IA (YOLO)'),
        backgroundColor: Colors.white,
        foregroundColor: C.navy,
        elevation: 0.5,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.popUntil(context, (r) => r.settings.name == 'inspeccion' || r.isFirst),
        ),
        actions: const [
          Padding(
            padding: EdgeInsets.only(right: 14),
            child: StatusBadge('Preliminar SST', C.azul),
          )
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1100),
          child: esDesktop
              ? Padding(
                  padding: const EdgeInsets.all(24),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(flex: 5, child: seccionImagen),
                      const SizedBox(width: 24),
                      Expanded(flex: 6, child: SingleChildScrollView(child: seccionDatos)),
                    ],
                  ),
                )
              : contenido([
                  seccionImagen,
                  const SizedBox(height: 14),
                  seccionDatos,
                ]),
        ),
      ),
    );
  }

  Widget _botonToggle(String texto, bool activo, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: activo ? C.azul : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          texto,
          style: TextStyle(
            fontSize: 11,
            fontWeight: activo ? FontWeight.w700 : FontWeight.w500,
            color: Colors.white,
          ),
        ),
      ),
    );
  }

  Widget _lineaParametro(String k, String v) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: RichText(
        text: TextSpan(
          style: const TextStyle(fontSize: 11.5, color: Color(0xFF334155)),
          children: [
            TextSpan(text: '$k ', style: const TextStyle(fontWeight: FontWeight.w600, color: C.navy)),
            TextSpan(text: v),
          ],
        ),
      ),
    );
  }
}
