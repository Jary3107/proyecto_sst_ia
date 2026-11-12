import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/app_state.dart';
import '../services/dataset_service.dart';
import '../utils/constants.dart';
import '../widgets/widgets.dart';
import 'dataset_screen.dart';
import 'historial_screen.dart';
import 'normas_screen.dart';
import 'nueva_inspeccion_screen.dart';
import 'perfil_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    final esEscritorio = MediaQuery.of(context).size.width >= 850;

    final tabs = [
      _Inicio(irA: (i) => setState(() => _tab = i)),
      const HistorialScreen(),
      const NormasScreen(),
      const HistorialScreen(soloInformes: true),
      const PerfilScreen(),
    ];

    if (esEscritorio) {
      return Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        body: Row(
          children: [
            // Barra de Navegación Lateral para PC (NavigationRail Desktop)
            NavigationRail(
              selectedIndex: _tab,
              onDestinationSelected: (i) => setState(() => _tab = i),
              backgroundColor: Colors.white,
              elevation: 1,
              minWidth: 90,
              minExtendedWidth: 220,
              extended: MediaQuery.of(context).size.width >= 1100,
              leading: Padding(
                padding: const EdgeInsets.symmetric(vertical: 20),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: C.azul.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.verified_user, color: C.azul, size: 28),
                    ),
                    if (MediaQuery.of(context).size.width >= 1100) ...[
                      const SizedBox(width: 10),
                      const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('SST-IA', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18, color: C.navy)),
                          Text('Auditoría Pericial', style: TextStyle(fontSize: 11, color: C.texto2)),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              destinations: const [
                NavigationRailDestination(
                  icon: Icon(Icons.home_outlined),
                  selectedIcon: Icon(Icons.home, color: C.azul),
                  label: Text('Inicio'),
                ),
                NavigationRailDestination(
                  icon: Icon(Icons.fact_check_outlined),
                  selectedIcon: Icon(Icons.fact_check, color: C.azul),
                  label: Text('Inspecciones'),
                ),
                NavigationRailDestination(
                  icon: Icon(Icons.menu_book_outlined),
                  selectedIcon: Icon(Icons.menu_book, color: C.azul),
                  label: Text('Normas SST'),
                ),
                NavigationRailDestination(
                  icon: Icon(Icons.bar_chart_outlined),
                  selectedIcon: Icon(Icons.bar_chart, color: C.azul),
                  label: Text('Informes PDF'),
                ),
                NavigationRailDestination(
                  icon: Icon(Icons.person_outline),
                  selectedIcon: Icon(Icons.person, color: C.azul),
                  label: Text('Perfil'),
                ),
              ],
            ),
            const VerticalDivider(width: 1, thickness: 1, color: Color(0xFFE2E8F0)),

            // Área Central de Contenido Adaptada para PC
            Expanded(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1200),
                  child: tabs[_tab],
                ),
              ),
            ),
          ],
        ),
      );
    }

    // Modo Móvil / Pantallas Angostas
    return Scaffold(
      body: SafeArea(child: IndexedStack(index: _tab, children: tabs)),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (i) => setState(() => _tab = i),
        backgroundColor: Colors.white,
        indicatorColor: const Color(0xFFE3EEFF),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home, color: C.azul),
            label: 'Inicio',
          ),
          NavigationDestination(
            icon: Icon(Icons.fact_check_outlined),
            selectedIcon: Icon(Icons.fact_check, color: C.azul),
            label: 'Inspecciones',
          ),
          NavigationDestination(
            icon: Icon(Icons.menu_book_outlined),
            selectedIcon: Icon(Icons.menu_book, color: C.azul),
            label: 'Normas SST',
          ),
          NavigationDestination(
            icon: Icon(Icons.bar_chart_outlined),
            selectedIcon: Icon(Icons.bar_chart, color: C.azul),
            label: 'Informes',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person, color: C.azul),
            label: 'Perfil',
          ),
        ],
      ),
    );
  }
}

class _Inicio extends StatefulWidget {
  final void Function(int) irA;
  const _Inicio({required this.irA});

  @override
  State<_Inicio> createState() => _InicioState();
}

class _InicioState extends State<_Inicio> {
  EstadoServidorIA? _salud;

  @override
  void initState() {
    super.initState();
    _revisarBackend();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<AppState>().cargarDesdeBackend();
    });
  }

  Future<void> _revisarBackend() async {
    final res = await DatasetIAService().verificarSalud();
    if (mounted) setState(() => _salud = res);
  }

  Widget _moduloCard({
    required IconData icono,
    required String titulo,
    required String subtitulo,
    required VoidCallback onTap,
    required Color color,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [BoxShadow(color: Color(0x08000000), blurRadius: 8, offset: Offset(0, 3))],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icono, color: color, size: 28),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        titulo,
                        style: const TextStyle(fontWeight: FontWeight.w700, color: C.navy, fontSize: 14.5),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        subtitulo,
                        style: const TextStyle(fontSize: 12, color: C.texto2, height: 1.25),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right, color: C.texto2),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ancho = MediaQuery.of(context).size.width;
    final esDesktop = ancho >= 768;
    final nombre = context.watch<AppState>().profesional.split(' ').first;
    final backendOk = _salud?.operativo == true;

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1100),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 36),
          children: [
            // Cabecera institucional
            Row(
              children: [
                if (!esDesktop) ...[
                  const Icon(Icons.verified_user, color: C.azul, size: 28),
                  const SizedBox(width: 8),
                  const Text('SST-IA', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: C.navy)),
                  const Spacer(),
                ],
                if (esDesktop)
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Panel de Auditoría y Control SST',
                          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: C.navy)),
                      Text('Sistema Asistido por Visión Artificial y Normativa Colombiana',
                          style: TextStyle(fontSize: 12.5, color: C.texto2)),
                    ],
                  ),
                const Spacer(),
                InkWell(
                  onTap: () {
                    _revisarBackend();
                    ir(context, const DatasetScreen());
                  },
                  borderRadius: BorderRadius.circular(20),
                  child: StatusBadge(
                    backendOk ? 'IA Conectada (sst_best.pt)' : 'Modo Local Offline',
                    backendOk ? C.verde : C.naranja,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Saludo al profesional
            Text(
              'Bienvenido, $nombre',
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: C.navy),
            ),
            const Text(
              'Auditor Especialista en Seguridad y Salud en el Trabajo · Politécnico Grancolombiano',
              style: TextStyle(color: C.texto2, fontSize: 13),
            ),
            const SizedBox(height: 20),

            // Banner Hero: Nueva Inspección
            InkWell(
              onTap: () => ir(context, const NuevaInspeccionScreen()),
              borderRadius: BorderRadius.circular(16),
              child: Container(
                padding: const EdgeInsets.all(22),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF0F3B68), Color(0xFF1E5BB0)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF1E5BB0).withValues(alpha: 0.28),
                      blurRadius: 14,
                      offset: const Offset(0, 5),
                    )
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(Icons.add_a_photo, color: Colors.white, size: 32),
                    ),
                    const SizedBox(width: 18),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Iniciar Nueva Inspección Técnica',
                            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 17),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'Captura evidencias fotográficas, detecta señales con IA y genera el informe pericial normativo.',
                            style: TextStyle(color: Colors.white70, fontSize: 12.5, height: 1.3),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Icon(Icons.arrow_forward_ios, color: Colors.white, size: 18),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Módulos del Sistema en Grid para PC (2 columnas) o Lista para Móvil
            if (esDesktop)
              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 16,
                crossAxisSpacing: 16,
                childAspectRatio: 2.8,
                children: [
                  _moduloCard(
                    icono: Icons.menu_book,
                    titulo: 'Catálogo de Normas SST',
                    subtitulo: 'NTC 1461, Res. 2400/79, NSR-10, fórmulas dimensionales y fichas técnicas.',
                    color: const Color(0xFF0284C7),
                    onTap: () => widget.irA(2),
                  ),
                  _moduloCard(
                    icono: Icons.model_training,
                    titulo: 'Dataset y Modelo YOLOv8',
                    subtitulo: 'Importar datasets Roboflow vía cURL, compilar pesos sst_best.pt y monitorear.',
                    color: const Color(0xFF7C3AED),
                    onTap: () => ir(context, const DatasetScreen()),
                  ),
                  _moduloCard(
                    icono: Icons.fact_check_outlined,
                    titulo: 'Mis Inspecciones en Sede',
                    subtitulo: 'Control de recorridos activos, evidencias fotográficas y estado de hallazgos.',
                    color: C.azul,
                    onTap: () => widget.irA(1),
                  ),
                  _moduloCard(
                    icono: Icons.picture_as_pdf,
                    titulo: 'Informes Periciales de Auditoría',
                    subtitulo: 'Generación y descarga de dictámenes oficiales en PDF según APA 7ma.',
                    color: C.verde,
                    onTap: () => widget.irA(3),
                  ),
                ],
              )
            else ...[
              _moduloCard(
                icono: Icons.menu_book,
                titulo: 'Catálogo de Normas SST',
                subtitulo: 'NTC 1461, Res. 2400/79, NSR-10 y fichas técnicas',
                color: const Color(0xFF0284C7),
                onTap: () => widget.irA(2),
              ),
              const SizedBox(height: 12),
              _moduloCard(
                icono: Icons.model_training,
                titulo: 'Dataset y Modelo YOLOv8',
                subtitulo: 'Importar vía cURL de Roboflow y compilar modelo',
                color: const Color(0xFF7C3AED),
                onTap: () => ir(context, const DatasetScreen()),
              ),
              const SizedBox(height: 12),
              _moduloCard(
                icono: Icons.fact_check_outlined,
                titulo: 'Mis inspecciones',
                subtitulo: 'Recorridos en curso y finalizados',
                color: C.azul,
                onTap: () => widget.irA(1),
              ),
              const SizedBox(height: 12),
              _moduloCard(
                icono: Icons.picture_as_pdf,
                titulo: 'Informes Periciales',
                subtitulo: 'Generar y consultar reportes oficiales en PDF',
                color: C.verde,
                onTap: () => widget.irA(3),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
