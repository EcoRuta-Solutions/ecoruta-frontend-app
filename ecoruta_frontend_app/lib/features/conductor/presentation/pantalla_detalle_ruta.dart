import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/theme/app_theme.dart';
import '../data/modelos_conductor.dart';
import 'accesibilidad_conductor.dart';
import 'mis_rutas_controller.dart';
import 'tarjeta_parada_conductor.dart';

const _centroTrujillo = LatLng(-8.1116, -79.0288);

class PantallaDetalleRuta extends ConsumerWidget {
  const PantallaDetalleRuta({required this.idRuta, super.key});

  final int idRuta;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detalle = ref.watch(detalleRutaProvider(idRuta));

    return Scaffold(
      appBar: AppBar(title: Text('Ruta #$idRuta')),
      body: detalle.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => Center(
          child: semanticaBotonConductor(
            etiqueta: 'Reintentar carga del detalle de ruta',
            child: FilledButton.icon(
              style: estiloBotonConductor,
              onPressed: () => ref.invalidate(detalleRutaProvider(idRuta)),
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Reintentar'),
            ),
          ),
        ),
        data: (ruta) => RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(detalleRutaProvider(idRuta));
            await ref.read(detalleRutaProvider(idRuta).future);
          },
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            children: [
              _ResumenRuta(ruta: ruta),
              const SizedBox(height: 16),
              _MapaRuta(ruta: ruta),
              const SizedBox(height: 16),
              _ListaParadas(ruta: ruta),
              const SizedBox(height: 16),
              _AccionesRuta(ruta: ruta),
            ],
          ),
        ),
      ),
    );
  }
}

class _ResumenRuta extends StatelessWidget {
  const _ResumenRuta({required this.ruta});

  final RutaConductor ruta;

  @override
  Widget build(BuildContext context) {
    final visual = Theme.of(context)
        .extension<ColoresProceso>()!
        .para(_estadoProcesoConductor(ruta.estado));

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    ruta.camion == null ? 'Ruta' : ruta.camion!.placa,
                    style: Theme.of(context).textTheme.titleLarge
                        ?.copyWith(color: EcoColors.primario),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: visual.fondo,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(visual.icono, size: 16, color: visual.color),
                      const SizedBox(width: 8),
                      Text(
                        etiquetaEstadoRuta(ruta.estado),
                        style: TextStyle(color: visual.color),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              [
                'Turno ${ruta.turnoTexto}',
                if (ruta.distanciaKm != null)
                  '${ruta.distanciaKm!.toStringAsFixed(1)} km',
                if (ruta.tiempoEstimadoMin != null)
                  '${ruta.tiempoEstimadoMin!.round()} min estimados',
                if (ruta.metodoDistancia == metodoDistanciaAproximada)
                  'distancias aproximadas',
              ].join(' · '),
              style: Theme.of(context).textTheme.bodyMedium
                  ?.copyWith(color: EcoColors.textoSecundario),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 20,
              runSpacing: 12,
              children: [
                _Dato(
                  icono: Icons.event_outlined,
                  texto: _fecha(ruta.fechaInicio),
                ),
                _Dato(
                  icono: Icons.schedule_outlined,
                  texto: '${_hora(ruta.horaInicio)} - ${_hora(ruta.horaFin)}',
                ),
                _Dato(
                  icono: Icons.task_alt_rounded,
                  texto: '${ruta.paradasHechas}/${ruta.paradasTotal} paradas',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _MapaRuta extends StatelessWidget {
  const _MapaRuta({required this.ruta});

  final RutaConductor ruta;

  @override
  Widget build(BuildContext context) {
    // Ordenadas por `orden`; se dibujan con la ubicación del punto crítico.
    final paradas = ruta.paradas.where((p) => p.tieneUbicacion).toList();
    if (paradas.isEmpty) return const SizedBox.shrink();

    final puntos = [
      for (final parada in paradas) LatLng(parada.latitud!, parada.longitud!),
    ];

    return Card(
      clipBehavior: Clip.antiAlias,
      child: SizedBox(
        height: 280,
        child: FlutterMap(
          options: MapOptions(
            initialCenter: puntos.isEmpty ? _centroTrujillo : puntos.first,
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
                        '${paradas[i].orden}',
                        style: const TextStyle(color: Colors.white),
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ListaParadas extends ConsumerWidget {
  const _ListaParadas({required this.ruta});

  final RutaConductor ruta;

  @override
  Widget build(BuildContext context, WidgetRef ref) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
        child: Text(
          'Paradas',
          style: Theme.of(context).textTheme.titleMedium
              ?.copyWith(color: EcoColors.primario),
        ),
      ),
      if (ruta.paradas.isEmpty)
        const Card(
          child: Padding(
            padding: EdgeInsets.all(16),
            child: Text('Esta ruta aún no tiene paradas.'),
          ),
        )
      else
        for (final parada in ruta.paradas)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: TarjetaParadaConductor(
              ruta: ruta,
              parada: parada,
              alCambiar: () => ref.invalidate(detalleRutaProvider(ruta.id)),
            ),
          ),
    ],
  );
}

class _AccionesRuta extends ConsumerWidget {
  const _AccionesRuta({required this.ruta});

  final RutaConductor ruta;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(misRutasControllerProvider.notifier);

    Future<void> cambiar(EstadoRutaConductor estado, String mensaje) async {
      try {
        await controller.cambiarEstado(ruta.id, estado);
        ref.invalidate(detalleRutaProvider(ruta.id));
        if (context.mounted) _mostrarMensaje(context, mensaje);
      } catch (_) {
        if (context.mounted) {
          _mostrarMensaje(context, 'No se pudo actualizar la ruta.');
        }
      }
    }

    Future<void> confirmarCancelacion() async {
      final confirmar = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Cancelar ruta'),
          content: const Text(
            '¿Quieres cancelar esta ruta? Esta acción actualizará su estado.',
          ),
          actions: [
            semanticaBotonConductor(
              etiqueta: 'Volver sin cancelar la ruta',
              child: TextButton(
                style: estiloBotonConductor,
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Volver'),
              ),
            ),
            semanticaBotonConductor(
              etiqueta: 'Confirmar cancelación de ruta',
              child: FilledButton(
                style: estiloBotonConductor,
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Cancelar ruta'),
              ),
            ),
          ],
        ),
      );
      if (confirmar == true && context.mounted) {
        await cambiar(EstadoRutaConductor.cancelado, 'Ruta cancelada.');
      }
    }

    return switch (ruta.estado) {
      EstadoRutaConductor.pendiente => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          semanticaBotonConductor(
            etiqueta: 'Iniciar ruta',
            child: FilledButton.icon(
              style: estiloBotonConductor,
              onPressed: () =>
                  cambiar(EstadoRutaConductor.enProceso, 'Ruta iniciada.'),
              icon: const Icon(Icons.play_arrow_rounded),
              label: const Text('Iniciar ruta'),
            ),
          ),
          const SizedBox(height: 8),
          semanticaBotonConductor(
            etiqueta: 'Cancelar ruta',
            child: OutlinedButton.icon(
              style: estiloBotonConductor,
              onPressed: confirmarCancelacion,
              icon: const Icon(Icons.cancel_outlined),
              label: const Text('Cancelar ruta'),
            ),
          ),
        ],
      ),
      EstadoRutaConductor.enProceso => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          semanticaBotonConductor(
            etiqueta: 'Finalizar ruta',
            child: FilledButton.icon(
              style: estiloBotonConductor,
              onPressed: () =>
                  cambiar(EstadoRutaConductor.completado, 'Ruta finalizada.'),
              icon: const Icon(Icons.check_rounded),
              label: const Text('Finalizar ruta'),
            ),
          ),
          const SizedBox(height: 8),
          semanticaBotonConductor(
            etiqueta: 'Cancelar ruta',
            child: OutlinedButton.icon(
              style: estiloBotonConductor,
              onPressed: confirmarCancelacion,
              icon: const Icon(Icons.cancel_outlined),
              label: const Text('Cancelar ruta'),
            ),
          ),
        ],
      ),
      EstadoRutaConductor.completado ||
      EstadoRutaConductor.cancelado => const SizedBox.shrink(),
    };
  }
}

class _Dato extends StatelessWidget {
  const _Dato({required this.icono, required this.texto});

  final IconData icono;
  final String texto;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(icono, size: 18, color: EcoColors.textoSecundario),
      const SizedBox(width: 8),
      Text(
        texto,
        style: Theme.of(context).textTheme.labelMedium
            ?.copyWith(color: EcoColors.textoSecundario),
      ),
    ],
  );
}

EstadoProcesoPanel _estadoProcesoConductor(EstadoRutaConductor estado) =>
    switch (estado) {
      EstadoRutaConductor.pendiente => EstadoProcesoPanel.asignada,
      EstadoRutaConductor.enProceso => EstadoProcesoPanel.enCurso,
      EstadoRutaConductor.completado => EstadoProcesoPanel.completada,
      EstadoRutaConductor.cancelado => EstadoProcesoPanel.inactivo,
    };

String _hora(DateTime fecha) =>
    '${fecha.hour.toString().padLeft(2, '0')}:'
    '${fecha.minute.toString().padLeft(2, '0')}';

String _fecha(DateTime fecha) =>
    '${fecha.day.toString().padLeft(2, '0')}/'
    '${fecha.month.toString().padLeft(2, '0')}/${fecha.year}';

void _mostrarMensaje(BuildContext context, String mensaje) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(mensaje)));
}
