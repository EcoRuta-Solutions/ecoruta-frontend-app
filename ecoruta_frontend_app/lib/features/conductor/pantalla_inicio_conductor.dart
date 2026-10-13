import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/config/app_config.dart';
import '../../core/theme/app_theme.dart';
import '../auth/presentation/auth_controller.dart';
import 'presentation/accesibilidad_conductor.dart';
import 'presentation/navegacion_conductor_controller.dart';
import 'presentation/pantalla_mapa_conductor.dart';
import 'presentation/pantalla_mas_conductor.dart';
import 'presentation/pantalla_mi_ruta.dart';
import 'presentation/pantalla_reportar.dart';

class PantallaInicioConductor extends ConsumerWidget {
  const PantallaInicioConductor({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final destino = ref.watch(navegacionConductorProvider).destino;
    final pantalla = switch (destino) {
      DestinoConductor.miRuta => const PantallaMiRuta(),
      DestinoConductor.mapa => const PantallaMapaConductor(),
      DestinoConductor.reportar => const PantallaReportar(),
      DestinoConductor.mas => const PantallaMasConductor(),
    };
    final titulo = switch (destino) {
      DestinoConductor.miRuta => 'Mi ruta',
      DestinoConductor.mapa => 'Mapa de ruta',
      DestinoConductor.reportar => 'Reportar',
      DestinoConductor.mas => 'Mi perfil',
    };

    return Scaffold(
      appBar: AppBar(
        backgroundColor: EcoColors.fondo,
        title: Text(titulo),
        actions: [
          semanticaBotonConductor(
            etiqueta: 'Cerrar sesión',
            child: IconButton(
              tooltip: 'Cerrar sesión',
              constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
              icon: const Icon(Icons.logout_rounded),
              onPressed: () => ref.read(authProvider.notifier).logout(),
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          if (AppConfig.usarDatosDeEjemplo) const _AvisoDatosEjemplo(),
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 220),
              switchInCurve: Curves.easeOut,
              switchOutCurve: Curves.easeIn,
              transitionBuilder: (child, animation) =>
                  FadeTransition(opacity: animation, child: child),
              child: KeyedSubtree(key: ValueKey(destino), child: pantalla),
            ),
          ),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: destino.index,
        onDestinationSelected: (seleccion) => ref
            .read(navegacionConductorProvider.notifier)
            .seleccionar(DestinoConductor.values[seleccion]),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.route_outlined),
            selectedIcon: Icon(Icons.route_rounded),
            label: 'Mi ruta',
          ),
          NavigationDestination(
            icon: Icon(Icons.map_outlined),
            selectedIcon: Icon(Icons.map_rounded),
            label: 'Mapa',
          ),
          NavigationDestination(
            icon: Icon(Icons.campaign_outlined),
            selectedIcon: Icon(Icons.campaign_rounded),
            label: 'Reportar',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline_rounded),
            selectedIcon: Icon(Icons.person_rounded),
            label: 'Perfil',
          ),
        ],
      ),
    );
  }
}

class _AvisoDatosEjemplo extends StatelessWidget {
  const _AvisoDatosEjemplo();

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
    color: const Color(0xFFFFF5E3),
    child: const SafeArea(
      bottom: false,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.science_outlined, size: 16, color: Color(0xFF8A5A00)),
          SizedBox(width: 8),
          Text(
            'Datos de ejemplo',
            style: TextStyle(
              color: Color(0xFF8A5A00),
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    ),
  );
}
