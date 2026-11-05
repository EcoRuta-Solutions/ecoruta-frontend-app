import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/config/app_config.dart';
import '../../../core/navegacion/navegacion_externa.dart';
import '../../../core/theme/app_theme.dart';
import '../data/modelos_puntos_criticos.dart';
import 'pantalla_mapa.dart';
import 'puntos_criticos_providers.dart';
import 'widgets/aviso_datos_ejemplo.dart';
import 'widgets/estados_panel.dart';

/// Capa del mapa municipal con los puntos críticos de acumulación.
class MapaPuntosCriticos extends ConsumerWidget {
  const MapaPuntosCriticos({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final puntos = ref.watch(puntosCriticosProvider);

    return puntos.when(
      loading: () => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text(
              'Cargando puntos críticos',
              style: Theme.of(context).textTheme.bodyMedium
                  ?.copyWith(color: EcoColors.textoSecundario),
            ),
          ],
        ),
      ),
      error: (error, stackTrace) =>
          ErrorPanel(onRetry: () => ref.invalidate(puntosCriticosProvider)),
      data: (lista) => _MapaPuntosCargado(puntos: lista),
    );
  }
}

class _MapaPuntosCargado extends StatefulWidget {
  const _MapaPuntosCargado({required this.puntos});

  final List<PuntoCritico> puntos;

  @override
  State<_MapaPuntosCargado> createState() => _MapaPuntosCargadoState();
}

class _MapaPuntosCargadoState extends State<_MapaPuntosCargado> {
  final MapController _controladorMapa = MapController();
  FiltroPuntosCriticos _filtro = FiltroPuntosCriticos.todos;
  bool _errorTeselas = false;

  static const _margenCamara = EdgeInsets.fromLTRB(40, 160, 40, 150);

  List<PuntoCritico> get _visibles {
    final lista = filtrarPuntosCriticos(
      widget.puntos.where((punto) => punto.tieneCoordenadas),
      _filtro,
    );
    // Los prioritarios se dibujan al final para que queden encima.
    lista.sort((a, b) => b.categoria.index.compareTo(a.categoria.index));
    return lista;
  }

  CameraFit? _encuadre(List<PuntoCritico> puntos) => puntos.isEmpty
      ? null
      : CameraFit.coordinates(
          coordinates: [for (final punto in puntos) _punto(punto)],
          padding: _margenCamara,
          maxZoom: 16,
        );

  void _cambiarFiltro(FiltroPuntosCriticos filtro) {
    setState(() => _filtro = filtro);
    final encuadre = _encuadre(_visibles);
    if (encuadre != null) _controladorMapa.fitCamera(encuadre);
  }

  @override
  Widget build(BuildContext context) {
    final colores = Theme.of(context).extension<ColoresEstado>()!;
    final visibles = _visibles;
    final sinPuntos = widget.puntos.isEmpty;

    return Stack(
      children: [
        FlutterMap(
          mapController: _controladorMapa,
          options: MapOptions(
            initialCenter: PantallaMapa.centro,
            initialZoom: 13,
            initialCameraFit: _encuadre(visibles),
            interactionOptions: const InteractionOptions(
              flags: InteractiveFlag.all,
            ),
          ),
          children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: PantallaMapa.idPaquete,
              errorTileCallback: (_, error, _) {
                debugPrint('No se pudo cargar una tesela del mapa: $error');
                if (mounted && !_errorTeselas) {
                  setState(() => _errorTeselas = true);
                }
              },
            ),
            MarkerLayer(
              markers: [
                for (final punto in visibles)
                  Marker(
                    point: _punto(punto),
                    width: 44,
                    height: 44,
                    child: MarcadorPuntoCritico(
                      punto: punto,
                      onTap: () => _mostrarDetalle(context, punto),
                    ),
                  ),
              ],
            ),
          ],
        ),
        if (!sinPuntos)
          SafeArea(
            child: Align(
              alignment: Alignment.topCenter,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  12,
                  12 + PantallaMapa.margenSelector,
                  12,
                  12,
                ),
                child: _FiltrosPuntos(
                  filtro: _filtro,
                  colores: colores,
                  onCambiar: _cambiarFiltro,
                ),
              ),
            ),
          ),
        if (sinPuntos || visibles.isEmpty)
          Center(
            child: _AvisoVacio(
              texto: sinPuntos
                  ? 'No hay puntos críticos registrados'
                  : 'No hay puntos críticos en este filtro',
            ),
          ),
        if (_errorTeselas)
          SafeArea(
            child: Align(
              alignment: Alignment.topCenter,
              child: Padding(
                padding: const EdgeInsets.only(top: 136, left: 16, right: 16),
                child: Material(
                  color: EcoColors.primario,
                  borderRadius: BorderRadius.circular(12),
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: Text(
                      'El mapa base no está disponible. Los puntos siguen visibles.',
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
              child: _LeyendaPuntos(
                cantidad: visibles.length,
                colores: colores,
              ),
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

  LatLng _punto(PuntoCritico punto) => LatLng(punto.latitud!, punto.longitud!);

  void _mostrarDetalle(BuildContext context, PuntoCritico punto) {
    final mensajero = ScaffoldMessenger.maybeOf(context);
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      backgroundColor: EcoColors.superficie,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => DetallePuntoCritico(
        punto: punto,
        onComoLlegar: () async {
          final abierto = await abrirComoLlegar(
            latitud: punto.latitud!,
            longitud: punto.longitud!,
            nombre: punto.direccion.isEmpty ? punto.codigo : punto.direccion,
          );
          if (abierto) return;
          mensajero
            ?..hideCurrentSnackBar()
            ..showSnackBar(
              const SnackBar(content: Text('No se pudo abrir la navegación.')),
            );
        },
      ),
    );
  }
}

EstadoVisual visualPuntoCritico(
  ColoresEstado colores,
  CategoriaPuntoCritico categoria,
) => switch (categoria) {
  CategoriaPuntoCritico.prioritario => colores.critico,
  CategoriaPuntoCritico.potencial => colores.alerta,
  CategoriaPuntoCritico.recuperado => colores.normal,
};

String nombreCategoriaPunto(CategoriaPuntoCritico categoria) =>
    switch (categoria) {
      CategoriaPuntoCritico.prioritario => 'Prioritario',
      CategoriaPuntoCritico.potencial => 'Potencial',
      CategoriaPuntoCritico.recuperado => 'Recuperado',
    };

String _nombreEstado(EstadoPuntoCritico estado) => switch (estado) {
  EstadoPuntoCritico.potencial => 'Potencial',
  EstadoPuntoCritico.recuperado => 'Recuperado',
  EstadoPuntoCritico.desconocido => 'Sin estado',
};

String _nombreFiltro(FiltroPuntosCriticos filtro) => switch (filtro) {
  FiltroPuntosCriticos.todos => 'Todos',
  FiltroPuntosCriticos.prioritarios => 'Prioritarios',
  FiltroPuntosCriticos.potenciales => 'Potenciales',
  FiltroPuntosCriticos.recuperados => 'Recuperados',
};

class MarcadorPuntoCritico extends StatelessWidget {
  const MarcadorPuntoCritico({
    required this.punto,
    required this.onTap,
    super.key,
  });

  final PuntoCritico punto;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final visual = visualPuntoCritico(
      Theme.of(context).extension<ColoresEstado>()!,
      punto.categoria,
    );

    return Semantics(
      button: true,
      label:
          'Punto crítico ${punto.codigo}, '
          '${nombreCategoriaPunto(punto.categoria)}',
      child: Tooltip(
        message: '${punto.codigo} · ${punto.direccion}',
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            customBorder: const CircleBorder(),
            child: Center(
              child: Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: visual.color,
                  shape: BoxShape.circle,
                  border: Border.all(color: EcoColors.superficie, width: 2.5),
                  boxShadow: [
                    BoxShadow(
                      color: EcoColors.primario.withValues(alpha: 0.24),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Icon(visual.icono, color: Colors.white, size: 15),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _FiltrosPuntos extends StatelessWidget {
  const _FiltrosPuntos({
    required this.filtro,
    required this.colores,
    required this.onCambiar,
  });

  final FiltroPuntosCriticos filtro;
  final ColoresEstado colores;
  final ValueChanged<FiltroPuntosCriticos> onCambiar;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final opcion in FiltroPuntosCriticos.values) ...[
              if (opcion != FiltroPuntosCriticos.todos)
                const SizedBox(width: 8),
              _chip(context, opcion),
            ],
          ],
        ),
      ),
    ),
  );

  Widget _chip(BuildContext context, FiltroPuntosCriticos opcion) {
    final seleccionado = opcion == filtro;
    final color = switch (opcion) {
      FiltroPuntosCriticos.todos => EcoColors.primario,
      FiltroPuntosCriticos.prioritarios => colores.critico.color,
      FiltroPuntosCriticos.potenciales => colores.alerta.color,
      FiltroPuntosCriticos.recuperados => colores.normal.color,
    };
    return ChoiceChip(
      label: Text(_nombreFiltro(opcion)),
      selected: seleccionado,
      showCheckmark: false,
      onSelected: (_) => onCambiar(opcion),
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
}

class _LeyendaPuntos extends StatelessWidget {
  const _LeyendaPuntos({required this.cantidad, required this.colores});

  final int cantidad;
  final ColoresEstado colores;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            cantidad == 1 ? '1 punto crítico' : '$cantidad puntos críticos',
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: EcoColors.primario,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (AppConfig.usarDatosDeEjemplo) ...[
            const SizedBox(height: 8),
            const AvisoDatosEjemplo(),
          ],
          const SizedBox(height: 8),
          Wrap(
            spacing: 16,
            runSpacing: 8,
            children: [
              for (final categoria in CategoriaPuntoCritico.values)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      visualPuntoCritico(colores, categoria).icono,
                      size: 16,
                      color: visualPuntoCritico(colores, categoria).color,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      nombreCategoriaPunto(categoria),
                      style: Theme.of(context).textTheme.labelSmall
                          ?.copyWith(color: EcoColors.texto),
                    ),
                  ],
                ),
            ],
          ),
        ],
      ),
    ),
  );
}

class _AvisoVacio extends StatelessWidget {
  const _AvisoVacio({required this.texto});

  final String texto;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.location_off_outlined,
            size: 32,
            color: EcoColors.textoSecundario,
          ),
          const SizedBox(height: 12),
          Text(
            texto,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium
                ?.copyWith(color: EcoColors.textoSecundario),
          ),
        ],
      ),
    ),
  );
}

/// Hoja inferior con los datos de un punto crítico.
class DetallePuntoCritico extends StatelessWidget {
  const DetallePuntoCritico({
    required this.punto,
    required this.onComoLlegar,
    super.key,
  });

  final PuntoCritico punto;
  final VoidCallback onComoLlegar;

  @override
  Widget build(BuildContext context) {
    final ancho = MediaQuery.sizeOf(context).width;
    final colores = Theme.of(context).extension<ColoresEstado>()!;
    final visual = visualPuntoCritico(colores, punto.categoria);
    final estadoVisual = punto.estado == EstadoPuntoCritico.recuperado
        ? colores.normal
        : colores.alerta;
    final textos = Theme.of(context).textTheme;

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
                        'Punto crítico ${punto.codigo}',
                        style: textos.titleLarge?.copyWith(
                          color: EcoColors.primario,
                        ),
                      ),
                    ),
                    Icon(visual.icono, color: visual.color),
                  ],
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _Etiqueta(
                      texto: _nombreEstado(punto.estado),
                      visual: estadoVisual,
                    ),
                    if (punto.priorizacionObligatoria)
                      _Etiqueta(
                        texto: 'Priorización obligatoria',
                        visual: colores.critico,
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                _Dato(
                  titulo: 'Dirección',
                  valor: punto.direccion.isEmpty
                      ? 'Sin dirección'
                      : punto.direccion,
                ),
                const SizedBox(height: 12),
                _Dato(
                  titulo: 'Referencia',
                  valor: punto.referencia ?? 'Sin referencia',
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: Semantics(
                    button: true,
                    label: 'Cómo llegar al punto crítico ${punto.codigo}',
                    excludeSemantics: true,
                    child: FilledButton.icon(
                      onPressed: punto.tieneCoordenadas ? onComoLlegar : null,
                      icon: const Icon(Icons.directions_rounded),
                      label: const Text('Cómo llegar'),
                    ),
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

class _Etiqueta extends StatelessWidget {
  const _Etiqueta({required this.texto, required this.visual});

  final String texto;
  final EstadoVisual visual;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
    decoration: BoxDecoration(
      color: visual.fondo,
      borderRadius: BorderRadius.circular(16),
    ),
    child: Text(
      texto,
      style: Theme.of(context).textTheme.labelMedium
          ?.copyWith(color: visual.color, fontWeight: FontWeight.w700),
    ),
  );
}

class _Dato extends StatelessWidget {
  const _Dato({required this.titulo, required this.valor});

  final String titulo;
  final String valor;

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
      Text(
        valor,
        style: Theme.of(context).textTheme.bodyLarge
            ?.copyWith(color: EcoColors.texto),
      ),
    ],
  );
}
