import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import 'pantalla_contenedores.dart';
import 'pantalla_reportes_ciudadanos.dart';
import 'pantalla_usuarios_flota.dart';
import 'navegacion_controller.dart';

class PantallaMas extends ConsumerWidget {
  const PantallaMas({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final navegacion = ref.watch(navegacionMunicipalidadProvider);
    final opcion = navegacion.opcionMas;
    if (opcion != null) {
      final pantalla = switch (opcion) {
        OpcionMasMunicipalidad.contenedores => const PantallaContenedores(),
        OpcionMasMunicipalidad.reportesCiudadanos =>
          const PantallaReportesCiudadanos(),
        OpcionMasMunicipalidad.usuariosYFlota => const PantallaUsuariosFlota(),
        OpcionMasMunicipalidad.informes => _PantallaModuloPendiente(
          titulo: _etiqueta(opcion),
          onBack: ref.read(navegacionMunicipalidadProvider.notifier).volverAMas,
        ),
      };
      return Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: EcoLayout.anchoContenido),
          child: Column(
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: ref
                      .read(navegacionMunicipalidadProvider.notifier)
                      .volverAMas,
                  icon: const Icon(Icons.arrow_back_rounded),
                  label: const Text('Más'),
                ),
              ),
              Expanded(child: pantalla),
            ],
          ),
        ),
      );
    }

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: EcoLayout.anchoContenido),
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Text(
              'Más herramientas',
              style: Theme.of(context).textTheme.headlineMedium
                  ?.copyWith(color: EcoColors.primario),
            ),
            const SizedBox(height: 24),
            for (final opcion in OpcionMasMunicipalidad.values)
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Card(
                  clipBehavior: Clip.antiAlias,
                  child: ListTile(
                    minTileHeight: 72,
                    leading: Icon(
                      _icono(opcion),
                      color: EcoColors.primario,
                      size: 24,
                    ),
                    title: Text(_etiqueta(opcion)),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () => ref
                        .read(navegacionMunicipalidadProvider.notifier)
                        .abrirOpcion(opcion),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _PantallaModuloPendiente extends StatelessWidget {
  const _PantallaModuloPendiente({required this.titulo, required this.onBack});

  final String titulo;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: EcoLayout.anchoContenido),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.construction_outlined,
                size: 40,
                color: EcoColors.textoSecundario,
              ),
              const SizedBox(height: 16),
              Text(
                titulo,
                style: Theme.of(context).textTheme.titleLarge
                    ?.copyWith(color: EcoColors.primario),
              ),
              const SizedBox(height: 8),
              Text(
                'Esta sección se está preparando.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium
                    ?.copyWith(color: EcoColors.textoSecundario),
              ),
              const SizedBox(height: 24),
              OutlinedButton.icon(
                onPressed: onBack,
                icon: const Icon(Icons.arrow_back_rounded),
                label: const Text('Volver a Más'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String _etiqueta(OpcionMasMunicipalidad opcion) => switch (opcion) {
  OpcionMasMunicipalidad.contenedores => 'Contenedores',
  OpcionMasMunicipalidad.reportesCiudadanos => 'Reportes ciudadanos',
  OpcionMasMunicipalidad.usuariosYFlota => 'Usuarios y flota',
  OpcionMasMunicipalidad.informes => 'Informes',
};

IconData _icono(OpcionMasMunicipalidad opcion) => switch (opcion) {
  OpcionMasMunicipalidad.contenedores => Icons.delete_outline_rounded,
  OpcionMasMunicipalidad.reportesCiudadanos => Icons.campaign_outlined,
  OpcionMasMunicipalidad.usuariosYFlota => Icons.groups_outlined,
  OpcionMasMunicipalidad.informes => Icons.assessment_outlined,
};
