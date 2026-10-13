import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/config/app_config.dart';
import '../../core/theme/app_theme.dart';
import '../auth/presentation/auth_controller.dart';
import 'presentation/navegacion_ciudadano_controller.dart';
import 'presentation/pantalla_inicio_tab.dart';
import 'presentation/pantalla_mis_reportes.dart';
import 'presentation/pantalla_perfil_ciudadano.dart';
import 'presentation/pantalla_reportar_ciudadano.dart';

class PantallaInicioCiudadano extends ConsumerWidget {
  const PantallaInicioCiudadano({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final destino = ref.watch(navegacionCiudadanoProvider).destino;
    final pantalla = switch (destino) {
      DestinoCiudadano.inicio => const PantallaInicioCiudadanoTab(),
      DestinoCiudadano.reportar => const PantallaReportarCiudadano(),
      DestinoCiudadano.misReportes => const PantallaMisReportes(),
      DestinoCiudadano.perfil => const PantallaPerfilCiudadano(),
    };
    final titulo = switch (destino) {
      DestinoCiudadano.inicio => 'EcoRuta',
      DestinoCiudadano.reportar => 'Reportar',
      DestinoCiudadano.misReportes => 'Mis reportes',
      DestinoCiudadano.perfil => 'Mi perfil',
    };

    return Scaffold(
      appBar: AppBar(
        backgroundColor: EcoColors.fondo,
        title: Text(titulo),
        actions: [
          IconButton(
            tooltip: 'Cerrar sesión',
            constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
            icon: const Icon(Icons.logout_rounded),
            onPressed: () => ref.read(authProvider.notifier).logout(),
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
            .read(navegacionCiudadanoProvider.notifier)
            .seleccionar(DestinoCiudadano.values[seleccion]),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home_rounded),
            label: 'Inicio',
          ),
          NavigationDestination(
            icon: Icon(Icons.add_location_alt_outlined),
            selectedIcon: Icon(Icons.add_location_alt_rounded),
            label: 'Reportar',
          ),
          NavigationDestination(
            icon: Icon(Icons.receipt_long_outlined),
            selectedIcon: Icon(Icons.receipt_long_rounded),
            label: 'Mis reportes',
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
