import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../auth/presentation/auth_controller.dart';
import 'presentation/controladores_dominio.dart';
import 'presentation/pantalla_alertas.dart';
import 'presentation/pantalla_mapa.dart';
import 'presentation/pantalla_mas.dart';
import 'presentation/pantalla_panel.dart';
import 'presentation/pantalla_reportes.dart';
import 'presentation/pantalla_rutas.dart';
import 'presentation/navegacion_controller.dart';

class PantallaInicioMunicipalidad extends ConsumerWidget {
  const PantallaInicioMunicipalidad({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final navegacion = ref.watch(navegacionMunicipalidadProvider);
    final alertas =
        ref.watch(alertasControllerProvider).asData?.value ?? const [];
    final sinReconocer = alertas
        .where((alerta) => alerta.activaSinReconocer)
        .length;
    final destino = navegacion.destino;
    final informesSeleccionados =
        destino == DestinoMunicipalidad.mas &&
        navegacion.opcionMas == OpcionMasMunicipalidad.informes;
    final pantalla = switch (destino) {
      DestinoMunicipalidad.panel => const PantallaPanel(),
      DestinoMunicipalidad.mapa => const PantallaMapa(),
      DestinoMunicipalidad.alertas => const PantallaAlertas(),
      DestinoMunicipalidad.rutas => const PantallaRutas(),
      DestinoMunicipalidad.mas =>
        informesSeleccionados ? const PantallaReportes() : const PantallaMas(),
    };
    final indice = destino.index;
    final titulo = informesSeleccionados
        ? 'Informes'
        : destino == DestinoMunicipalidad.rutas
        ? 'Rutas'
        : 'Centro de control';

    return Scaffold(
      appBar: AppBar(
        backgroundColor: EcoColors.fondo,
        title: Text(titulo),
        actions: [
          IconButton(
            tooltip: 'Cerrar sesión',
            icon: const Icon(Icons.logout_rounded),
            onPressed: () => ref.read(authProvider.notifier).logout(),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 220),
        switchInCurve: Curves.easeOut,
        switchOutCurve: Curves.easeIn,
        transitionBuilder: (child, animation) =>
            FadeTransition(opacity: animation, child: child),
        child: KeyedSubtree(
          key: ValueKey((indice, navegacion.opcionMas)),
          child: pantalla,
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: indice,
        onDestinationSelected: (seleccion) => ref
            .read(navegacionMunicipalidadProvider.notifier)
            .seleccionar(DestinoMunicipalidad.values[seleccion]),
        destinations: [
          NavigationDestination(
            icon: const Icon(Icons.dashboard_outlined),
            selectedIcon: const Icon(Icons.dashboard_rounded),
            label: 'Panel',
          ),
          NavigationDestination(
            icon: const Icon(Icons.map_outlined),
            selectedIcon: const Icon(Icons.map_rounded),
            label: 'Mapa',
          ),
          NavigationDestination(
            icon: Badge(
              isLabelVisible: sinReconocer > 0,
              label: Text('$sinReconocer'),
              child: const Icon(Icons.notifications_none),
            ),
            selectedIcon: Badge(
              isLabelVisible: sinReconocer > 0,
              label: Text('$sinReconocer'),
              child: const Icon(Icons.notifications_rounded),
            ),
            label: 'Alertas',
          ),
          NavigationDestination(
            icon: const Icon(Icons.route_outlined),
            selectedIcon: const Icon(Icons.route_rounded),
            label: 'Rutas',
          ),
          NavigationDestination(
            icon: const Icon(Icons.more_horiz_rounded),
            selectedIcon: const Icon(Icons.more_horiz_rounded),
            label: 'Más',
          ),
        ],
      ),
    );
  }
}
