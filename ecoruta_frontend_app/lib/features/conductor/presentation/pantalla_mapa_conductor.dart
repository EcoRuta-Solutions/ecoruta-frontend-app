import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/theme/app_theme.dart';
import '../data/modelos_conductor.dart';
import 'mis_rutas_controller.dart';

class PantallaMapaConductor extends ConsumerWidget {
  const PantallaMapaConductor({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rutas = ref.watch(misRutasControllerProvider);

    return rutas.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, _) => const Center(child: Text('No se pudo cargar el mapa')),
      data: (lista) {
        final ruta = rutaActivaDe(lista);
        if (ruta == null) {
          return const Center(child: Text('No tienes una ruta activa'));
        }
        final paradas = ruta.paradas.where((p) => p.nodo != null).toList();
        if (paradas.isEmpty) {
          return const Center(child: Text('La ruta no tiene paradas con ubicación'));
        }

        final puntos = [
          for (final parada in paradas)
            LatLng(parada.nodo!.latitud, parada.nodo!.longitud),
        ];

        return Stack(
          children: [
            FlutterMap(
              options: MapOptions(
                initialCenter: puntos.first,
                initialZoom: 13,
                interactionOptions: const InteractionOptions(
                  flags: InteractiveFlag.all,
                ),
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.ecoruta.app.ecoruta_frontend_app',
                ),
                if (puntos.length > 1)
                  PolylineLayer(
                    polylines: [
                      Polyline(
                        points: puntos,
                        strokeWidth: 4,
                        color: EcoColors.acento,
                      ),
                    ],
                  ),
                MarkerLayer(
                  markers: [
                    for (var i = 0; i < paradas.length; i++)
                      Marker(
                        point: puntos[i],
                        width: 44,
                        height: 44,
                        child: CircleAvatar(
                          backgroundColor: paradas[i].recolectado
                              ? const Color(0xFF30A46C)
                              : EcoColors.primario,
                          child: Text(
                            '${i + 1}',
                            style: const TextStyle(color: Colors.white),
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
            Positioned(
              left: 16,
              right: 16,
              top: 16,
              child: Card(
                child: ListTile(
                  leading: const Icon(
                    Icons.local_shipping_rounded,
                    color: EcoColors.primario,
                  ),
                  title: Text('Ruta #${ruta.id}'),
                  subtitle: Text(
                    '${ruta.paradasHechas}/${ruta.paradasTotal} paradas · '
                    '${etiquetaEstadoRuta(ruta.estado)}',
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
