import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/evidencia.dart';
import '../models/hallazgo.dart';
import '../services/app_state.dart';
import '../utils/constants.dart';
import '../utils/validators.dart';
import '../widgets/widgets.dart';
import 'hallazgo_guardado_screen.dart';

class RevisarHallazgoScreen extends StatefulWidget {
  final Evidencia evidencia;
  final Hallazgo hallazgo;
  const RevisarHallazgoScreen(this.evidencia, this.hallazgo, {super.key});

  @override
  State<RevisarHallazgoScreen> createState() => _RevisarHallazgoScreenState();
}

class _RevisarHallazgoScreenState extends State<RevisarHallazgoScreen> {
  final _form = GlobalKey<FormState>();
  late final Hallazgo h = widget.hallazgo;

  late final _elemento = TextEditingController(text: h.elemento);
  late final _ubi = TextEditingController(text: h.ubicacion);
  late final _desc = TextEditingController(text: h.descripcion);
  late final _obs = TextEditingController(text: h.observacion);
  late final _norma = TextEditingController(text: h.norma);
  late final _recom = TextEditingController(text: h.recomendacion);

  late String _categoria = h.categoria;
  late String _condicion = h.condicion;
  late List<bool> _verificados;

  @override
  void initState() {
    super.initState();
    if (h.checklistVerificados.length != h.checklistSst.length) {
      _verificados = List<bool>.filled(h.checklistSst.length, false);
    } else {
      _verificados = List<bool>.from(h.checklistVerificados);
    }
  }

  @override
  void dispose() {
    _elemento.dispose();
    _ubi.dispose();
    _desc.dispose();
    _obs.dispose();
    _norma.dispose();
    _recom.dispose();
    super.dispose();
  }

  Widget _combo(String v, List<String> base, void Function(String?) f) {
    final items = base.contains(v) ? base : [...base, v];
    return DropdownButtonFormField<String>(
      initialValue: v,
      isExpanded: true,
      items: items.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
      onChanged: f,
      decoration: InputDecoration(
        filled: true,
        fillColor: const Color(0xFFF8FAFC),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
        ),
      ),
    );
  }

  bool _guardar(EstadoHallazgo estado) {
    h
      ..elemento = _elemento.text.trim()
      ..categoria = _categoria
      ..ubicacion = _ubi.text.trim()
      ..descripcion = _desc.text.trim()
      ..condicion = _condicion
      ..observacion = _obs.text.trim()
      ..norma = _norma.text.trim()
      ..recomendacion = _recom.text.trim()
      ..checklistVerificados = _verificados
      ..estado = estado;

    final nuevo = !widget.evidencia.hallazgos.contains(h);
    context.read<AppState>().guardarHallazgo(widget.evidencia, h);
    return nuevo;
  }

  void _accion(EstadoHallazgo estado) {
    if (!_form.currentState!.validate()) return;
    _guardar(estado);
    Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const HallazgoGuardadoScreen()));
  }

  @override
  Widget build(BuildContext context) {
    final esDesktop = MediaQuery.of(context).size.width >= 850;

    Widget seccionFotoYNorma = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Foto(
          h.fotoPath,
          base64Str: h.fotoAnotadaBase64,
          height: esDesktop ? 260 : 160,
          width: double.infinity,
        ),
        const SizedBox(height: 12),
        if (h.norma.isNotEmpty)
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFEFF6FF),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFBFDBFE)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Norma Aplicable de Referencia:',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 11.5, color: C.navy)),
                const SizedBox(height: 3),
                Text(h.norma, style: const TextStyle(fontSize: 12, color: Color(0xFF1E3A8A), fontWeight: FontWeight.w600)),
                if (h.alturaMontaje.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text('Altura reglamentaria: ${h.alturaMontaje}',
                      style: const TextStyle(fontSize: 11.5, color: Color(0xFF334155))),
                ],
              ],
            ),
          ),
        const SizedBox(height: 18),
        Row(
          children: [
            Expanded(
              child: AppButton(
                'Guardar Pendiente',
                estilo: EstiloBoton.contorno,
                onPressed: () => _accion(EstadoHallazgo.pendiente),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: AppButton(
                'Aprobar Hallazgo',
                estilo: EstiloBoton.primario,
                onPressed: () => _accion(EstadoHallazgo.validado),
              ),
            ),
          ],
        ),
      ],
    );

    Widget seccionFormulario = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Etiqueta('Elemento / Señal'),
        TextFormField(controller: _elemento, validator: requerido),

        const Etiqueta('Categoría Normativa'),
        _combo(_categoria, categorias, (v) => setState(() => _categoria = v!)),

        const Etiqueta('Ubicación Física en Sede'),
        TextFormField(controller: _ubi, validator: requerido),

        const Etiqueta('Condición de Conformidad'),
        _combo(_condicion, condiciones, (v) => setState(() => _condicion = v!)),

        const Etiqueta('Norma Técnica de Referencia'),
        TextFormField(controller: _norma),

        // Checklist Normativo Interactivo
        if (h.checklistSst.isNotEmpty) ...[
          const Etiqueta('Puntos de Verificación en Terreno (Checklist SST)'),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Column(
              children: [
                for (int i = 0; i < h.checklistSst.length; i++)
                  CheckboxListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    activeColor: C.verde,
                    title: Text(
                      h.checklistSst[i],
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: _verificados[i] ? FontWeight.w600 : FontWeight.w400,
                        color: _verificados[i] ? C.navy : const Color(0xFF475569),
                      ),
                    ),
                    value: _verificados[i],
                    onChanged: (val) {
                      setState(() => _verificados[i] = val == true);
                    },
                  ),
              ],
            ),
          ),
        ],

        const Etiqueta('Recomendación Técnica Pericial (Normas SST)'),
        TextFormField(
          controller: _recom,
          maxLines: 3,
          decoration: const InputDecoration(
            hintText: 'Acción preventiva o correctiva exigida por la norma...',
          ),
        ),

        const Etiqueta('Descripción y Observación del Auditor'),
        TextFormField(controller: _obs, maxLines: 2),
      ],
    );

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('Validación de Hallazgo SST'),
        backgroundColor: Colors.white,
        foregroundColor: C.navy,
        elevation: 0.5,
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1100),
          child: Form(
            key: _form,
            child: esDesktop
                ? Padding(
                    padding: const EdgeInsets.all(24),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(flex: 5, child: seccionFotoYNorma),
                        const SizedBox(width: 24),
                        Expanded(flex: 6, child: SingleChildScrollView(child: seccionFormulario)),
                      ],
                    ),
                  )
                : contenido([
                    seccionFotoYNorma,
                    const SizedBox(height: 14),
                    seccionFormulario,
                  ]),
          ),
        ),
      ),
    );
  }
}
