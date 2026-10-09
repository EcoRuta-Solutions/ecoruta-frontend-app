import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/theme/app_theme.dart';
import '../data/modelos_flota.dart';
import '../data/modelos_reporte_ciudadano.dart';
import 'controladores_dominio.dart';
import 'panel_utils.dart';
import 'panel_controller.dart';
import 'widgets/estados_panel.dart';

const _maximoAnchoReportesCiudadanos = 920.0;
final _ahoraDemo = DateTime(2026, 10, 8, 12);

class PantallaReportesCiudadanos extends ConsumerStatefulWidget {
  const PantallaReportesCiudadanos({super.key});

  @override
  ConsumerState<PantallaReportesCiudadanos> createState() =>
      _PantallaReportesCiudadanosState();
}

class _PantallaReportesCiudadanosState
    extends ConsumerState<PantallaReportesCiudadanos> {
  EstadoReporte? _estado;
  CategoriaReporte? _categoria;
  int? _dias;

  @override
  Widget build(BuildContext context) {
    final reportes = ref.watch(reportesCiudadanosControllerProvider);
    final ancho = MediaQuery.sizeOf(context).width;
    final margen = ancho < EcoLayout.anchoCompacto ? 16.0 : 24.0;
    return reportes.when(
      loading: () =>
          _lista(margen, const [SliverToBoxAdapter(child: EsqueletoPanel())]),
      error: (error, stackTrace) => _lista(margen, [
        SliverToBoxAdapter(
          child: ErrorPanel(
            onRetry: () => ref.invalidate(reportesCiudadanosControllerProvider),
          ),
        ),
      ]),
      data: (datos) {
        final filtrados = datos.where(_coincide).toList()
          ..sort((a, b) => b.fecha.compareTo(a.fecha));
        return _lista(margen, [
          SliverPadding(
            padding: const EdgeInsets.only(bottom: 16),
            sliver: SliverToBoxAdapter(
              child: Text(
                'Reportes ciudadanos',
                style: Theme.of(context).textTheme.headlineMedium
                    ?.copyWith(color: EcoColors.primario),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: _FiltrosReportes(
              estado: _estado,
              categoria: _categoria,
              dias: _dias,
              onEstado: (valor) => setState(() => _estado = valor),
              onCategoria: (valor) => setState(() => _categoria = valor),
              onDias: (valor) => setState(() => _dias = valor),
              onLimpiar: () => setState(() {
                _estado = null;
                _categoria = null;
                _dias = null;
              }),
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 16)),
          if (filtrados.isEmpty)
            const SliverToBoxAdapter(
              child: _VacioReporteCiudadano(
                mensaje: 'No hay reportes para los filtros seleccionados.',
              ),
            )
          else
            SliverList.builder(
              itemCount: filtrados.length,
              itemBuilder: (context, index) => _TarjetaReporte(
                reporte: filtrados[index],
                onTap: () => _abrirDetalle(filtrados[index]),
              ),
            ),
        ]);
      },
    );
  }

  bool _coincide(ReporteCiudadano reporte) {
    final estado = _estado == null || reporte.estado == _estado;
    final categoria = _categoria == null || reporte.categoria == _categoria;
    final fecha =
        _dias == null ||
        reporte.fecha.isAfter(_ahoraDemo.subtract(Duration(days: _dias!)));
    return estado && categoria && fecha;
  }

  Widget _lista(double margen, List<Widget> slivers) => Center(
    child: ConstrainedBox(
      constraints: const BoxConstraints(
        maxWidth: _maximoAnchoReportesCiudadanos,
      ),
      child: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(reportesCiudadanosControllerProvider);
          await ref.read(reportesCiudadanosControllerProvider.future);
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

  void _abrirDetalle(ReporteCiudadano reporte) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      backgroundColor: EcoColors.superficie,
      builder: (_) => _DetalleReporteCiudadano(reporte: reporte),
    );
  }
}

class _FiltrosReportes extends StatelessWidget {
  const _FiltrosReportes({
    required this.estado,
    required this.categoria,
    required this.dias,
    required this.onEstado,
    required this.onCategoria,
    required this.onDias,
    required this.onLimpiar,
  });

  final EstadoReporte? estado;
  final CategoriaReporte? categoria;
  final int? dias;
  final ValueChanged<EstadoReporte?> onEstado;
  final ValueChanged<CategoriaReporte?> onCategoria;
  final ValueChanged<int?> onDias;
  final VoidCallback onLimpiar;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _FilaChips<EstadoReporte>(
            titulo: 'Estado',
            valor: estado,
            opciones: [
              (null, 'Todos'),
              for (final item in EstadoReporte.values)
                (item, _nombreEstadoReporte(item)),
            ],
            onSeleccionar: onEstado,
          ),
          const SizedBox(height: 12),
          _FilaChips<CategoriaReporte>(
            titulo: 'Categoría',
            valor: categoria,
            opciones: [
              (null, 'Todas'),
              for (final item in CategoriaReporte.values)
                (item, _nombreCategoria(item)),
            ],
            onSeleccionar: onCategoria,
          ),
          const SizedBox(height: 12),
          _FilaChips<int>(
            titulo: 'Fecha',
            valor: dias,
            opciones: const [
              (null, 'Todo el periodo'),
              (7, '7 días'),
              (30, '30 días'),
            ],
            onSeleccionar: onDias,
          ),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: onLimpiar,
              icon: const Icon(Icons.restart_alt_rounded),
              label: const Text('Limpiar filtros'),
            ),
          ),
        ],
      ),
    ),
  );
}

class _FilaChips<T extends Object> extends StatelessWidget {
  const _FilaChips({
    required this.titulo,
    required this.valor,
    required this.opciones,
    required this.onSeleccionar,
  });

  final String titulo;
  final T? valor;
  final List<(T?, String)> opciones;
  final ValueChanged<T?> onSeleccionar;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        titulo,
        style: Theme.of(context).textTheme.labelMedium
            ?.copyWith(color: EcoColors.textoSecundario),
      ),
      const SizedBox(height: 4),
      SizedBox(
        height: 48,
        child: ListView(
          scrollDirection: Axis.horizontal,
          children: [
            for (var indice = 0; indice < opciones.length; indice++)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  label: Text(opciones[indice].$2),
                  selected: opciones[indice].$1 == valor,
                  onSelected: (_) => onSeleccionar(opciones[indice].$1),
                ),
              ),
          ],
        ),
      ),
    ],
  );
}

class _TarjetaReporte extends StatelessWidget {
  const _TarjetaReporte({required this.reporte, required this.onTap});
  final ReporteCiudadano reporte;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final visual = _visualReporte(context, reporte.estado);
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        _nombreCategoria(reporte.categoria),
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(color: EcoColors.primario),
                      ),
                    ),
                    _ChipReporte(estado: reporte.estado),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  reporte.descripcion,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Icon(visual.icono, size: 16, color: visual.color),
                    const SizedBox(width: 8),
                    Text(
                      _haceFecha(reporte.fecha),
                      style: Theme.of(context).textTheme.labelMedium
                          ?.copyWith(color: EcoColors.textoSecundario),
                    ),
                    const Spacer(),
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

class _DetalleReporteCiudadano extends ConsumerWidget {
  const _DetalleReporteCiudadano({required this.reporte});
  final ReporteCiudadano reporte;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reportes =
        ref.watch(reportesCiudadanosControllerProvider).asData?.value ?? [];
    final actual =
        reportes.where((item) => item.id == reporte.id).firstOrNull ?? reporte;
    final flota = ref.watch(flotaControllerProvider).asData?.value;
    final panel = ref.watch(panelControllerProvider).asData?.value;
    final nodo = panel?.nodos
        .where((item) => item.id == actual.nodoRelacionado)
        .firstOrNull;
    final ancho = MediaQuery.sizeOf(context).width;
    final punto = LatLng(actual.latitud, actual.longitud);

    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        ancho < 600 ? 24 : 32,
        8,
        ancho < 600 ? 24 : 32,
        32,
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _nombreCategoria(actual.categoria),
                style: Theme.of(context).textTheme.titleLarge
                    ?.copyWith(color: EcoColors.primario),
              ),
              const SizedBox(height: 8),
              _ChipReporte(estado: actual.estado),
              const SizedBox(height: 16),
              Text(actual.descripcion),
              const SizedBox(height: 16),
              _FotoPlaceholder(),
              const SizedBox(height: 16),
              Text('Ubicación', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: SizedBox(
                  height: 180,
                  child: FlutterMap(
                    options: MapOptions(
                      initialCenter: punto,
                      initialZoom: 15,
                      interactionOptions: const InteractionOptions(
                        flags: InteractiveFlag.none,
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
                          Marker(
                            point: punto,
                            width: 40,
                            height: 40,
                            child: Icon(
                              Icons.location_on_rounded,
                              color: Theme.of(context)
                                  .extension<ColoresEstado>()!
                                  .alerta
                                  .color,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '${actual.latitud.toStringAsFixed(4)}, '
                '${actual.longitud.toStringAsFixed(4)} · Trujillo',
              ),
              if (nodo != null) ...[
                const SizedBox(height: 16),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.delete_outline_rounded),
                  title: Text(nodo.nombre),
                  subtitle: Text('Contenedor relacionado · ${nodo.codigo}'),
                ),
              ],
              const SizedBox(height: 16),
              Text('Historial', style: Theme.of(context).textTheme.titleMedium),
              if (actual.historial.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Text('Sin acciones registradas.'),
                )
              else
                for (final accion in actual.historial)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(
                      Icons.history_rounded,
                      color: Theme.of(context)
                          .extension<ColoresProceso>()!
                          .para(EstadoProcesoPanel.reconocida)
                          .color,
                    ),
                    title: Text(accion.que),
                    subtitle: Text(
                      '${accion.quien} · ${accion.cuando.day}/${accion.cuando.month}'
                      '${accion.nota == null ? '' : '\n${accion.nota}'}',
                    ),
                  ),
              const SizedBox(height: 16),
              if (actual.estado == EstadoReporte.recibido)
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: flota == null
                        ? null
                        : () => _asignar(context, ref, actual, flota),
                    icon: const Icon(Icons.person_add_alt_1_rounded),
                    label: const Text('Pasar a En atención'),
                  ),
                ),
              if (actual.estado == EstadoReporte.enAtencion)
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: () => _resolver(context, ref, actual),
                    icon: const Icon(Icons.task_alt_rounded),
                    label: const Text('Marcar como resuelto'),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _asignar(
    BuildContext context,
    WidgetRef ref,
    ReporteCiudadano actual,
    DatosFlota flota,
  ) async {
    final responsables = [
      ...flota.usuarios
          .where(
            (usuario) =>
                usuario.activo &&
                (usuario.rol == RolPanel.operador ||
                    usuario.rol == RolPanel.supervisor),
          )
          .map((usuario) => usuario.nombre),
      ...flota.conductores
          .where((conductor) => conductor.estado != EstadoConductor.descanso)
          .map((conductor) => conductor.nombre),
    ];
    final responsable = await showDialog<String>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('Asignar reporte'),
        children: [
          for (final nombre in responsables)
            SimpleDialogOption(
              onPressed: () => Navigator.pop(context, nombre),
              child: Text(nombre),
            ),
        ],
      ),
    );
    if (responsable == null || !context.mounted) return;
    await _accionReporte(
      context,
      () => ref
          .read(reportesCiudadanosControllerProvider.notifier)
          .iniciarAtencion(
            actual.id,
            asignadoA: responsable,
            quien: 'Operador municipal',
          ),
      'Reporte asignado a $responsable.',
    );
  }

  Future<void> _resolver(
    BuildContext context,
    WidgetRef ref,
    ReporteCiudadano actual,
  ) async {
    final nota = await _solicitarNota(context);
    if (nota == null || !context.mounted) return;
    await _accionReporte(
      context,
      () => ref
          .read(reportesCiudadanosControllerProvider.notifier)
          .resolver(
            actual.id,
            quien: 'Operador municipal',
            nota: nota.isEmpty ? null : nota,
          ),
      'Reporte marcado como resuelto.',
    );
  }
}

class _FotoPlaceholder extends StatelessWidget {
  const _FotoPlaceholder();

  @override
  Widget build(BuildContext context) {
    final colores = Theme.of(context).extension<ColoresEstado>()!;
    return Semantics(
      label: 'Espacio reservado para fotografía del reporte',
      child: Container(
        height: 120,
        width: double.infinity,
        decoration: BoxDecoration(
          color: colores.sinDatos.fondo,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: EcoColors.borde),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.photo_camera_back_outlined,
              size: 32,
              color: colores.sinDatos.color,
            ),
            const SizedBox(height: 8),
            Text(
              'Sin fotografía adjunta',
              style: Theme.of(context).textTheme.labelMedium
                  ?.copyWith(color: EcoColors.textoSecundario),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChipReporte extends StatelessWidget {
  const _ChipReporte({required this.estado});
  final EstadoReporte estado;

  @override
  Widget build(BuildContext context) {
    final proceso = switch (estado) {
      EstadoReporte.recibido => EstadoProcesoPanel.recibido,
      EstadoReporte.enAtencion => EstadoProcesoPanel.enAtencion,
      EstadoReporte.resuelto => EstadoProcesoPanel.resuelto,
    };
    final visual = Theme.of(context).extension<ColoresProceso>()!.para(proceso);
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
            _nombreEstadoReporte(estado),
            style: TextStyle(color: visual.color),
          ),
        ],
      ),
    );
  }
}

Future<void> _accionReporte(
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

Future<String?> _solicitarNota(BuildContext context) async {
  final controlador = TextEditingController();
  final nota = await showDialog<String>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Resolver reporte'),
      content: TextField(
        controller: controlador,
        maxLines: 3,
        decoration: const InputDecoration(labelText: 'Nota (opcional)'),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, controlador.text.trim()),
          child: const Text('Confirmar'),
        ),
      ],
    ),
  );
  controlador.dispose();
  return nota;
}

EstadoVisual _visualReporte(BuildContext context, EstadoReporte estado) {
  final extension = Theme.of(context).extension<ColoresProceso>()!;
  return switch (estado) {
    EstadoReporte.recibido => extension.para(EstadoProcesoPanel.recibido),
    EstadoReporte.enAtencion => extension.para(EstadoProcesoPanel.enAtencion),
    EstadoReporte.resuelto => extension.para(EstadoProcesoPanel.resuelto),
  };
}

String _haceFecha(DateTime fecha) {
  return formatearTiempoRelativo(fecha, ahora: _ahoraDemo);
}

String _nombreCategoria(CategoriaReporte categoria) => switch (categoria) {
  CategoriaReporte.contenedorLleno => 'Contenedor lleno',
  CategoriaReporte.danado => 'Contenedor dañado',
  CategoriaReporte.basuraAcumulada => 'Basura acumulada',
  CategoriaReporte.malOlor => 'Mal olor',
  CategoriaReporte.otro => 'Otro',
};

String _nombreEstadoReporte(EstadoReporte estado) => switch (estado) {
  EstadoReporte.recibido => 'Recibido',
  EstadoReporte.enAtencion => 'En atención',
  EstadoReporte.resuelto => 'Resuelto',
};

class _VacioReporteCiudadano extends StatelessWidget {
  const _VacioReporteCiudadano({required this.mensaje});
  final String mensaje;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Text(mensaje, textAlign: TextAlign.center),
    ),
  );
}

void _mostrarMensaje(BuildContext context, String mensaje) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(mensaje)));
}
