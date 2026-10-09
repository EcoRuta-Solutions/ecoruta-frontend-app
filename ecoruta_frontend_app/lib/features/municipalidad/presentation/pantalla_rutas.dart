import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/theme/app_theme.dart';
import '../data/modelos_flota.dart';
import '../data/modelos_panel.dart';
import '../data/modelos_ruta.dart';
import 'controladores_dominio.dart';
import 'panel_controller.dart';
import 'widgets/estados_panel.dart';

const _maximoAnchoRutas = 920.0;
const _centroTrujillo = LatLng(-8.1116, -79.0288);

class PantallaRutas extends ConsumerWidget {
  const PantallaRutas({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rutas = ref.watch(rutasControllerProvider);
    final ancho = MediaQuery.sizeOf(context).width;
    final margen = ancho < EcoLayout.anchoCompacto ? 16.0 : 24.0;
    return rutas.when(
      loading: () => _lista(ref, margen, const [
        SliverToBoxAdapter(child: EsqueletoPanel()),
      ]),
      error: (error, stackTrace) => _lista(ref, margen, [
        SliverToBoxAdapter(
          child: ErrorPanel(
            onRetry: () => ref.invalidate(rutasControllerProvider),
          ),
        ),
      ]),
      data: (datos) => _lista(ref, margen, [
        SliverPadding(
          padding: const EdgeInsets.only(bottom: 24),
          sliver: SliverToBoxAdapter(
            child: Text(
              'Rutas de recolección',
              style: Theme.of(context).textTheme.headlineMedium
                  ?.copyWith(color: EcoColors.primario),
            ),
          ),
        ),
        if (datos.isEmpty)
          const SliverToBoxAdapter(
            child: _VacioRutas(mensaje: 'Aún no hay rutas para mostrar.'),
          )
        else
          SliverList.builder(
            itemCount: datos.length,
            itemBuilder: (context, index) => _TarjetaRuta(ruta: datos[index]),
          ),
      ]),
    );
  }

  Widget _lista(WidgetRef ref, double margen, List<Widget> slivers) => Center(
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: _maximoAnchoRutas),
      child: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(rutasControllerProvider);
          await ref.read(rutasControllerProvider.future);
        },
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverPadding(
              padding: EdgeInsets.fromLTRB(margen, 24, margen, 32),
              sliver: SliverMainAxisGroup(slivers: slivers),
            ),
          ],
        ),
      ),
    ),
  );
}

class _TarjetaRuta extends StatelessWidget {
  const _TarjetaRuta({required this.ruta});
  final RutaMunicipal ruta;

  @override
  Widget build(BuildContext context) {
    final visual = Theme.of(context)
        .extension<ColoresProceso>()!
        .para(_estadoProcesoRuta(ruta.estado));
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => PantallaDetalleRuta(rutaId: ruta.id),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        ruta.nombre,
                        style: Theme.of(context).textTheme.titleLarge
                            ?.copyWith(color: EcoColors.primario),
                      ),
                    ),
                    _ChipEstadoRuta(estado: ruta.estado),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  '${ruta.id} · ${ruta.zona}',
                  style: Theme.of(context).textTheme.bodyMedium
                      ?.copyWith(color: EcoColors.textoSecundario),
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 20,
                  runSpacing: 12,
                  children: [
                    _DatoRuta(
                      icono: Icons.person_outline,
                      texto: _asignacion(ruta.conductorId, 'Conductor'),
                    ),
                    _DatoRuta(
                      icono: Icons.local_shipping_outlined,
                      texto: _asignacion(ruta.vehiculoId, 'Vehículo'),
                    ),
                    _DatoRuta(
                      icono: Icons.route_outlined,
                      texto: '${ruta.distanciaKm.toStringAsFixed(1)} km',
                    ),
                    _DatoRuta(
                      icono: Icons.schedule_outlined,
                      texto: '${ruta.duracionMin} min',
                    ),
                    _DatoRuta(
                      icono: Icons.location_on_outlined,
                      texto: '${ruta.paradas.length} paradas',
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Icon(visual.icono, size: 18, color: visual.color),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Ahorro ${ruta.ahorroKmPorcentaje.toStringAsFixed(1)}% '
                        'frente a la ruta fija',
                        style: Theme.of(context).textTheme.labelMedium
                            ?.copyWith(color: visual.color),
                      ),
                    ),
                    const Icon(Icons.chevron_right_rounded),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class PantallaDetalleRuta extends ConsumerWidget {
  const PantallaDetalleRuta({required this.rutaId, super.key});

  final String rutaId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rutas = ref.watch(rutasControllerProvider);
    final panel = ref.watch(panelControllerProvider);
    final flota = ref.watch(flotaControllerProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Detalle de ruta')),
      body: rutas.isLoading || panel.isLoading || flota.isLoading
          ? const _CargaRuta()
          : rutas.hasError || panel.hasError || flota.hasError
          ? Center(
              child: ErrorPanel(
                onRetry: () {
                  ref.invalidate(rutasControllerProvider);
                  ref.invalidate(panelControllerProvider);
                  ref.invalidate(flotaControllerProvider);
                },
              ),
            )
          : rutas.when(
              loading: () => const _CargaRuta(),
              error: (error, stackTrace) => const SizedBox.shrink(),
              data: (listaRutas) {
                final ruta = listaRutas
                    .where((item) => item.id == rutaId)
                    .firstOrNull;
                if (ruta == null) {
                  return const _VacioRutas(
                    mensaje: 'No encontramos esta ruta.',
                  );
                }
                final nodos = panel.requireValue.nodos;
                final datosFlota = flota.requireValue;
                final ancho = MediaQuery.sizeOf(context).width;
                return RefreshIndicator(
                  onRefresh: () async {
                    ref.invalidate(rutasControllerProvider);
                    await ref.read(rutasControllerProvider.future);
                  },
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(
                        maxWidth: _maximoAnchoRutas,
                      ),
                      child: ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: EdgeInsets.fromLTRB(
                          ancho < EcoLayout.anchoCompacto ? 16 : 24,
                          24,
                          ancho < EcoLayout.anchoCompacto ? 16 : 24,
                          32,
                        ),
                        children: [
                          _ResumenRuta(ruta: ruta),
                          const SizedBox(height: 16),
                          _MapaRuta(ruta: ruta, nodos: nodos),
                          const SizedBox(height: 16),
                          _ComparacionRuta(ruta: ruta),
                          const SizedBox(height: 16),
                          _ParadasRuta(ruta: ruta, nodos: nodos),
                          const SizedBox(height: 16),
                          _HistorialRuta(ruta: ruta),
                          const SizedBox(height: 16),
                          _AccionesRuta(ruta: ruta, flota: datosFlota),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
    );
  }
}

class _ResumenRuta extends StatelessWidget {
  const _ResumenRuta({required this.ruta});
  final RutaMunicipal ruta;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            ruta.nombre,
            style: Theme.of(context).textTheme.titleLarge
                ?.copyWith(color: EcoColors.primario),
          ),
          const SizedBox(height: 8),
          Text('${ruta.id} · ${ruta.zona}'),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _ChipEstadoRuta(estado: ruta.estado),
              _DatoRuta(
                icono: Icons.route_outlined,
                texto: '${ruta.distanciaKm.toStringAsFixed(1)} km',
              ),
              _DatoRuta(
                icono: Icons.schedule_outlined,
                texto: '${ruta.duracionMin} min',
              ),
            ],
          ),
        ],
      ),
    ),
  );
}

class _MapaRuta extends StatelessWidget {
  const _MapaRuta({required this.ruta, required this.nodos});
  final RutaMunicipal ruta;
  final List<NodoEstado> nodos;

  @override
  Widget build(BuildContext context) {
    final paradas = [...ruta.paradas]
      ..sort((a, b) => a.orden.compareTo(b.orden));
    final nodosParada = [
      for (final parada in paradas)
        for (final nodo in nodos)
          if (nodo.id == parada.nodoId &&
              nodo.latitud != null &&
              nodo.longitud != null)
            nodo,
    ];
    final puntos = [
      for (final nodo in nodosParada) LatLng(nodo.latitud!, nodo.longitud!),
    ];
    return Card(
      clipBehavior: Clip.antiAlias,
      child: SizedBox(
        height: 260,
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
              errorTileCallback: (_, error, _) {
                debugPrint('No se pudo cargar una tesela de ruta: $error');
              },
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
                for (var indice = 0; indice < nodosParada.length; indice++)
                  Marker(
                    point: puntos[indice],
                    width: 44,
                    height: 44,
                    child: Semantics(
                      label:
                          'Parada ${indice + 1}: ${nodosParada[indice].codigo}',
                      child: CircleAvatar(
                        backgroundColor: EcoColors.primario,
                        child: Text(
                          '${indice + 1}',
                          style: const TextStyle(color: Colors.white),
                        ),
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

class _ComparacionRuta extends StatelessWidget {
  const _ComparacionRuta({required this.ruta});
  final RutaMunicipal ruta;

  @override
  Widget build(BuildContext context) {
    final proceso = Theme.of(context).extension<ColoresProceso>()!;
    final ahorroTiempo = ruta.duracionFijaMin == 0
        ? 0.0
        : (ruta.duracionFijaMin - ruta.duracionMin) /
              ruta.duracionFijaMin *
              100;
    final ahorroParadas = ruta.paradasFijas == 0
        ? 0.0
        : (ruta.paradasFijas - ruta.paradas.length) / ruta.paradasFijas * 100;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Ruta optimizada vs. ruta fija',
              style: Theme.of(context).textTheme.titleMedium
                  ?.copyWith(color: EcoColors.primario),
            ),
            const SizedBox(height: 16),
            for (final dato in [
              (
                'Distancia',
                '${ruta.distanciaKm.toStringAsFixed(1)} km',
                '${ruta.distanciaFijaKm.toStringAsFixed(1)} km',
              ),
              (
                'Duración',
                '${ruta.duracionMin} min',
                '${ruta.duracionFijaMin} min',
              ),
              ('Paradas', '${ruta.paradas.length}', '${ruta.paradasFijas}'),
            ])
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  children: [
                    Expanded(child: Text(dato.$1)),
                    Text(
                      dato.$2,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(width: 16),
                    Text(
                      dato.$3,
                      style: const TextStyle(color: EcoColors.textoSecundario),
                    ),
                  ],
                ),
              ),
            const Divider(),
            Wrap(
              spacing: 16,
              runSpacing: 8,
              children: [
                _AhorroChip(
                  etiqueta: 'Km',
                  valor: ruta.ahorroKmPorcentaje,
                  visual: proceso.para(EstadoProcesoPanel.completada),
                ),
                _AhorroChip(
                  etiqueta: 'Tiempo',
                  valor: ahorroTiempo,
                  visual: proceso.para(EstadoProcesoPanel.enCurso),
                ),
                _AhorroChip(
                  etiqueta: 'Paradas',
                  valor: ahorroParadas,
                  visual: proceso.para(EstadoProcesoPanel.aprobada),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _AhorroChip extends StatelessWidget {
  const _AhorroChip({
    required this.etiqueta,
    required this.valor,
    required this.visual,
  });

  final String etiqueta;
  final double valor;
  final EstadoVisual visual;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
          '$etiqueta ${valor.toStringAsFixed(1)}% de ahorro',
          style: TextStyle(color: visual.color),
        ),
      ],
    ),
  );
}

class _ParadasRuta extends StatelessWidget {
  const _ParadasRuta({required this.ruta, required this.nodos});
  final RutaMunicipal ruta;
  final List<NodoEstado> nodos;

  @override
  Widget build(BuildContext context) {
    final paradas = [...ruta.paradas]
      ..sort((a, b) => a.orden.compareTo(b.orden));
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Paradas',
              style: Theme.of(context).textTheme.titleMedium
                  ?.copyWith(color: EcoColors.primario),
            ),
            const SizedBox(height: 8),
            if (paradas.isEmpty)
              const Text('Esta ruta aún no tiene paradas.')
            else
              for (final parada in paradas)
                _FilaParada(
                  parada: parada,
                  nodo: nodos
                      .where((nodo) => nodo.id == parada.nodoId)
                      .firstOrNull,
                ),
          ],
        ),
      ),
    );
  }
}

class _FilaParada extends StatelessWidget {
  const _FilaParada({required this.parada, required this.nodo});

  final ParadaRuta parada;
  final NodoEstado? nodo;

  @override
  Widget build(BuildContext context) => ListTile(
    contentPadding: EdgeInsets.zero,
    leading: CircleAvatar(
      backgroundColor: EcoColors.acento.withValues(alpha: 0.12),
      child: Text('${parada.orden}'),
    ),
    title: Text(nodo?.nombre ?? 'Nodo ${parada.nodoId}'),
    subtitle: Text(
      '${nodo?.codigo ?? 'Sin código'} · Llenado esperado: '
      '${nodo?.llenado == null ? '—' : '${nodo!.llenado!.round()}%'}',
    ),
    trailing: Text(
      '${parada.horaEstimada.hour.toString().padLeft(2, '0')}:'
      '${parada.horaEstimada.minute.toString().padLeft(2, '0')}',
    ),
  );
}

class _HistorialRuta extends StatelessWidget {
  const _HistorialRuta({required this.ruta});
  final RutaMunicipal ruta;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Historial de cambios',
            style: Theme.of(context).textTheme.titleMedium
                ?.copyWith(color: EcoColors.primario),
          ),
          const SizedBox(height: 8),
          if (ruta.historial.isEmpty)
            const Text('Aún no hay cambios registrados.')
          else
            for (final accion in ruta.historial.reversed)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.history_rounded),
                title: Text(accion.que),
                subtitle: Text(
                  '${accion.quien} · ${accion.cuando.day}/${accion.cuando.month}',
                ),
              ),
        ],
      ),
    ),
  );
}

class _AccionesRuta extends ConsumerWidget {
  const _AccionesRuta({required this.ruta, required this.flota});
  final RutaMunicipal ruta;
  final DatosFlota? flota;

  @override
  Widget build(BuildContext context, WidgetRef ref) => Wrap(
    spacing: 8,
    runSpacing: 8,
    children: [
      if (ruta.estado == EstadoRuta.propuesta)
        FilledButton.icon(
          onPressed: () => _accionRuta(
            context,
            () => ref
                .read(rutasControllerProvider.notifier)
                .aprobar(ruta.id, quien: 'Supervisor municipal'),
            'Ruta aprobada.',
          ),
          icon: const Icon(Icons.check_rounded),
          label: const Text('Aprobar ruta'),
        ),
      OutlinedButton.icon(
        onPressed: flota == null
            ? null
            : () => _elegirAsignacion(context, ref, ruta, flota!),
        icon: const Icon(Icons.swap_horiz_rounded),
        label: const Text('Reasignar'),
      ),
    ],
  );
}

Future<void> _elegirAsignacion(
  BuildContext context,
  WidgetRef ref,
  RutaMunicipal ruta,
  DatosFlota flota,
) async {
  final opciones = [
    for (final conductor in flota.conductores)
      if (conductor.estado == EstadoConductor.disponible)
        for (final vehiculo in flota.vehiculos)
          if (vehiculo.estado == EstadoVehiculo.operativo &&
              (conductor.vehiculoAsignado == null ||
                  conductor.vehiculoAsignado == vehiculo.id))
            (conductor: conductor, vehiculo: vehiculo),
  ];
  if (opciones.isEmpty) {
    _mostrarMensaje(context, 'No hay conductores ni vehículos disponibles.');
    return;
  }
  final seleccion =
      await showDialog<({Conductor conductor, Vehiculo vehiculo})>(
        context: context,
        builder: (context) => SimpleDialog(
          title: const Text('Reasignar ruta'),
          children: [
            for (final opcion in opciones)
              SimpleDialogOption(
                onPressed: () => Navigator.pop(context, opcion),
                child: ListTile(
                  title: Text(opcion.conductor.nombre),
                  subtitle: Text(
                    '${opcion.vehiculo.placa} · ${opcion.vehiculo.tipo}',
                  ),
                ),
              ),
          ],
        ),
      );
  if (seleccion == null || !context.mounted) return;
  await _accionRuta(
    context,
    () => ref
        .read(rutasControllerProvider.notifier)
        .reasignar(
          ruta.id,
          conductor: seleccion.conductor,
          vehiculo: seleccion.vehiculo,
          quien: 'Supervisor municipal',
        ),
    'Ruta reasignada.',
  );
}

Future<void> _accionRuta(
  BuildContext context,
  Future<void> Function() accion,
  String confirmacion,
) async {
  try {
    await accion();
    if (context.mounted) _mostrarMensaje(context, confirmacion);
  } on StateError catch (error) {
    if (context.mounted) _mostrarMensaje(context, error.message.toString());
  }
}

class _ChipEstadoRuta extends StatelessWidget {
  const _ChipEstadoRuta({required this.estado});
  final EstadoRuta estado;

  @override
  Widget build(BuildContext context) {
    final visual = Theme.of(context)
        .extension<ColoresProceso>()!
        .para(_estadoProcesoRuta(estado));
    return Container(
      constraints: const BoxConstraints(minHeight: 40),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
            _nombreEstadoRuta(estado),
            style: TextStyle(color: visual.color),
          ),
        ],
      ),
    );
  }
}

class _DatoRuta extends StatelessWidget {
  const _DatoRuta({required this.icono, required this.texto});
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

class _VacioRutas extends StatelessWidget {
  const _VacioRutas({required this.mensaje});
  final String mensaje;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Text(mensaje, textAlign: TextAlign.center),
    ),
  );
}

class _CargaRuta extends StatelessWidget {
  const _CargaRuta();
  @override
  Widget build(BuildContext context) => Center(
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: _maximoAnchoRutas),
      child: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          for (final alto in [112.0, 260.0, 200.0, 220.0])
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Container(
                height: alto,
                decoration: BoxDecoration(
                  color: EcoColors.borde.withValues(alpha: 0.7),
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
        ],
      ),
    ),
  );
}

EstadoProcesoPanel _estadoProcesoRuta(EstadoRuta estado) => switch (estado) {
  EstadoRuta.propuesta => EstadoProcesoPanel.propuesta,
  EstadoRuta.aprobada => EstadoProcesoPanel.aprobada,
  EstadoRuta.enCurso => EstadoProcesoPanel.enCurso,
  EstadoRuta.completada => EstadoProcesoPanel.completada,
};

String _nombreEstadoRuta(EstadoRuta estado) => switch (estado) {
  EstadoRuta.propuesta => 'Propuesta',
  EstadoRuta.aprobada => 'Aprobada',
  EstadoRuta.enCurso => 'En curso',
  EstadoRuta.completada => 'Completada',
};

String _asignacion(int? id, String tipo) =>
    id == null ? '$tipo sin asignar' : '$tipo #$id';

void _mostrarMensaje(BuildContext context, String mensaje) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(mensaje)));
}
