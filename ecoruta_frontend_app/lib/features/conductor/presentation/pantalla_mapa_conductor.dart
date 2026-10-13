import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/theme/app_theme.dart';
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
        final ruta = rutaActivaDe(lista);
        if (ruta == null) {
          return const Center(child: Text('No tienes una ruta activa'));
        }
        final paradas = ruta.paradas
            .where((parada) => parada.nodo != null)
            .toList();
        if (paradas.isEmpty) {
          return const Center(
            child: Text('La ruta no tiene paradas con ubicación'),
          );
        }

        final puntos = [
          for (final parada in paradas)
            LatLng(parada.nodo!.latitud, parada.nodo!.longitud),
        ];
        final seleccionada = paradas.firstWhere(
          (parada) => parada.id == _paradaSeleccionadaId,
          orElse: () => paradas.first,
        );
        final nodoSeleccionado = seleccionada.nodo!;

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
                nodo: nodoSeleccionado,
                onComoLlegar: () => _comoLlegar(nodoSeleccionado),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _comoLlegar(NodoConductor nodo) async {
    final abierto = await abrirNavegacionExterna(nodo);
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
    required this.nodo,
    required this.onComoLlegar,
  });

  final ParadaConductor parada;
  final NodoConductor nodo;
  final VoidCallback onComoLlegar;

  @override
  Widget build(BuildContext context) {
    final detalles = [
      if (parada.horaEstimada != null)
        'Hora estimada ${_hora(parada.horaEstimada!)}',
      if (nodo.llenado != null) 'Llenado ${nodo.llenado!.round()}%',
      if (nodo.prioridad != null) 'Prioridad ${nodo.prioridad}',
    ];

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
            if (detalles.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(detalles.join(' · ')),
            ],
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: semanticaBotonConductor(
                etiqueta: 'Cómo llegar a ${nodo.nombre}',
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

String _hora(DateTime fecha) =>
    '${fecha.hour.toString().padLeft(2, '0')}:'
    '${fecha.minute.toString().padLeft(2, '0')}';
