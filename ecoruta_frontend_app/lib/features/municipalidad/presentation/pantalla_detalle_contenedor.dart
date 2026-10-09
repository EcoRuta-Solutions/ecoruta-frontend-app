import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/theme/app_theme.dart';
import '../data/modelos_lectura_nodo.dart';
import '../data/modelos_panel.dart';
import 'controladores_dominio.dart';
import 'navegacion_controller.dart';
import 'panel_utils.dart';
import 'widgets/barra_llenado.dart';
import 'widgets/chip_estado.dart';
import 'widgets/estados_panel.dart';

class PantallaDetalleContenedor extends ConsumerStatefulWidget {
  const PantallaDetalleContenedor({required this.nodoId, super.key});

  final int nodoId;

  @override
  ConsumerState<PantallaDetalleContenedor> createState() =>
      _PantallaDetalleContenedorState();
}

class _PantallaDetalleContenedorState
    extends ConsumerState<PantallaDetalleContenedor> {
  int _dias = 1;

  @override
  Widget build(BuildContext context) {
    final solicitud = (nodoId: widget.nodoId, dias: _dias);
    final detalle = ref.watch(detalleNodoProvider(solicitud));

    return Scaffold(
      appBar: AppBar(title: const Text('Detalle del contenedor')),
      body: detalle.when(
        loading: () => const _CargaDetalle(),
        error: (error, stackTrace) => Center(
          child: ErrorPanel(
            onRetry: () => ref.invalidate(detalleNodoProvider(solicitud)),
          ),
        ),
        data: (datos) => datos == null
            ? const _NodoNoEncontrado()
            : _ContenidoDetalle(
                detalle: datos,
                dias: _dias,
                onDiasChanged: (dias) => setState(() => _dias = dias),
                onRefresh: () async {
                  ref.invalidate(detalleNodoProvider(solicitud));
                  await ref.read(detalleNodoProvider(solicitud).future);
                },
                onAbrirMapa: () => _abrirEnMapa(datos.nodo),
                onAbrirAlertas: _abrirAlertas,
              ),
      ),
    );
  }

  void _abrirEnMapa(NodoEstado nodo) {
    ref.read(navegacionMunicipalidadProvider.notifier).verNodoEnMapa(nodo.id);
    Navigator.of(context).pop();
  }

  void _abrirAlertas() {
    ref
        .read(navegacionMunicipalidadProvider.notifier)
        .seleccionar(DestinoMunicipalidad.alertas);
    Navigator.of(context).pop();
  }
}

class _ContenidoDetalle extends StatelessWidget {
  const _ContenidoDetalle({
    required this.detalle,
    required this.dias,
    required this.onDiasChanged,
    required this.onRefresh,
    required this.onAbrirMapa,
    required this.onAbrirAlertas,
  });

  final DetalleNodo detalle;
  final int dias;
  final ValueChanged<int> onDiasChanged;
  final Future<void> Function() onRefresh;
  final VoidCallback onAbrirMapa;
  final VoidCallback onAbrirAlertas;

  @override
  Widget build(BuildContext context) {
    final ancho = MediaQuery.sizeOf(context).width;
    final nodo = detalle.nodo;

    return RefreshIndicator(
      onRefresh: onRefresh,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: EcoLayout.anchoContenido),
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.fromLTRB(
              ancho < EcoLayout.anchoCompacto ? 16 : 24,
              24,
              ancho < EcoLayout.anchoCompacto ? 16 : 24,
              32,
            ),
            children: [
              _CabeceraNodo(nodo: nodo),
              const SizedBox(height: 16),
              _SeccionTarjeta(
                titulo: 'Historial de llenado',
                hijo: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SegmentedButton<int>(
                      segments: const [
                        ButtonSegment(value: 1, label: Text('24 h')),
                        ButtonSegment(value: 7, label: Text('7 días')),
                      ],
                      selected: {dias},
                      onSelectionChanged: (seleccion) =>
                          onDiasChanged(seleccion.first),
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      height: 220,
                      child: _GraficoLlenado(
                        lecturas: detalle.lecturas,
                        prediccion: detalle.prediccion,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              _TarjetaPrediccion(prediccion: detalle.prediccion),
              const SizedBox(height: 16),
              _SaludNodo(nodo: nodo),
              const SizedBox(height: 16),
              _UbicacionNodo(nodo: nodo, onAbrirMapa: onAbrirMapa),
              const SizedBox(height: 16),
              _EventosNodo(eventos: detalle.eventos),
              const SizedBox(height: 24),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  OutlinedButton.icon(
                    onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('La edición estará disponible pronto.'),
                      ),
                    ),
                    icon: const Icon(Icons.edit_outlined),
                    label: const Text('Editar contenedor'),
                  ),
                  OutlinedButton.icon(
                    onPressed: onAbrirAlertas,
                    icon: const Icon(Icons.notifications_outlined),
                    label: const Text('Ver alertas de este contenedor'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CabeceraNodo extends StatelessWidget {
  const _CabeceraNodo({required this.nodo});

  final NodoEstado nodo;

  @override
  Widget build(BuildContext context) {
    final visual = Theme.of(context)
        .extension<ColoresEstado>()!
        .para(nodo.estado);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              nodo.nombre,
              style: Theme.of(context).textTheme.titleLarge
                  ?.copyWith(color: EcoColors.primario),
            ),
            const SizedBox(height: 8),
            Text(
              nodo.codigo,
              style: Theme.of(context).textTheme.bodyMedium
                  ?.copyWith(color: EcoColors.textoSecundario),
            ),
            const SizedBox(height: 24),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  nodo.llenado == null ? '—' : '${nodo.llenado!.round()}%',
                  style: Theme.of(context).textTheme.displayMedium?.copyWith(
                    color: visual.color,
                    fontWeight: FontWeight.w700,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
                const Spacer(),
                ChipEstado(estado: nodo.estado),
              ],
            ),
            const SizedBox(height: 16),
            BarraLlenado(llenado: nodo.llenado, estado: nodo.estado),
          ],
        ),
      ),
    );
  }
}

class _SeccionTarjeta extends StatelessWidget {
  const _SeccionTarjeta({required this.titulo, required this.hijo});

  final String titulo;
  final Widget hijo;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            titulo,
            style: Theme.of(context).textTheme.titleMedium
                ?.copyWith(color: EcoColors.primario),
          ),
          const SizedBox(height: 16),
          hijo,
        ],
      ),
    ),
  );
}

class _GraficoLlenado extends StatelessWidget {
  const _GraficoLlenado({required this.lecturas, required this.prediccion});

  final List<LecturaLlenado> lecturas;
  final PrediccionLlenado? prediccion;

  @override
  Widget build(BuildContext context) {
    final estado = Theme.of(context).extension<ColoresEstado>()!;
    if (lecturas.isEmpty) {
      return const Center(child: Text('Aún no hay lecturas para graficar.'));
    }

    return Semantics(
      label: 'Gráfico del historial de llenado',
      child: LineChart(
        LineChartData(
          minY: 0,
          maxY: 100,
          minX: 0,
          maxX: lecturas.length.toDouble().clamp(1, double.infinity).toDouble(),
          gridData: const FlGridData(
            drawVerticalLine: false,
            horizontalInterval: 25,
          ),
          titlesData: FlTitlesData(
            topTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            rightTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 32,
                getTitlesWidget: (valor, meta) {
                  final indice = valor.round();
                  if (valor != indice ||
                      indice < 0 ||
                      indice >= lecturas.length) {
                    return const SizedBox.shrink();
                  }
                  final fecha = lecturas[indice].fecha;
                  return Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      diasLabel(fecha, lecturas.length),
                      style: Theme.of(context).textTheme.labelSmall
                          ?.copyWith(color: EcoColors.textoSecundario),
                    ),
                  );
                },
              ),
            ),
          ),
          extraLinesData: ExtraLinesData(
            horizontalLines: [
              HorizontalLine(
                y: umbralReferenciaGrafico,
                color: estado.critico.color.withValues(alpha: 0.55),
                strokeWidth: 1,
                dashArray: [6, 4],
                label: HorizontalLineLabel(
                  show: true,
                  labelResolver: (_) => 'Referencia visual',
                  style: Theme.of(context).textTheme.labelSmall
                      ?.copyWith(color: estado.critico.color),
                ),
              ),
            ],
          ),
          lineBarsData: [
            LineChartBarData(
              spots: [
                for (var indice = 0; indice < lecturas.length; indice++)
                  FlSpot(indice.toDouble(), lecturas[indice].porcentaje),
              ],
              isCurved: true,
              color: EcoColors.acento,
              barWidth: 3,
              dotData: const FlDotData(show: true),
              belowBarData: BarAreaData(
                show: true,
                color: EcoColors.acento.withValues(alpha: 0.10),
              ),
            ),
            if (prediccion != null)
              LineChartBarData(
                spots: [
                  FlSpot(
                    (lecturas.length - 1).toDouble(),
                    lecturas.last.porcentaje,
                  ),
                  FlSpot(lecturas.length.toDouble(), 100),
                ],
                color: estado.alerta.color,
                barWidth: 2,
                dashArray: [6, 4],
                dotData: const FlDotData(show: false),
              ),
          ],
          lineTouchData: LineTouchData(
            touchTooltipData: LineTouchTooltipData(
              getTooltipItems: (spots) => spots
                  .map(
                    (spot) => LineTooltipItem(
                      '${spot.y.round()}%',
                      Theme.of(context).textTheme.labelMedium!.copyWith(
                        color: EcoColors.superficie,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  )
                  .toList(),
            ),
          ),
        ),
        duration: const Duration(milliseconds: 300),
      ),
    );
  }

  String diasLabel(DateTime fecha, int total) => total <= 9
      ? '${fecha.hour.toString().padLeft(2, '0')}:00'
      : '${fecha.day}/${fecha.month}';
}

class _TarjetaPrediccion extends StatelessWidget {
  const _TarjetaPrediccion({required this.prediccion});

  final PrediccionLlenado? prediccion;

  @override
  Widget build(BuildContext context) => _SeccionTarjeta(
    titulo: 'Predicción de desborde',
    hijo: prediccion == null
        ? const Text('No hay lecturas suficientes para estimar el desborde.')
        : Row(
            children: [
              const Icon(Icons.schedule_rounded, color: EcoColors.acento),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'En ${prediccion!.horaEstimadaDesborde.difference(DateTime(2026, 10, 8, 12)).inHours} h · '
                  '${TimeOfDay.fromDateTime(prediccion!.horaEstimadaDesborde).format(context)}',
                  style: Theme.of(context).textTheme.bodyMedium
                      ?.copyWith(color: EcoColors.texto),
                ),
              ),
              Text(
                '${(prediccion!.confianza * 100).round()}% confianza',
                style: Theme.of(context).textTheme.labelMedium
                    ?.copyWith(color: EcoColors.textoSecundario),
              ),
            ],
          ),
  );
}

class _SaludNodo extends StatelessWidget {
  const _SaludNodo({required this.nodo});

  final NodoEstado nodo;

  @override
  Widget build(BuildContext context) {
    final operativo = Theme.of(context)
        .extension<ColoresProceso>()!
        .para(switch (nodo.estadoOperativo) {
          EstadoOperativo.activo => EstadoProcesoPanel.activo,
          EstadoOperativo.mantenimiento => EstadoProcesoPanel.mantenimiento,
          EstadoOperativo.inactivo => EstadoProcesoPanel.inactivo,
        });
    return _SeccionTarjeta(
      titulo: 'Salud del nodo',
      hijo: Wrap(
        spacing: 24,
        runSpacing: 20,
        children: [
          _DatoSalud(etiqueta: 'Batería', valor: '${nodo.bateria ?? '—'}%'),
          _DatoSalud(etiqueta: 'Señal', valor: '${nodo.senal ?? '—'}/4'),
          _DatoSalud(
            etiqueta: 'Última lectura',
            valor: tiempoDesdeLectura(nodo.ultimaLectura),
          ),
          _DatoSalud(etiqueta: 'Firmware', valor: nodo.firmware),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(operativo.icono, color: operativo.color, size: 18),
              const SizedBox(width: 8),
              Text(
                _nombreOperativo(nodo.estadoOperativo),
                style: Theme.of(context).textTheme.bodySmall
                    ?.copyWith(color: operativo.color),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DatoSalud extends StatelessWidget {
  const _DatoSalud({required this.etiqueta, required this.valor});

  final String etiqueta;
  final String valor;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        etiqueta,
        style: Theme.of(context).textTheme.labelSmall
            ?.copyWith(color: EcoColors.textoSecundario),
      ),
      const SizedBox(height: 8),
      Text(valor, style: Theme.of(context).textTheme.bodyMedium),
    ],
  );
}

class _UbicacionNodo extends StatelessWidget {
  const _UbicacionNodo({required this.nodo, required this.onAbrirMapa});

  final NodoEstado nodo;
  final VoidCallback onAbrirMapa;

  @override
  Widget build(BuildContext context) {
    final punto = nodo.latitud == null || nodo.longitud == null
        ? null
        : LatLng(nodo.latitud!, nodo.longitud!);
    return _SeccionTarjeta(
      titulo: 'Ubicación',
      hijo: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: SizedBox(
              height: 160,
              child: punto == null
                  ? const Center(child: Text('Ubicación no disponible.'))
                  : FlutterMap(
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
                                    .para(nodo.estado)
                                    .color,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Text(
                  '${nodo.zona}, Trujillo',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
              TextButton.icon(
                onPressed: onAbrirMapa,
                icon: const Icon(Icons.map_outlined),
                label: const Text('Ver en el mapa'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _EventosNodo extends StatelessWidget {
  const _EventosNodo({required this.eventos});

  final List<EventoNodo> eventos;

  @override
  Widget build(BuildContext context) => _SeccionTarjeta(
    titulo: 'Eventos',
    hijo: eventos.isEmpty
        ? const Text('Sin eventos recientes.')
        : Column(
            children: [
              for (final evento in eventos)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(
                    _iconoEvento(evento.tipo),
                    color: Theme.of(context)
                        .extension<ColoresEstado>()!
                        .alerta
                        .color,
                  ),
                  title: Text(_nombreEvento(evento.tipo)),
                  subtitle: Text(evento.descripcion),
                  trailing: Text(
                    '${evento.fecha.day}/${evento.fecha.month}',
                    style: Theme.of(context).textTheme.labelSmall,
                  ),
                ),
            ],
          ),
  );
}

class _CargaDetalle extends StatelessWidget {
  const _CargaDetalle();

  @override
  Widget build(BuildContext context) => Center(
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: EcoLayout.anchoContenido),
      child: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          for (final alto in [168.0, 300.0, 132.0, 180.0, 200.0])
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

class _NodoNoEncontrado extends StatelessWidget {
  const _NodoNoEncontrado();

  @override
  Widget build(BuildContext context) => const Center(
    child: Padding(
      padding: EdgeInsets.all(24),
      child: Text('No encontramos este contenedor.'),
    ),
  );
}

String _nombreOperativo(EstadoOperativo estado) => switch (estado) {
  EstadoOperativo.activo => 'Activo',
  EstadoOperativo.mantenimiento => 'En mantenimiento',
  EstadoOperativo.inactivo => 'Inactivo',
};

IconData _iconoEvento(TipoEventoNodo tipo) => switch (tipo) {
  TipoEventoNodo.volteado => Icons.screen_rotation_alt_rounded,
  TipoEventoNodo.lecturaAtipica => Icons.show_chart_rounded,
  TipoEventoNodo.bateriaBaja => Icons.battery_alert_rounded,
  TipoEventoNodo.mantenimiento => Icons.build_outlined,
};

String _nombreEvento(TipoEventoNodo tipo) => switch (tipo) {
  TipoEventoNodo.volteado => 'Contenedor volteado',
  TipoEventoNodo.lecturaAtipica => 'Lectura atípica',
  TipoEventoNodo.bateriaBaja => 'Batería baja',
  TipoEventoNodo.mantenimiento => 'Mantenimiento',
};
