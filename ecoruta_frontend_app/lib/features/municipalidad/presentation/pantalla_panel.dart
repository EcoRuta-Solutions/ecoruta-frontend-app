import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../data/modelos_panel.dart';
import 'pantalla_detalle_contenedor.dart';
import 'panel_controller.dart';
import 'widgets/tarjeta_contenedor.dart';
import 'widgets/tarjeta_metrica.dart';
import 'widgets/estados_panel.dart';

enum _FiltroPanel { todos, criticos, alertas, normales, sinDatos }

class PantallaPanel extends ConsumerStatefulWidget {
  const PantallaPanel({super.key});

  @override
  ConsumerState<PantallaPanel> createState() => _PantallaPanelState();
}

class _PantallaPanelState extends ConsumerState<PantallaPanel> {
  _FiltroPanel _filtro = _FiltroPanel.todos;

  @override
  Widget build(BuildContext context) {
    final panel = ref.watch(panelControllerProvider);
    final onRefresh = ref.read(panelControllerProvider.notifier).recargar;

    return panel.when(
      loading: () => _envolver(
        onRefresh: onRefresh,
        slivers: const [SliverToBoxAdapter(child: EsqueletoPanel())],
      ),
      error: (error, stackTrace) => _envolver(
        onRefresh: onRefresh,
        slivers: [SliverToBoxAdapter(child: ErrorPanel(onRetry: onRefresh))],
      ),
      data: (datos) {
        final nodos = _nodosFiltrados(datos.nodos);
        return _envolver(
          onRefresh: onRefresh,
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.only(bottom: 24),
              sliver: SliverToBoxAdapter(child: _encabezado()),
            ),
            SliverPadding(
              padding: const EdgeInsets.only(bottom: 24),
              sliver: SliverToBoxAdapter(child: _resumen(datos.resumen)),
            ),
            SliverPadding(
              padding: const EdgeInsets.only(bottom: 16),
              sliver: SliverToBoxAdapter(child: _filtros()),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Text(
                  'Contenedores',
                  style: Theme.of(context).textTheme.titleLarge
                      ?.copyWith(color: EcoColors.texto),
                ),
              ),
            ),
            if (nodos.isEmpty)
              SliverToBoxAdapter(child: _vacio())
            else
              SliverList.builder(
                itemCount: nodos.length,
                itemBuilder: (context, index) {
                  final nodo = nodos[index];
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: TarjetaContenedor(
                      nodo: nodo,
                      onTap: () => _mostrarDetalle(nodo),
                    ),
                  );
                },
              ),
          ],
        );
      },
    );
  }

  Widget _envolver({
    required Future<void> Function() onRefresh,
    required List<Widget> slivers,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final margen = constraints.maxWidth < EcoLayout.anchoCompacto
            ? 16.0
            : 24.0;
        return Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: EcoLayout.anchoContenido,
            ),
            child: RefreshIndicator(
              onRefresh: onRefresh,
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
      },
    );
  }

  Widget _encabezado() {
    return Row(
      children: [
        Expanded(
          child: Text(
            'Panel',
            style: Theme.of(context).textTheme.headlineMedium
                ?.copyWith(color: EcoColors.primario),
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: EcoColors.acento.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(24),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.circle, color: EcoColors.acento, size: 8),
              const SizedBox(width: 8),
              Text(
                'En vivo',
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: EcoColors.primario,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _resumen(ResumenPanel resumen) {
    final extension = Theme.of(context).extension<ColoresEstado>()!;
    final metricas = [
      (
        etiqueta: 'Críticos',
        valor: resumen.criticos,
        estado: EstadoNodo.critico,
      ),
      (etiqueta: 'Alertas', valor: resumen.alertas, estado: EstadoNodo.alerta),
      (
        etiqueta: 'Normales',
        valor: resumen.normales,
        estado: EstadoNodo.normal,
      ),
      (
        etiqueta: 'Sin datos',
        valor: resumen.sinDatos,
        estado: EstadoNodo.sinDatos,
      ),
    ];
    final teal = EcoColors.acento;

    return Column(
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Promedio de llenado',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(color: EcoColors.textoSecundario),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        resumen.promedioLlenado == null
                            ? '—'
                            : '${resumen.promedioLlenado!.round()}%',
                        style: Theme.of(context).textTheme.displaySmall
                            ?.copyWith(
                              color: EcoColors.primario,
                              fontWeight: FontWeight.w700,
                              fontFeatures: const [
                                FontFeature.tabularFigures(),
                              ],
                            ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'De ${resumen.nodosConDatos} contenedores con datos',
                        style: Theme.of(context).textTheme.bodySmall
                            ?.copyWith(color: EcoColors.textoSecundario),
                      ),
                    ],
                  ),
                ),
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: teal.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(
                    Icons.analytics_outlined,
                    color: extension.normal.color,
                    size: 26,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        GridView.count(
          crossAxisCount: 2,
          mainAxisSpacing: 16,
          crossAxisSpacing: 16,
          mainAxisExtent: 136,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          children: [
            for (final metrica in metricas)
              TarjetaMetrica(
                etiqueta: metrica.etiqueta,
                valor: metrica.valor,
                estado: metrica.estado,
              ),
          ],
        ),
      ],
    );
  }

  Widget _filtros() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final filtro in _FiltroPanel.values) ...[
            if (filtro != _FiltroPanel.todos) const SizedBox(width: 8),
            _chipFiltro(filtro),
          ],
        ],
      ),
    );
  }

  Widget _chipFiltro(_FiltroPanel filtro) {
    final seleccionado = _filtro == filtro;
    final estado = switch (filtro) {
      _FiltroPanel.criticos => EstadoNodo.critico,
      _FiltroPanel.alertas => EstadoNodo.alerta,
      _FiltroPanel.normales => EstadoNodo.normal,
      _FiltroPanel.sinDatos => EstadoNodo.sinDatos,
      _FiltroPanel.todos => null,
    };
    final color = estado == null
        ? EcoColors.primario
        : Theme.of(context).extension<ColoresEstado>()!.para(estado).color;

    return ChoiceChip(
      label: Text(_nombreFiltro(filtro)),
      selected: seleccionado,
      showCheckmark: false,
      onSelected: (_) => setState(() => _filtro = filtro),
      selectedColor: color.withValues(alpha: 0.12),
      backgroundColor: EcoColors.superficie,
      side: BorderSide(
        color: seleccionado ? color.withValues(alpha: 0.35) : EcoColors.borde,
      ),
      labelStyle: Theme.of(context).textTheme.labelMedium?.copyWith(
        color: seleccionado ? color : EcoColors.textoSecundario,
        fontWeight: seleccionado ? FontWeight.w700 : FontWeight.w500,
      ),
    );
  }

  Widget _vacio() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: EcoColors.superficie,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: EcoColors.borde),
      ),
      child: Column(
        children: [
          Icon(
            Icons.filter_alt_off_outlined,
            size: 32,
            color: EcoColors.textoSecundario,
          ),
          const SizedBox(height: 16),
          Text(
            'No hay contenedores en este filtro',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium
                ?.copyWith(color: EcoColors.textoSecundario),
          ),
        ],
      ),
    );
  }

  List<NodoEstado> _nodosFiltrados(List<NodoEstado> origen) {
    final estadoFiltro = switch (_filtro) {
      _FiltroPanel.criticos => EstadoNodo.critico,
      _FiltroPanel.alertas => EstadoNodo.alerta,
      _FiltroPanel.normales => EstadoNodo.normal,
      _FiltroPanel.sinDatos => EstadoNodo.sinDatos,
      _FiltroPanel.todos => null,
    };
    final nodos =
        origen
            .where(
              (nodo) => estadoFiltro == null || nodo.estado == estadoFiltro,
            )
            .toList()
          ..sort((a, b) {
            final gravedad = a.estado.index.compareTo(b.estado.index);
            if (gravedad != 0) return gravedad;
            return (b.llenado ?? -1).compareTo(a.llenado ?? -1);
          });
    return nodos;
  }

  String _nombreFiltro(_FiltroPanel filtro) => switch (filtro) {
    _FiltroPanel.todos => 'Todos',
    _FiltroPanel.criticos => 'Críticos',
    _FiltroPanel.alertas => 'Alertas',
    _FiltroPanel.normales => 'Normales',
    _FiltroPanel.sinDatos => 'Sin datos',
  };

  void _mostrarDetalle(NodoEstado nodo) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => PantallaDetalleContenedor(nodoId: nodo.id),
      ),
    );
  }
}
