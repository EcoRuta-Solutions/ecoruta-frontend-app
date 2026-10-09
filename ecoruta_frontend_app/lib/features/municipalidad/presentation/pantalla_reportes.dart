import 'dart:convert';
import 'dart:io';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/theme/app_theme.dart';
import '../data/exportador_informes.dart';
import '../data/modelos_informe.dart';
import '../data/modelos_panel.dart';
import 'controladores_dominio.dart';
import 'panel_controller.dart';
import 'widgets/barra_llenado.dart';
import 'widgets/chip_estado.dart';
import 'widgets/estados_panel.dart';

const _anchoMaximoInformes = 920.0;
const _zonasInforme = ['Centro', 'Víctor Larco', 'La Esperanza', 'El Porvenir'];

class PantallaReportes extends ConsumerStatefulWidget {
  const PantallaReportes({super.key});

  @override
  ConsumerState<PantallaReportes> createState() => _PantallaReportesState();
}

class _PantallaReportesState extends ConsumerState<PantallaReportes> {
  RangoInforme _rango = RangoInforme.sieteDias;
  DateTimeRange? _personalizado;
  bool _exportando = false;

  @override
  Widget build(BuildContext context) {
    final informe = ref.watch(informesControllerProvider);
    final panel = ref.watch(panelControllerProvider);
    final ancho = MediaQuery.sizeOf(context).width;
    final margen = ancho < EcoLayout.anchoCompacto ? 16.0 : 24.0;

    if (informe.isLoading || panel.isLoading) {
      return _lista(margen, const [
        SliverToBoxAdapter(child: EsqueletoPanel()),
      ]);
    }
    if (informe.hasError || panel.hasError) {
      return _lista(margen, [
        SliverToBoxAdapter(
          child: ErrorPanel(
            onRetry: () {
              ref.invalidate(informesControllerProvider);
              ref.invalidate(panelControllerProvider);
            },
          ),
        ),
      ]);
    }

    final datosInforme = informe.requireValue;
    final datosPanel = panel.requireValue;
    final top = datosPanel.nodos.where((nodo) => nodo.llenado != null).toList()
      ..sort((a, b) => (b.llenado ?? 0).compareTo(a.llenado ?? 0));
    final topCinco = top.take(5).toList();
    return _lista(margen, [
      SliverPadding(
        padding: const EdgeInsets.only(bottom: 16),
        sliver: SliverToBoxAdapter(
          child: Text(
            'Informes',
            style: Theme.of(context).textTheme.headlineMedium
                ?.copyWith(color: EcoColors.primario),
          ),
        ),
      ),
      SliverToBoxAdapter(
        child: _SelectorRango(
          rango: _rango,
          personalizado: _personalizado,
          onSeleccionar: _seleccionarRango,
          onPersonalizado: _seleccionarPersonalizado,
        ),
      ),
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.only(top: 16),
          child: _ResumenReporte(resumen: datosPanel.resumen),
        ),
      ),
      SliverPadding(
        padding: const EdgeInsets.only(top: 16),
        sliver: SliverToBoxAdapter(
          child: _KpisInforme(kpis: datosInforme.kpis),
        ),
      ),
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.only(top: 16),
          child: _GraficoLlenadoInforme(puntos: datosInforme.llenadoPromedio),
        ),
      ),
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.only(top: 16),
          child: _GraficoDesbordes(zonas: datosInforme.desbordesPorZona),
        ),
      ),
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.only(top: 16),
          child: _GraficoKilometros(
            optimizados: datosInforme.kilometrosOptimizados,
            fijos: datosInforme.kilometrosFijos,
          ),
        ),
      ),
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.only(top: 16),
          child: _GraficoEstados(resumen: datosPanel.resumen),
        ),
      ),
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(0, 24, 0, 16),
          child: Text(
            'Top 5 más llenos',
            style: Theme.of(context).textTheme.titleLarge
                ?.copyWith(color: EcoColors.primario),
          ),
        ),
      ),
      if (topCinco.isEmpty)
        const SliverToBoxAdapter(
          child: _MensajeInforme(
            mensaje: 'No hay contenedores con lecturas en este periodo.',
          ),
        )
      else
        SliverList.builder(
          itemCount: topCinco.length,
          itemBuilder: (context, index) => _FilaTop(nodo: topCinco[index]),
        ),
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.only(top: 8),
          child: _BotonExportar(
            estaExportando: _exportando,
            onSeleccionar: (formato) =>
                _exportar(formato, datosInforme, datosPanel.nodos),
          ),
        ),
      ),
    ]);
  }

  Widget _lista(double margen, List<Widget> slivers) => Center(
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: _anchoMaximoInformes),
      child: RefreshIndicator(
        onRefresh: () async {
          await Future.wait([
            ref.read(informesControllerProvider.notifier).recargar(),
            ref.read(panelControllerProvider.notifier).recargar(),
          ]);
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

  Future<void> _seleccionarRango(RangoInforme rango) async {
    final ahora = DateTime.now();
    final hoy = DateTime(ahora.year, ahora.month, ahora.day);
    final inicio = switch (rango) {
      RangoInforme.hoy => hoy,
      RangoInforme.sieteDias => hoy.subtract(const Duration(days: 6)),
      RangoInforme.treintaDias => hoy.subtract(const Duration(days: 29)),
      RangoInforme.personalizado => _personalizado?.start ?? hoy,
    };
    final fin = rango == RangoInforme.personalizado
        ? _personalizado?.end ?? ahora
        : ahora;
    setState(() => _rango = rango);
    await ref
        .read(informesControllerProvider.notifier)
        .cargarRango(inicio, fin);
  }

  Future<void> _seleccionarPersonalizado() async {
    final hoy = DateTime.now();
    final rango = await showDateRangePicker(
      context: context,
      locale: const Locale('es'),
      firstDate: DateTime(hoy.year - 5),
      lastDate: hoy,
      initialDateRange:
          _personalizado ??
          DateTimeRange(start: hoy.subtract(const Duration(days: 6)), end: hoy),
      helpText: 'Selecciona el periodo del informe',
      saveText: 'Aplicar',
    );
    if (rango == null || !mounted) return;
    setState(() {
      _personalizado = rango;
      _rango = RangoInforme.personalizado;
    });
    await ref
        .read(informesControllerProvider.notifier)
        .cargarRango(rango.start, rango.end.add(const Duration(days: 1)));
  }

  Future<void> _exportar(
    _FormatoExportacion formato,
    DatosInforme informe,
    List<NodoEstado> nodos,
  ) async {
    setState(() => _exportando = true);
    try {
      final bytes = formato == _FormatoExportacion.csv
          ? utf8.encode(generarCsvInforme(informe, nodos))
          : await generarPdfInforme(informe, nodos);
      final directorio = await getApplicationDocumentsDirectory();
      final extension = formato == _FormatoExportacion.csv ? 'csv' : 'pdf';
      final archivo = File(
        '${directorio.path}${Platform.pathSeparator}'
        'ecoruta_informe_${DateTime.now().millisecondsSinceEpoch}.$extension',
      );
      await archivo.writeAsBytes(bytes, flush: true);
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(archivo.path)],
          subject: 'Informe EcoRuta Trujillo',
          text:
              'Informe municipal del periodo '
              '${DateFormat('dd/MM/yyyy', 'es').format(informe.inicio)} - '
              '${DateFormat('dd/MM/yyyy', 'es').format(informe.fin)}',
        ),
      );
      if (mounted) _mensaje('Informe exportado y listo para compartir.');
    } on Exception catch (error) {
      if (mounted) _mensaje('No se pudo exportar el informe: $error');
    } finally {
      if (mounted) setState(() => _exportando = false);
    }
  }

  void _mensaje(String texto) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(texto)));
  }
}

enum _FormatoExportacion { csv, pdf }

class _BotonExportar extends StatelessWidget {
  const _BotonExportar({
    required this.estaExportando,
    required this.onSeleccionar,
  });

  final bool estaExportando;
  final ValueChanged<_FormatoExportacion> onSeleccionar;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Builder(
        builder: (context) => OutlinedButton.icon(
          onPressed: estaExportando
              ? null
              : () async {
                  final caja = context.findRenderObject()! as RenderBox;
                  final posicion = caja.localToGlobal(Offset.zero);
                  final seleccion = await showMenu<_FormatoExportacion>(
                    context: context,
                    position: RelativeRect.fromLTRB(
                      posicion.dx,
                      posicion.dy + caja.size.height,
                      posicion.dx + caja.size.width,
                      posicion.dy,
                    ),
                    items: const [
                      PopupMenuItem(
                        value: _FormatoExportacion.csv,
                        child: ListTile(
                          leading: Icon(Icons.table_view_outlined),
                          title: Text('Exportar CSV'),
                        ),
                      ),
                      PopupMenuItem(
                        value: _FormatoExportacion.pdf,
                        child: ListTile(
                          leading: Icon(Icons.picture_as_pdf_outlined),
                          title: Text('Exportar PDF'),
                        ),
                      ),
                    ],
                  );
                  if (seleccion != null && context.mounted) {
                    onSeleccionar(seleccion);
                  }
                },
          icon: estaExportando
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.download_outlined),
          label: Text(estaExportando ? 'Preparando informe' : 'Exportar'),
        ),
      ),
      if (estaExportando) ...[
        const SizedBox(height: 8),
        const LinearProgressIndicator(),
      ],
    ],
  );
}

class _SelectorRango extends StatelessWidget {
  const _SelectorRango({
    required this.rango,
    required this.personalizado,
    required this.onSeleccionar,
    required this.onPersonalizado,
  });

  final RangoInforme rango;
  final DateTimeRange? personalizado;
  final ValueChanged<RangoInforme> onSeleccionar;
  final VoidCallback onPersonalizado;

  @override
  Widget build(BuildContext context) {
    final fecha = personalizado == null
        ? null
        : '${DateFormat('d MMM', 'es').format(personalizado!.start)} – '
              '${DateFormat('d MMM', 'es').format(personalizado!.end)}';
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              fecha == null ? 'Periodo del informe' : 'Periodo · $fecha',
              style: Theme.of(context).textTheme.titleMedium
                  ?.copyWith(color: EcoColors.primario),
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 48,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  for (final opcion in [
                    (RangoInforme.hoy, 'Hoy'),
                    (RangoInforme.sieteDias, '7 días'),
                    (RangoInforme.treintaDias, '30 días'),
                  ])
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(opcion.$2),
                        selected: rango == opcion.$1,
                        onSelected: (_) => onSeleccionar(opcion.$1),
                      ),
                    ),
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ActionChip(
                      avatar: const Icon(Icons.date_range_outlined, size: 18),
                      label: const Text('Personalizado'),
                      onPressed: onPersonalizado,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ResumenReporte extends StatelessWidget {
  const _ResumenReporte({required this.resumen});
  final ResumenPanel resumen;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Resumen de contenedores',
            style: Theme.of(context).textTheme.titleLarge
                ?.copyWith(color: EcoColors.primario),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 24,
            runSpacing: 16,
            children: [
              _ValorResumen(etiqueta: 'Total', valor: '${resumen.totalNodos}'),
              _ValorResumen(
                etiqueta: 'Promedio de llenado',
                valor: resumen.promedioLlenado == null
                    ? '—'
                    : '${resumen.promedioLlenado!.round()}%',
              ),
              _ValorResumen(
                etiqueta: 'Con lectura',
                valor: '${resumen.nodosConDatos}',
              ),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _ChipResumen(
                estado: EstadoNodo.critico,
                cantidad: resumen.criticos,
              ),
              _ChipResumen(
                estado: EstadoNodo.alerta,
                cantidad: resumen.alertas,
              ),
              _ChipResumen(
                estado: EstadoNodo.normal,
                cantidad: resumen.normales,
              ),
              _ChipResumen(
                estado: EstadoNodo.sinDatos,
                cantidad: resumen.sinDatos,
              ),
            ],
          ),
        ],
      ),
    ),
  );
}

class _ValorResumen extends StatelessWidget {
  const _ValorResumen({required this.etiqueta, required this.valor});
  final String etiqueta;
  final String valor;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        valor,
        style: Theme.of(context).textTheme.titleLarge?.copyWith(
          color: EcoColors.primario,
          fontWeight: FontWeight.w700,
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
      ),
      const SizedBox(height: 4),
      Text(
        etiqueta,
        style: Theme.of(context).textTheme.labelMedium
            ?.copyWith(color: EcoColors.textoSecundario),
      ),
    ],
  );
}

class _ChipResumen extends StatelessWidget {
  const _ChipResumen({required this.estado, required this.cantidad});
  final EstadoNodo estado;
  final int cantidad;

  @override
  Widget build(BuildContext context) {
    final visual = Theme.of(context).extension<ColoresEstado>()!.para(estado);
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
          Text('${_nombreEstado(estado)} · $cantidad'),
        ],
      ),
    );
  }
}

class _KpisInforme extends StatelessWidget {
  const _KpisInforme({required this.kpis});
  final List<KpiInforme> kpis;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      for (final kpi in kpis)
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: _TarjetaKpi(kpi: kpi),
        ),
    ],
  );
}

class _TarjetaKpi extends StatelessWidget {
  const _TarjetaKpi({required this.kpi});
  final KpiInforme kpi;

  @override
  Widget build(BuildContext context) {
    final visual = Theme.of(context).extension<ColoresProceso>()!.para(
      kpi.cumple ? EstadoProcesoPanel.completada : EstadoProcesoPanel.nueva,
    );
    final operador = kpi.mayorEsMejor ? '≥' : '≤';
    return Semantics(
      label:
          '${kpi.nombre}: ${kpi.valor}${kpi.unidad}, meta $operador'
          '${kpi.meta}${kpi.unidad}, ${kpi.cumple ? 'cumple' : 'no cumple'}',
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(visual.icono, color: visual.color, size: 24),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      kpi.nombre,
                      style: Theme.of(context).textTheme.titleSmall
                          ?.copyWith(color: EcoColors.primario),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Meta $operador ${_formatoNumero(kpi.meta)}${kpi.unidad}',
                      style: Theme.of(context).textTheme.labelMedium
                          ?.copyWith(color: EcoColors.textoSecundario),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${_formatoNumero(kpi.valor)}${kpi.unidad}',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: visual.color,
                      fontWeight: FontWeight.w700,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                  Text(
                    kpi.cumple ? 'Cumple' : 'No cumple',
                    style: Theme.of(context).textTheme.labelSmall
                        ?.copyWith(color: visual.color),
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

class _TarjetaGrafico extends StatelessWidget {
  const _TarjetaGrafico({required this.titulo, required this.hijo});
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
          const SizedBox(height: 20),
          hijo,
        ],
      ),
    ),
  );
}

class _GraficoLlenadoInforme extends StatelessWidget {
  const _GraficoLlenadoInforme({required this.puntos});
  final List<PuntoSerieInforme> puntos;

  @override
  Widget build(BuildContext context) => _TarjetaGrafico(
    titulo: 'Llenado promedio en el tiempo',
    hijo: SizedBox(
      height: 220,
      child: puntos.isEmpty
          ? const _VacioGrafico()
          : Semantics(
              label: 'Gráfico de línea del llenado promedio en el tiempo',
              child: LineChart(
                LineChartData(
                  minY: 0,
                  maxY: 100,
                  minX: 0,
                  maxX: (puntos.length - 1).toDouble().clamp(
                    1,
                    double.infinity,
                  ),
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
                              indice >= puntos.length) {
                            return const SizedBox.shrink();
                          }
                          return Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(
                              DateFormat(
                                'd/M',
                                'es',
                              ).format(puntos[indice].fecha),
                              style: Theme.of(context).textTheme.labelSmall
                                  ?.copyWith(color: EcoColors.textoSecundario),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  lineBarsData: [
                    LineChartBarData(
                      spots: [
                        for (var index = 0; index < puntos.length; index++)
                          FlSpot(index.toDouble(), puntos[index].valor),
                      ],
                      isCurved: true,
                      barWidth: 3,
                      color: EcoColors.acento,
                      dotData: const FlDotData(show: true),
                      belowBarData: BarAreaData(
                        show: true,
                        color: EcoColors.acento.withValues(alpha: 0.10),
                      ),
                    ),
                  ],
                  lineTouchData: LineTouchData(
                    touchTooltipData: LineTouchTooltipData(
                      getTooltipItems: (spots) => spots
                          .map(
                            (spot) => LineTooltipItem(
                              '${spot.y.round()}%',
                              const TextStyle(
                                color: EcoColors.superficie,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          )
                          .toList(),
                    ),
                  ),
                ),
                duration: const Duration(milliseconds: 360),
              ),
            ),
    ),
  );
}

class _GraficoDesbordes extends StatelessWidget {
  const _GraficoDesbordes({required this.zonas});
  final Map<String, int> zonas;

  @override
  Widget build(BuildContext context) {
    final entradas = [
      for (final zona in _zonasInforme) (zona, zonas[zona] ?? 0),
    ];
    return _TarjetaGrafico(
      titulo: 'Desbordes por zona',
      hijo: SizedBox(
        height: 240,
        child: entradas.every((entrada) => entrada.$2 == 0)
            ? const _VacioGrafico()
            : Semantics(
                label: 'Gráfico de columnas de desbordes por zona',
                child: BarChart(
                  BarChartData(
                    maxY:
                        (entradas
                                    .map((entrada) => entrada.$2)
                                    .fold<int>(
                                      0,
                                      (maximo, valor) =>
                                          valor > maximo ? valor : maximo,
                                    ) +
                                1)
                            .toDouble(),
                    gridData: const FlGridData(drawVerticalLine: false),
                    borderData: FlBorderData(show: false),
                    titlesData: FlTitlesData(
                      topTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
                      rightTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
                      leftTitles: const AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 28,
                        ),
                      ),
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 48,
                          getTitlesWidget: (valor, meta) {
                            final indice = valor.toInt();
                            if (indice < 0 || indice >= entradas.length) {
                              return const SizedBox.shrink();
                            }
                            return Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: Text(
                                _zonaCorta(entradas[indice].$1),
                                style: Theme.of(context).textTheme.labelSmall
                                    ?.copyWith(
                                      color: EcoColors.textoSecundario,
                                    ),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                    barGroups: [
                      for (var index = 0; index < entradas.length; index++)
                        BarChartGroupData(
                          x: index,
                          barRods: [
                            BarChartRodData(
                              toY: entradas[index].$2.toDouble(),
                              color: Theme.of(context)
                                  .extension<ColoresEstado>()!
                                  .alerta
                                  .color,
                              width: 24,
                              borderRadius: const BorderRadius.vertical(
                                top: Radius.circular(6),
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                  duration: const Duration(milliseconds: 360),
                ),
              ),
      ),
    );
  }
}

class _GraficoKilometros extends StatelessWidget {
  const _GraficoKilometros({required this.optimizados, required this.fijos});
  final List<PuntoSerieInforme> optimizados;
  final List<PuntoSerieInforme> fijos;

  @override
  Widget build(BuildContext context) {
    final cantidad = optimizados.length < fijos.length
        ? optimizados.length
        : fijos.length;
    final mayor = [
      ...optimizados.map((punto) => punto.valor),
      ...fijos.map((punto) => punto.valor),
    ].fold<double>(0, (actual, valor) => valor > actual ? valor : actual);
    return _TarjetaGrafico(
      titulo: 'Kilómetros optimizados vs. fijos',
      hijo: Column(
        children: [
          SizedBox(
            height: 200,
            child: cantidad == 0
                ? const _VacioGrafico()
                : Semantics(
                    label: 'Gráfico comparativo de kilómetros optimizados y ruta fija',
                    child: LineChart(
                      LineChartData(
                        minY: 0,
                        maxY: mayor == 0 ? 1 : mayor * 1.15,
                        minX: 0,
                        maxX: (cantidad - 1).toDouble().clamp(
                          1,
                          double.infinity,
                        ),
                        gridData: const FlGridData(drawVerticalLine: false),
                        titlesData: const FlTitlesData(
                          topTitles: AxisTitles(
                            sideTitles: SideTitles(showTitles: false),
                          ),
                          rightTitles: AxisTitles(
                            sideTitles: SideTitles(showTitles: false),
                          ),
                        ),
                        lineBarsData: [
                          _serieLinea(
                            optimizados.take(cantidad).toList(),
                            EcoColors.acento,
                          ),
                          _serieLinea(
                            fijos.take(cantidad).toList(),
                            Theme.of(context)
                                .extension<ColoresEstado>()!
                                .sinDatos
                                .color,
                          ),
                        ],
                      ),
                      duration: const Duration(milliseconds: 360),
                    ),
                  ),
          ),
          const SizedBox(height: 12),
          const Wrap(
            spacing: 20,
            runSpacing: 8,
            children: [
              _LeyendaSerie(color: EcoColors.acento, texto: 'Optimizada'),
              _LeyendaSerie(
                color: EcoColors.textoSecundario,
                texto: 'Ruta fija',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

LineChartBarData _serieLinea(List<PuntoSerieInforme> puntos, Color color) =>
    LineChartBarData(
      spots: [
        for (var index = 0; index < puntos.length; index++)
          FlSpot(index.toDouble(), puntos[index].valor),
      ],
      isCurved: true,
      color: color,
      barWidth: 3,
      dotData: const FlDotData(show: true),
    );

class _LeyendaSerie extends StatelessWidget {
  const _LeyendaSerie({required this.color, required this.texto});
  final Color color;
  final String texto;
  @override
  Widget build(BuildContext context) => Semantics(
    label: 'Serie: $texto',
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 8),
        Text(texto),
      ],
    ),
  );
}

class _GraficoEstados extends StatelessWidget {
  const _GraficoEstados({required this.resumen});
  final ResumenPanel resumen;

  @override
  Widget build(BuildContext context) {
    final estados = [
      (EstadoNodo.critico, resumen.criticos),
      (EstadoNodo.alerta, resumen.alertas),
      (EstadoNodo.normal, resumen.normales),
      (EstadoNodo.sinDatos, resumen.sinDatos),
    ];
    final mayor = estados.fold<int>(
      0,
      (actual, item) => item.$2 > actual ? item.$2 : actual,
    );
    return _TarjetaGrafico(
      titulo: 'Contenedores por estado',
      hijo: Column(
        children: [
          for (final item in estados)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _BarraEstado(
                estado: item.$1,
                cantidad: item.$2,
                maximo: mayor,
              ),
            ),
        ],
      ),
    );
  }
}

class _BarraEstado extends StatelessWidget {
  const _BarraEstado({
    required this.estado,
    required this.cantidad,
    required this.maximo,
  });
  final EstadoNodo estado;
  final int cantidad;
  final int maximo;

  @override
  Widget build(BuildContext context) {
    final visual = Theme.of(context).extension<ColoresEstado>()!.para(estado);
    return Semantics(
      label: '${_nombreEstado(estado)}: $cantidad',
      child: Row(
        children: [
          SizedBox(
            width: 92,
            child: Row(
              children: [
                Icon(visual.icono, size: 16, color: visual.color),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _nombreEstado(estado),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.labelSmall,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: maximo == 0 ? 0 : cantidad / maximo),
              duration: const Duration(milliseconds: 400),
              builder: (context, valor, _) => ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: valor,
                  minHeight: 10,
                  color: visual.color,
                  backgroundColor: visual.fondo,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          SizedBox(
            width: 20,
            child: Text(
              '$cantidad',
              textAlign: TextAlign.end,
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: EcoColors.primario,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FilaTop extends StatelessWidget {
  const _FilaTop({required this.nodo});
  final NodoEstado nodo;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    nodo.nombre,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleMedium
                        ?.copyWith(color: EcoColors.texto),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${nodo.codigo} · ${nodo.zona}',
                    style: Theme.of(context).textTheme.labelMedium
                        ?.copyWith(color: EcoColors.textoSecundario),
                  ),
                  const SizedBox(height: 8),
                  ChipEstado(estado: nodo.estado),
                  const SizedBox(height: 12),
                  BarraLlenado(llenado: nodo.llenado, estado: nodo.estado),
                ],
              ),
            ),
            const SizedBox(width: 16),
            Text(
              '${nodo.llenado!.round()}%',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: Theme.of(context)
                    .extension<ColoresEstado>()!
                    .para(nodo.estado)
                    .color,
                fontWeight: FontWeight.w700,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _VacioGrafico extends StatelessWidget {
  const _VacioGrafico();
  @override
  Widget build(BuildContext context) =>
      const Center(child: Text('No hay datos suficientes para graficar.'));
}

class _MensajeInforme extends StatelessWidget {
  const _MensajeInforme({required this.mensaje});
  final String mensaje;
  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Text(mensaje, textAlign: TextAlign.center),
    ),
  );
}

String _nombreEstado(EstadoNodo estado) => switch (estado) {
  EstadoNodo.critico => 'Críticos',
  EstadoNodo.alerta => 'Alertas',
  EstadoNodo.normal => 'Normales',
  EstadoNodo.sinDatos => 'Sin datos',
};

String _formatoNumero(double valor) => valor == valor.roundToDouble()
    ? valor.round().toString()
    : valor.toStringAsFixed(1);

String _zonaCorta(String zona) => switch (zona) {
  'Víctor Larco' => 'V. Larco',
  'La Esperanza' => 'Esperanza',
  'El Porvenir' => 'Porvenir',
  _ => zona,
};
