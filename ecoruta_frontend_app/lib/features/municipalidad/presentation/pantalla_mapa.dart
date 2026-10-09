import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import 'dart:math' as math;

import '../../../core/theme/app_theme.dart';
import '../data/modelos_panel.dart';
import 'panel_controller.dart';
import 'panel_utils.dart';
import 'navegacion_controller.dart';
import 'pantalla_detalle_contenedor.dart';
import 'widgets/barra_llenado.dart';
import 'widgets/chip_estado.dart';
import 'widgets/estados_panel.dart';

class PantallaMapa extends ConsumerWidget {
  const PantallaMapa({super.key});

  static const _centro = LatLng(-8.1116, -79.0288);
  static const _idPaquete = 'com.ecoruta.app.ecoruta_frontend_app';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final panel = ref.watch(panelControllerProvider);
    final nodoEnFoco = ref.watch(navegacionMunicipalidadProvider).focoNodoId;
    final alRecargar = ref.read(panelControllerProvider.notifier).recargar;

    return panel.when(
      loading: () => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text(
              'Cargando ubicaciones',
              style: Theme.of(context).textTheme.bodyMedium
                  ?.copyWith(color: EcoColors.textoSecundario),
            ),
          ],
        ),
      ),
      error: (error, stackTrace) => ErrorPanel(onRetry: alRecargar),
      data: (datos) => _MapaCargado(nodos: datos.nodos, nodoEnFoco: nodoEnFoco),
    );
  }
}

class _MapaCargado extends ConsumerStatefulWidget {
  const _MapaCargado({required this.nodos, this.nodoEnFoco});

  final List<NodoEstado> nodos;
  final int? nodoEnFoco;

  @override
  ConsumerState<_MapaCargado> createState() => _MapaCargadoState();
}

class _MapaCargadoState extends ConsumerState<_MapaCargado>
    with SingleTickerProviderStateMixin {
  final MapController _controladorMapa = MapController();
  late final AnimationController _animacionMapa;
  late final Animation<double> _progresoMapa;
  final Set<EstadoNodo> _estados = EstadoNodo.values.toSet();
  String? _zona;
  double _zoom = 14;
  bool _errorTeselas = false;
  bool _filtrosExpandidos = false;
  int? _nodoEnfocado;
  LatLng? _origenAnimacion;
  LatLng? _destinoAnimacion;
  double _zoomOrigen = 14;
  double _zoomDestino = 14;

  @override
  void initState() {
    super.initState();
    _animacionMapa = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 360),
    );
    _progresoMapa = CurvedAnimation(
      parent: _animacionMapa,
      curve: Curves.easeInOutCubic,
    )..addListener(_actualizarCamara);
    _nodoEnfocado = widget.nodoEnFoco;
    WidgetsBinding.instance.addPostFrameCallback((_) => _centrarFoco());
  }

  @override
  void dispose() {
    _animacionMapa.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant _MapaCargado oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.nodoEnFoco != widget.nodoEnFoco) {
      _nodoEnfocado = widget.nodoEnFoco;
      _estados
        ..clear()
        ..addAll(EstadoNodo.values);
      _zona = null;
      WidgetsBinding.instance.addPostFrameCallback((_) => _centrarFoco());
    }
  }

  @override
  Widget build(BuildContext context) {
    final extension = Theme.of(context).extension<ColoresEstado>()!;
    final dibujables = widget.nodos
        .where(_tieneCoordenadas)
        .where((nodo) => _estados.contains(nodo.estado))
        .where((nodo) => _zona == null || nodo.zona == _zona)
        .toList();
    final grupos = _agrupar(dibujables);
    final zonas = widget.nodos.map((nodo) => nodo.zona).toSet().toList()
      ..sort();

    return Stack(
      children: [
        FlutterMap(
          mapController: _controladorMapa,
          options: MapOptions(
            initialCenter: PantallaMapa._centro,
            initialZoom: 14,
            interactionOptions: const InteractionOptions(
              flags: InteractiveFlag.all,
            ),
            onPositionChanged: (camera, _) =>
                setState(() => _zoom = camera.zoom),
          ),
          children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: PantallaMapa._idPaquete,
              errorTileCallback: (_, error, _) {
                debugPrint('No se pudo cargar una tesela del mapa: $error');
                if (mounted && !_errorTeselas) {
                  setState(() => _errorTeselas = true);
                }
              },
            ),
            MarkerLayer(
              markers: [
                for (final grupo in grupos)
                  if (grupo.nodos.length == 1)
                    Marker(
                      point: _punto(grupo.nodos.single)!,
                      width: 52,
                      height: 52,
                      child: _MarcadorNodo(
                        nodo: grupo.nodos.single,
                        resaltado: grupo.nodos.single.id == _nodoEnfocado,
                        onTap: () =>
                            _mostrarDetalle(context, grupo.nodos.single),
                      ),
                    )
                  else
                    Marker(
                      point: grupo.centro,
                      width: 56,
                      height: 56,
                      child: _MarcadorGrupo(
                        cantidad: grupo.nodos.length,
                        onTap: () => _acercarGrupo(grupo),
                      ),
                    ),
              ],
            ),
          ],
        ),
        SafeArea(
          child: Align(
            alignment: Alignment.topLeft,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: _FiltrosMapa(
                estados: _estados,
                zonas: zonas,
                zona: _zona,
                expandido: _filtrosExpandidos,
                onAlternar: () =>
                    setState(() => _filtrosExpandidos = !_filtrosExpandidos),
                onCambiarEstado: (estado, activo) => setState(() {
                  if (activo) {
                    _estados.add(estado);
                  } else {
                    _estados.remove(estado);
                  }
                }),
                onCambiarZona: (zona) => setState(() => _zona = zona),
                onLimpiar: () => setState(() {
                  _estados
                    ..clear()
                    ..addAll(EstadoNodo.values);
                  _zona = null;
                }),
              ),
            ),
          ),
        ),
        SafeArea(
          child: Align(
            alignment: Alignment.topRight,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: _ConteoMarcadores(cantidad: dibujables.length),
            ),
          ),
        ),
        if (_errorTeselas)
          SafeArea(
            child: Align(
              alignment: Alignment.topCenter,
              child: Padding(
                padding: const EdgeInsets.only(top: 72, left: 16, right: 16),
                child: Material(
                  color: EcoColors.primario,
                  borderRadius: BorderRadius.circular(12),
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: Text(
                      'El mapa base no está disponible. Los nodos siguen visibles.',
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                ),
              ),
            ),
          ),
        SafeArea(
          child: Align(
            alignment: Alignment.bottomLeft,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 64),
              child: _LeyendaMapa(extension: extension),
            ),
          ),
        ),
        SafeArea(
          child: Align(
            alignment: Alignment.bottomRight,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  child: Text(
                    '© OpenStreetMap',
                    style: Theme.of(context).textTheme.labelSmall
                        ?.copyWith(color: EcoColors.textoSecundario),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  void _centrarFoco() {
    if (!mounted) return;
    final id = _nodoEnfocado;
    final nodo = id == null
        ? null
        : widget.nodos.where((element) => element.id == id).firstOrNull;
    final punto = nodo == null ? null : _punto(nodo);
    if (punto == null) return;
    _origenAnimacion = _controladorMapa.camera.center;
    _destinoAnimacion = punto;
    _zoomOrigen = _controladorMapa.camera.zoom;
    _zoomDestino = math.max(_zoom, 16).toDouble();
    _animacionMapa.forward(from: 0);
  }

  void _actualizarCamara() {
    final origen = _origenAnimacion;
    final destino = _destinoAnimacion;
    if (origen == null || destino == null) return;
    final progreso = _progresoMapa.value;
    _controladorMapa.move(
      LatLng(
        origen.latitude + (destino.latitude - origen.latitude) * progreso,
        origen.longitude + (destino.longitude - origen.longitude) * progreso,
      ),
      _zoomOrigen + (_zoomDestino - _zoomOrigen) * progreso,
    );
  }

  void _acercarGrupo(_GrupoMarcadores grupo) {
    _controladorMapa.move(grupo.centro, math.min(_zoom + 2, 18));
  }

  List<_GrupoMarcadores> _agrupar(List<NodoEstado> nodos) {
    final paso = 0.02 / math.pow(2, math.max(0, _zoom - 10) / 2);
    final grupos = <(int, int), List<NodoEstado>>{};
    for (final nodo in nodos) {
      final punto = _punto(nodo)!;
      final celda = (
        (punto.latitude / paso).floor(),
        (punto.longitude / paso).floor(),
      );
      grupos.putIfAbsent(celda, () => []).add(nodo);
    }
    return [
      for (final grupo in grupos.values)
        _GrupoMarcadores(
          nodos: grupo,
          centro: LatLng(
            grupo.map((nodo) => nodo.latitud!).reduce((a, b) => a + b) /
                grupo.length,
            grupo.map((nodo) => nodo.longitud!).reduce((a, b) => a + b) /
                grupo.length,
          ),
        ),
    ];
  }

  bool _tieneCoordenadas(NodoEstado nodo) => _punto(nodo) != null;

  LatLng? _punto(NodoEstado nodo) {
    final latitud = nodo.latitud;
    final longitud = nodo.longitud;
    if (latitud == null ||
        longitud == null ||
        !latitud.isFinite ||
        !longitud.isFinite ||
        latitud < -90 ||
        latitud > 90 ||
        longitud < -180 ||
        longitud > 180) {
      return null;
    }
    return LatLng(latitud, longitud);
  }

  void _mostrarDetalle(BuildContext context, NodoEstado nodo) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      backgroundColor: EcoColors.superficie,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => _DetalleNodo(
        nodo: nodo,
        onAbrirDetalle: () {
          Navigator.of(context).pop();
          Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => PantallaDetalleContenedor(nodoId: nodo.id),
            ),
          );
        },
      ),
    );
  }
}

class _GrupoMarcadores {
  const _GrupoMarcadores({required this.nodos, required this.centro});
  final List<NodoEstado> nodos;
  final LatLng centro;
}

class _MarcadorGrupo extends StatelessWidget {
  const _MarcadorGrupo({required this.cantidad, required this.onTap});

  final int cantidad;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: '$cantidad contenedores agrupados. Acercar el mapa.',
    child: Material(
      color: EcoColors.primario,
      shape: const CircleBorder(),
      elevation: 3,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Center(
          child: Text(
            '$cantidad',
            style: Theme.of(context).textTheme.titleMedium
                ?.copyWith(color: Colors.white, fontWeight: FontWeight.w700),
          ),
        ),
      ),
    ),
  );
}

class _FiltrosMapa extends StatelessWidget {
  const _FiltrosMapa({
    required this.estados,
    required this.zonas,
    required this.zona,
    required this.onCambiarEstado,
    required this.onCambiarZona,
    required this.onLimpiar,
    required this.expandido,
    required this.onAlternar,
  });

  final Set<EstadoNodo> estados;
  final List<String> zonas;
  final String? zona;
  final void Function(EstadoNodo, bool) onCambiarEstado;
  final ValueChanged<String?> onCambiarZona;
  final VoidCallback onLimpiar;
  final bool expandido;
  final VoidCallback onAlternar;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                tooltip: expandido ? 'Contraer filtros' : 'Mostrar filtros',
                constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
                onPressed: onAlternar,
                icon: Icon(
                  expandido
                      ? Icons.filter_alt_off_outlined
                      : Icons.filter_alt_outlined,
                ),
              ),
              if (expandido)
                SizedBox(
                  width: 168,
                  child: DropdownButton<String?>(
                    isExpanded: true,
                    value: zona,
                    hint: const Text(
                      'Todas las zonas',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    items: [
                      const DropdownMenuItem<String?>(
                        value: null,
                        child: Text(
                          'Todas las zonas',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      for (final item in zonas)
                        DropdownMenuItem(
                          value: item,
                          child: Text(
                            item,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                    ],
                    onChanged: onCambiarZona,
                  ),
                )
              else
                Text(
                  zona ?? 'Filtros',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelLarge,
                ),
              if (expandido)
                IconButton(
                  tooltip: 'Limpiar filtros',
                  onPressed: onLimpiar,
                  icon: const Icon(Icons.restart_alt_rounded),
                ),
            ],
          ),
          if (expandido)
            SizedBox(
              width: 280,
              height: 48,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  for (final estado in EstadoNodo.values)
                    Padding(
                      padding: const EdgeInsets.only(right: 4),
                      child: FilterChip(
                        label: Text(_nombreEstado(estado)),
                        selected: estados.contains(estado),
                        onSelected: (activo) => onCambiarEstado(estado, activo),
                        visualDensity: VisualDensity.compact,
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

class _MarcadorNodo extends StatelessWidget {
  const _MarcadorNodo({
    required this.nodo,
    required this.onTap,
    this.resaltado = false,
  });

  final NodoEstado nodo;
  final VoidCallback onTap;
  final bool resaltado;

  @override
  Widget build(BuildContext context) {
    final visual = Theme.of(context)
        .extension<ColoresEstado>()!
        .para(nodo.estado);

    return Semantics(
      button: true,
      label:
          'Contenedor ${nodo.codigo}, ${_nombreEstado(nodo.estado)}'
          '${resaltado ? ', seleccionado' : ''}',
      child: Tooltip(
        message: '${nodo.nombre} · ${nodo.codigo}',
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            customBorder: const CircleBorder(),
            child: Center(
              child: Container(
                width: resaltado ? 48 : 42,
                height: resaltado ? 48 : 42,
                decoration: BoxDecoration(
                  color: visual.color,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: resaltado ? EcoColors.acento : EcoColors.superficie,
                    width: resaltado ? 4 : 3,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: EcoColors.primario.withValues(alpha: 0.24),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Icon(visual.icono, color: Colors.white, size: 20),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ConteoMarcadores extends StatelessWidget {
  const _ConteoMarcadores({required this.cantidad});

  final int cantidad;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.location_on_outlined, color: EcoColors.primario),
            const SizedBox(width: 8),
            Text(
              '$cantidad contenedores',
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: EcoColors.primario,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LeyendaMapa extends StatelessWidget {
  const _LeyendaMapa({required this.extension});

  final ColoresEstado extension;

  @override
  Widget build(BuildContext context) {
    final estados = [
      (EstadoNodo.critico, 'Crítico'),
      (EstadoNodo.alerta, 'Alerta'),
      (EstadoNodo.normal, 'Normal'),
      (EstadoNodo.sinDatos, 'Sin datos'),
    ];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Wrap(
          spacing: 16,
          runSpacing: 8,
          children: [
            for (final (estado, etiqueta) in estados)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    extension.para(estado).icono,
                    size: 16,
                    color: extension.para(estado).color,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    etiqueta,
                    style: Theme.of(context).textTheme.labelSmall
                        ?.copyWith(color: EcoColors.texto),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

class _DetalleNodo extends StatelessWidget {
  const _DetalleNodo({required this.nodo, required this.onAbrirDetalle});

  final NodoEstado nodo;
  final VoidCallback onAbrirDetalle;

  @override
  Widget build(BuildContext context) {
    final ancho = MediaQuery.sizeOf(context).width;
    final visual = Theme.of(context)
        .extension<ColoresEstado>()!
        .para(nodo.estado);

    return SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              ancho < EcoLayout.anchoCompacto ? 24 : 32,
              8,
              ancho < EcoLayout.anchoCompacto ? 24 : 32,
              32,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        nodo.nombre,
                        style: Theme.of(context).textTheme.titleLarge
                            ?.copyWith(color: EcoColors.primario),
                      ),
                    ),
                    Icon(visual.icono, color: visual.color),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  nodo.codigo,
                  style: Theme.of(context).textTheme.bodyMedium
                      ?.copyWith(color: EcoColors.textoSecundario),
                ),
                const SizedBox(height: 24),
                Text(
                  nodo.llenado == null ? '—' : '${nodo.llenado!.round()}%',
                  style: Theme.of(context).textTheme.displaySmall?.copyWith(
                    color: visual.color,
                    fontWeight: FontWeight.w700,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
                const SizedBox(height: 16),
                BarraLlenado(llenado: nodo.llenado, estado: nodo.estado),
                const SizedBox(height: 16),
                Row(
                  children: [
                    ChipEstado(estado: nodo.estado),
                    const Spacer(),
                    Text(
                      tiempoDesdeLectura(nodo.ultimaLectura),
                      style: Theme.of(context).textTheme.labelMedium
                          ?.copyWith(color: EcoColors.textoSecundario),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: onAbrirDetalle,
                    icon: const Icon(Icons.open_in_new_rounded),
                    label: const Text('Ver detalle'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

String _nombreEstado(EstadoNodo estado) => switch (estado) {
  EstadoNodo.critico => 'Crítico',
  EstadoNodo.alerta => 'En alerta',
  EstadoNodo.normal => 'Normal',
  EstadoNodo.sinDatos => 'Sin datos',
};
