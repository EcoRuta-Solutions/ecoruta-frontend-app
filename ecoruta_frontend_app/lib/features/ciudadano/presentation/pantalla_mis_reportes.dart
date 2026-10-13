import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/theme/app_theme.dart';
import 'estado_visual_ciudadano.dart';
import 'mis_reportes_controller.dart';

class PantallaMisReportes extends ConsumerWidget {
  const PantallaMisReportes({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reportesAsync = ref.watch(misReportesControllerProvider);

    return reportesAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.cloud_off_rounded, size: 40),
              const SizedBox(height: 12),
              Text(
                error is StateError
                    ? error.message.toString()
                    : 'No se pudieron cargar tus reportes.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: () =>
                    ref.read(misReportesControllerProvider.notifier).recargar(),
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Reintentar'),
              ),
            ],
          ),
        ),
      ),
      data: (reportes) => RefreshIndicator(
        onRefresh: () =>
            ref.read(misReportesControllerProvider.notifier).recargar(),
        child: reportes.isEmpty
            ? ListView(
                children: const [
                  SizedBox(height: 80),
                  Icon(Icons.receipt_long_rounded, size: 48),
                  SizedBox(height: 12),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 32),
                    child: Text(
                      'Aún no has enviado reportes.\nUsa la pestaña "Reportar".',
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              )
            : ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Card(
                    clipBehavior: Clip.antiAlias,
                    child: SizedBox(
                      height: 220,
                      child: FlutterMap(
                        options: MapOptions(
                          initialCenter: LatLng(
                            reportes.first.latitud,
                            reportes.first.longitud,
                          ),
                          initialZoom: 14,
                          interactionOptions: const InteractionOptions(
                            flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
                          ),
                        ),
                        children: [
                          TileLayer(
                            urlTemplate:
                                'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                            userAgentPackageName:
                                'com.ecoruta.app.ecoruta_frontend_app',
                          ),
                          MarkerLayer(
                            markers: [
                              for (final reporte in reportes)
                                Marker(
                                  point: LatLng(
                                    reporte.latitud,
                                    reporte.longitud,
                                  ),
                                  width: 40,
                                  height: 40,
                                  child: Icon(
                                    Icons.location_on_rounded,
                                    size: 36,
                                    color: visualReporteCiudadano(
                                      context,
                                      reporte.estado,
                                    ).color,
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  for (final reporte in reportes)
                    Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    formatearFechaCorta(reporte.fecha),
                                    style: Theme.of(context)
                                        .textTheme
                                        .labelMedium
                                        ?.copyWith(
                                          color: EcoColors.textoSecundario,
                                        ),
                                  ),
                                ),
                                ChipEstadoReporte(estado: reporte.estado),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(reporte.descripcion),
                            if (reporte.asignadoA != null) ...[
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  const Icon(
                                    Icons.engineering_rounded,
                                    size: 16,
                                    color: EcoColors.textoSecundario,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    'Asignado a ${reporte.asignadoA}',
                                    style: Theme.of(context)
                                        .textTheme
                                        .labelMedium
                                        ?.copyWith(
                                          color: EcoColors.textoSecundario,
                                        ),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                ],
              ),
      ),
    );
  }
}
