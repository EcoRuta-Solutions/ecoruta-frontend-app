import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../data/modelos_alerta.dart';
import '../data/modelos_flota.dart';
import '../data/modelos_panel.dart';
import 'controladores_dominio.dart';
import 'panel_controller.dart';
import 'pantalla_detalle_contenedor.dart';
import 'widgets/estados_panel.dart';
import 'widgets/tarjeta_alerta.dart';

class PantallaAlertas extends ConsumerStatefulWidget {
  const PantallaAlertas({super.key});

  @override
  ConsumerState<PantallaAlertas> createState() => _PantallaAlertasState();
}

class _PantallaAlertasState extends ConsumerState<PantallaAlertas> {
  bool _mostrarHistorial = false;
  TipoAlerta? _tipo;
  EstadoAlerta? _estado;

  @override
  Widget build(BuildContext context) {
    final alertasState = ref.watch(alertasControllerProvider);
    final panelState = ref.watch(panelControllerProvider);
    final ancho = MediaQuery.sizeOf(context).width;
    final margen = ancho < EcoLayout.anchoCompacto ? 16.0 : 24.0;

    if (alertasState.isLoading || panelState.isLoading) {
      return _contenedor(margen, const [
        SliverToBoxAdapter(child: EsqueletoPanel()),
      ]);
    }
    if (alertasState.hasError || panelState.hasError) {
      return _contenedor(margen, [
        SliverToBoxAdapter(child: ErrorPanel(onRetry: _recargar)),
      ]);
    }

    final alertas = alertasState.requireValue;
    final nodos = panelState.requireValue.nodos;
    final filtradas = _filtrar(alertas, nodos);
    final activasSinReconocer = alertas
        .where((alerta) => alerta.activaSinReconocer)
        .length;

    return _contenedor(margen, [
      SliverToBoxAdapter(
        child: _EncabezadoAlertas(cantidad: activasSinReconocer),
      ),
      SliverPadding(
        padding: const EdgeInsets.only(bottom: 16),
        sliver: SliverToBoxAdapter(child: _selectorBandeja()),
      ),
      SliverPadding(
        padding: const EdgeInsets.only(bottom: 8),
        sliver: SliverToBoxAdapter(
          child: _FilaFiltro<TipoAlerta>(
            titulo: 'Severidad',
            opciones: [
              (null, 'Todas'),
              for (final tipo in TipoAlerta.values) (tipo, _nombreTipo(tipo)),
            ],
            seleccionado: _tipo,
            onSeleccion: (valor) => setState(() => _tipo = valor),
          ),
        ),
      ),
      SliverPadding(
        padding: const EdgeInsets.only(bottom: 24),
        sliver: SliverToBoxAdapter(
          child: _FilaFiltro<EstadoAlerta>(
            titulo: 'Estado',
            opciones: [
              (null, 'Todos'),
              for (final estado in EstadoAlerta.values)
                (estado, _nombreEstado(estado)),
            ],
            seleccionado: _estado,
            onSeleccion: (valor) => setState(() => _estado = valor),
          ),
        ),
      ),
      if (filtradas.isEmpty)
        SliverToBoxAdapter(child: _SinAlertas(historial: _mostrarHistorial))
      else
        SliverList.builder(
          itemCount: filtradas.length,
          itemBuilder: (context, index) {
            final alerta = filtradas[index];
            final nodo = nodos.firstWhere(
              (element) => element.id == alerta.nodoId,
            );
            return Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: TarjetaAlerta(
                alerta: alerta,
                nodo: nodo,
                onTap: () => _mostrarDetalle(context, alerta, nodo),
              ),
            );
          },
        ),
    ]);
  }

  Widget _contenedor(double margen, List<Widget> slivers) => Center(
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: EcoLayout.anchoContenido),
      child: RefreshIndicator(
        onRefresh: _recargar,
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

  Widget _selectorBandeja() => SegmentedButton<bool>(
    segments: const [
      ButtonSegment(value: false, label: Text('Activas')),
      ButtonSegment(value: true, label: Text('Historial')),
    ],
    selected: {_mostrarHistorial},
    onSelectionChanged: (seleccion) {
      setState(() {
        _mostrarHistorial = seleccion.first;
        _estado = null;
        _tipo = null;
      });
    },
  );

  List<AlertaPanel> _filtrar(
    List<AlertaPanel> alertas,
    List<NodoEstado> nodos,
  ) {
    final idsNodos = nodos.map((nodo) => nodo.id).toSet();
    final resultado = alertas.where((alerta) {
      final enBandeja = _mostrarHistorial
          ? alerta.estado == EstadoAlerta.atendida
          : alerta.estado != EstadoAlerta.atendida;
      return enBandeja &&
          (_tipo == null || alerta.tipo == _tipo) &&
          (_estado == null || alerta.estado == _estado) &&
          idsNodos.contains(alerta.nodoId);
    }).toList();
    resultado.sort((a, b) {
      final gravedad = _prioridad(a.tipo).compareTo(_prioridad(b.tipo));
      if (gravedad != 0) return gravedad;
      final llenadoA = nodos.firstWhere((nodo) => nodo.id == a.nodoId).llenado;
      final llenadoB = nodos.firstWhere((nodo) => nodo.id == b.nodoId).llenado;
      return (llenadoB ?? -1).compareTo(llenadoA ?? -1);
    });
    return resultado;
  }

  Future<void> _recargar() async {
    ref.invalidate(alertasControllerProvider);
    ref.invalidate(panelControllerProvider);
    await Future.wait([
      ref.read(alertasControllerProvider.future),
      ref.read(panelControllerProvider.future),
    ]);
  }

  void _mostrarDetalle(
    BuildContext context,
    AlertaPanel alerta,
    NodoEstado nodo,
  ) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      backgroundColor: EcoColors.superficie,
      builder: (_) => _DetalleAlerta(alerta: alerta, nodo: nodo),
    );
  }
}

class _FilaFiltro<T extends Object> extends StatelessWidget {
  const _FilaFiltro({
    required this.titulo,
    required this.opciones,
    required this.seleccionado,
    required this.onSeleccion,
  });

  final String titulo;
  final List<(T?, String)> opciones;
  final T? seleccionado;
  final ValueChanged<T?> onSeleccion;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        titulo,
        style: Theme.of(context).textTheme.labelLarge
            ?.copyWith(color: EcoColors.textoSecundario),
      ),
      const SizedBox(height: 8),
      SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            for (var indice = 0; indice < opciones.length; indice++) ...[
              if (indice > 0) const SizedBox(width: 8),
              ChoiceChip(
                label: Text(opciones[indice].$2),
                selected: opciones[indice].$1 == seleccionado,
                onSelected: (_) => onSeleccion(opciones[indice].$1),
              ),
            ],
          ],
        ),
      ),
    ],
  );
}

class _EncabezadoAlertas extends StatelessWidget {
  const _EncabezadoAlertas({required this.cantidad});

  final int cantidad;

  @override
  Widget build(BuildContext context) {
    final visual = Theme.of(context).extension<ColoresEstado>()!.critico;
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Row(
        children: [
          Expanded(
            child: Text(
              'Alertas',
              style: Theme.of(context).textTheme.headlineMedium
                  ?.copyWith(color: EcoColors.primario),
            ),
          ),
          Container(
            constraints: const BoxConstraints(minHeight: 40),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: visual.fondo,
              borderRadius: BorderRadius.circular(24),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(visual.icono, size: 16, color: visual.color),
                const SizedBox(width: 8),
                Text(
                  '$cantidad activas',
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: visual.color,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SinAlertas extends StatelessWidget {
  const _SinAlertas({required this.historial});

  final bool historial;

  @override
  Widget build(BuildContext context) {
    final colores = Theme.of(context).extension<ColoresEstado>()!;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 72, horizontal: 24),
      child: Column(
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: colores.normal.fondo,
              shape: BoxShape.circle,
            ),
            child: Icon(
              historial
                  ? Icons.history_rounded
                  : Icons.notifications_active_outlined,
              color: colores.normal.color,
              size: 36,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            historial ? 'Sin alertas en el historial' : 'Sin alertas activas',
            style: Theme.of(context).textTheme.titleLarge
                ?.copyWith(color: EcoColors.primario),
          ),
          const SizedBox(height: 8),
          Text(
            'Prueba con otros filtros para consultar más alertas.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium
                ?.copyWith(color: EcoColors.textoSecundario),
          ),
        ],
      ),
    );
  }
}

class _DetalleAlerta extends ConsumerWidget {
  const _DetalleAlerta({required this.alerta, required this.nodo});

  final AlertaPanel alerta;
  final NodoEstado nodo;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final alertas = ref.watch(alertasControllerProvider).asData?.value ?? [];
    final actual =
        alertas.where((item) => item.id == alerta.id).firstOrNull ?? alerta;
    final flota = ref.watch(flotaControllerProvider).asData?.value;
    final ancho = MediaQuery.sizeOf(context).width;

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
                nodo.nombre,
                style: Theme.of(context).textTheme.titleLarge
                    ?.copyWith(color: EcoColors.primario),
              ),
              const SizedBox(height: 8),
              Text('${nodo.codigo} · ${nodo.zona}'),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _EstadoAlertaChip(estado: actual.estado),
                  _MotivoChip(tipo: actual.tipo),
                ],
              ),
              const SizedBox(height: 16),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Expanded(child: Text('Llenado actual')),
                      Text(
                        nodo.llenado == null
                            ? '—'
                            : '${nodo.llenado!.round()}%',
                        style: Theme.of(context).textTheme.titleLarge
                            ?.copyWith(color: EcoColors.primario),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Historial de acciones',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              if (actual.historial.isEmpty)
                const Text('Aún no hay acciones registradas.')
              else
                for (final accion in actual.historial)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(
                      Icons.check_circle_outline,
                      color: Theme.of(context)
                          .extension<ColoresProceso>()!
                          .para(EstadoProcesoPanel.reconocida)
                          .color,
                    ),
                    title: Text(accion.que),
                    subtitle: Text(
                      '${accion.quien} · ${accion.cuando.day}/${accion.cuando.month} '
                      '${accion.cuando.hour.toString().padLeft(2, '0')}:'
                      '${accion.cuando.minute.toString().padLeft(2, '0')}'
                      '${accion.nota == null ? '' : '\n${accion.nota}'}',
                    ),
                  ),
              const SizedBox(height: 16),
              if (actual.estado == EstadoAlerta.nueva)
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: () => _ejecutarAccion(
                      context,
                      () => ref
                          .read(alertasControllerProvider.notifier)
                          .reconocer(actual.id, quien: 'Operador municipal'),
                      'Alerta reconocida.',
                    ),
                    icon: const Icon(Icons.visibility_outlined),
                    label: const Text('Reconocer'),
                  ),
                ),
              if (actual.estado == EstadoAlerta.reconocida)
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: flota == null
                        ? null
                        : () => _asignar(context, ref, actual, flota),
                    icon: const Icon(Icons.person_add_alt_1_rounded),
                    label: const Text('Asignar a un conductor'),
                  ),
                ),
              if (actual.estado == EstadoAlerta.asignada)
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: () => _atender(context, ref, actual),
                    icon: const Icon(Icons.task_alt_rounded),
                    label: const Text('Marcar como atendida'),
                  ),
                ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () {
                    Navigator.of(context).pop();
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) =>
                            PantallaDetalleContenedor(nodoId: nodo.id),
                      ),
                    );
                  },
                  icon: const Icon(Icons.open_in_new_rounded),
                  label: const Text('Abrir contenedor'),
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
    AlertaPanel alerta,
    DatosFlota flota,
  ) async {
    final opciones = [
      for (final conductor in flota.conductores)
        if (conductor.estado == EstadoConductor.disponible)
          for (final vehiculo in flota.vehiculos)
            if (vehiculo.id == conductor.vehiculoAsignado &&
                vehiculo.estado == EstadoVehiculo.operativo)
              (conductor: conductor, vehiculo: vehiculo),
    ];
    if (opciones.isEmpty) {
      _mensaje(context, 'No hay conductores y vehículos disponibles.');
      return;
    }
    final seleccion =
        await showDialog<({Conductor conductor, Vehiculo vehiculo})>(
          context: context,
          builder: (context) => SimpleDialog(
            title: const Text('Asignar alerta'),
            children: [
              for (final opcion in opciones)
                SimpleDialogOption(
                  onPressed: () => Navigator.pop(context, opcion),
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(opcion.conductor.nombre),
                    subtitle: Text(
                      '${opcion.vehiculo.placa} · ${opcion.vehiculo.tipo}',
                    ),
                    trailing: const Icon(Icons.chevron_right_rounded),
                  ),
                ),
            ],
          ),
        );
    if (seleccion == null || !context.mounted) return;
    await _ejecutarAccion(
      context,
      () => ref
          .read(alertasControllerProvider.notifier)
          .asignar(
            alerta.id,
            conductor: seleccion.conductor,
            vehiculo: seleccion.vehiculo,
            quien: 'Operador municipal',
          ),
      'Alerta asignada a ${seleccion.conductor.nombre}.',
    );
  }

  Future<void> _atender(
    BuildContext context,
    WidgetRef ref,
    AlertaPanel alerta,
  ) async {
    final nota = await _pedirNota(context);
    if (nota == null || !context.mounted) return;
    await _ejecutarAccion(
      context,
      () => ref
          .read(alertasControllerProvider.notifier)
          .atender(
            alerta.id,
            quien: 'Operador municipal',
            nota: nota.isEmpty ? null : nota,
          ),
      'Alerta marcada como atendida.',
    );
  }
}

class _EstadoAlertaChip extends StatelessWidget {
  const _EstadoAlertaChip({required this.estado});

  final EstadoAlerta estado;

  @override
  Widget build(BuildContext context) {
    final proceso = switch (estado) {
      EstadoAlerta.nueva => EstadoProcesoPanel.nueva,
      EstadoAlerta.reconocida => EstadoProcesoPanel.reconocida,
      EstadoAlerta.asignada => EstadoProcesoPanel.asignada,
      EstadoAlerta.atendida => EstadoProcesoPanel.atendida,
    };
    return _ChipProceso(
      visual: Theme.of(context).extension<ColoresProceso>()!.para(proceso),
      texto: _nombreEstado(estado),
    );
  }
}

class _MotivoChip extends StatelessWidget {
  const _MotivoChip({required this.tipo});

  final TipoAlerta tipo;

  @override
  Widget build(BuildContext context) {
    final estado = switch (tipo) {
      TipoAlerta.critico => EstadoNodo.critico,
      TipoAlerta.enAlerta ||
      TipoAlerta.volteado ||
      TipoAlerta.bateriaBaja => EstadoNodo.alerta,
      TipoAlerta.sinDatos => EstadoNodo.sinDatos,
    };
    final visual = Theme.of(context).extension<ColoresEstado>()!.para(estado);
    return _ChipProceso(visual: visual, texto: _nombreTipo(tipo));
  }
}

class _ChipProceso extends StatelessWidget {
  const _ChipProceso({required this.visual, required this.texto});

  final EstadoVisual visual;
  final String texto;

  @override
  Widget build(BuildContext context) => Container(
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
          texto,
          style: Theme.of(context).textTheme.labelMedium
              ?.copyWith(color: visual.color, fontWeight: FontWeight.w600),
        ),
      ],
    ),
  );
}

Future<void> _ejecutarAccion(
  BuildContext context,
  Future<void> Function() accion,
  String confirmacion,
) async {
  try {
    await accion();
    if (context.mounted) _mensaje(context, confirmacion);
  } on StateError catch (error) {
    if (context.mounted) _mensaje(context, error.message.toString());
  }
}

Future<String?> _pedirNota(BuildContext context) async {
  final controlador = TextEditingController();
  final nota = await showDialog<String>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Atender alerta'),
      content: TextField(
        controller: controlador,
        maxLines: 3,
        decoration: const InputDecoration(
          labelText: 'Nota (opcional)',
          hintText: 'Describe brevemente el trabajo realizado',
        ),
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

void _mensaje(BuildContext context, String texto) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(texto)));
}

int _prioridad(TipoAlerta tipo) => switch (tipo) {
  TipoAlerta.critico => 0,
  TipoAlerta.enAlerta => 1,
  TipoAlerta.volteado => 2,
  TipoAlerta.bateriaBaja => 3,
  TipoAlerta.sinDatos => 4,
};

String _nombreTipo(TipoAlerta tipo) => switch (tipo) {
  TipoAlerta.critico => 'Crítico',
  TipoAlerta.enAlerta => 'En alerta',
  TipoAlerta.volteado => 'Volteado',
  TipoAlerta.bateriaBaja => 'Batería baja',
  TipoAlerta.sinDatos => 'Sin datos',
};

String _nombreEstado(EstadoAlerta estado) => switch (estado) {
  EstadoAlerta.nueva => 'Nueva',
  EstadoAlerta.reconocida => 'Reconocida',
  EstadoAlerta.asignada => 'Asignada',
  EstadoAlerta.atendida => 'Atendida',
};
