import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/theme/app_theme.dart';
import '../../municipalidad/presentation/widgets/visual_llenado.dart';
import '../data/modelos_conductor.dart';
import 'accesibilidad_conductor.dart';
import 'error_conductor.dart';
import 'mis_rutas_controller.dart';
import 'navegacion_externa.dart';

class PantallaMapaConductor extends ConsumerStatefulWidget {
  const PantallaMapaConductor({super.key});

  @override
  ConsumerState<PantallaMapaConductor> createState() =>
      _PantallaMapaConductorState();
}

class _PantallaMapaConductorState extends ConsumerState<PantallaMapaConductor> {
  int? _paradaSeleccionadaId;

  @override
  Widget build(BuildContext context) {
    final rutas = ref.watch(misRutasControllerProvider);

    return rutas.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) {
        registrarErrorCargaConductor(error);
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.cloud_off_rounded, size: 40),
                const SizedBox(height: 16),
                Text(
                  mensajeErrorCargaConductor(error),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                semanticaBotonConductor(
                  etiqueta: 'Reintentar carga de rutas para el mapa',
                  child: FilledButton.icon(
                    style: estiloBotonConductor,
                    onPressed: () => ref
                        .read(misRutasControllerProvider.notifier)
                        .recargar(),
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text('Reintentar'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
      data: (lista) {
        final ruta = rutaDeHoy(lista, ref.watch(relojConductorProvider)());
        if (ruta == null) {
          return const Center(
            child: Text('Aún no tienes una ruta asignada para hoy'),
          );
        }
        // Ordenadas por `orden`, con la ubicación del punto crítico.
        final paradas = ruta.paradas
            .where((parada) => parada.tieneUbicacion)
            .toList();
        if (paradas.isEmpty) {
          return const Center(
            child: Text('La ruta no tiene paradas con ubicación'),
          );
        }

        final puntos = [
          for (final parada in paradas)
            LatLng(parada.latitud!, parada.longitud!),
        ];
        final seleccionada = paradas.firstWhere(
          (parada) => parada.id == _paradaSeleccionadaId,
          orElse: () => paradas.first,
        );

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
                        width: 48,
                        height: 48,
                        child: Semantics(
                          button: true,
                          selected: paradas[i].id == seleccionada.id,
                          label:
                              'Parada ${paradas[i].orden}: '
                              '${paradas[i].titulo}',
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              customBorder: const CircleBorder(),
                              onTap: () => setState(
                                () => _paradaSeleccionadaId = paradas[i].id,
                              ),
                              child: CircleAvatar(
                                backgroundColor: paradas[i].recolectado
                                    ? const Color(0xFF30A46C)
                                    : EcoColors.primario,
                                child: Text(
                                  '${paradas[i].orden}',
                                  style: const TextStyle(color: Colors.white),
                                ),
                              ),
                            ),
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
            Positioned(
              left: 16,
              right: 16,
              bottom: 16,
              child: _DetalleParadaSeleccionada(
                parada: seleccionada,
                onComoLlegar: () => _comoLlegar(seleccionada),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _comoLlegar(ParadaConductor parada) async {
    final abierto = await abrirNavegacionParada(parada);
    if (!mounted || abierto) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(content: Text('No se pudo abrir la navegación.')),
      );
  }
}

class _DetalleParadaSeleccionada extends StatelessWidget {
  const _DetalleParadaSeleccionada({
    required this.parada,
    required this.onComoLlegar,
  });

  final ParadaConductor parada;
  final VoidCallback onComoLlegar;

  @override
  Widget build(BuildContext context) {
    final referencia = parada.puntoCritico?.referencia;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Parada ${parada.orden}: ${parada.titulo}',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            if (referencia != null) ...[
              const SizedBox(height: 4),
              Text('Referencia: $referencia'),
            ],
            const SizedBox(height: 8),
            ChipLlenado(nivel: parada.estadoLlenado),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: semanticaBotonConductor(
                etiqueta: 'Cómo llegar a ${parada.codigo}',
                child: FilledButton.icon(
                  style: estiloBotonConductor,
                  onPressed: onComoLlegar,
                  icon: const Icon(Icons.directions_rounded),
                  label: const Text('Cómo llegar'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
