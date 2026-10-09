import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/theme/app_theme.dart';
import '../data/modelos_panel.dart';
import 'controladores_dominio.dart';
import 'widgets/chip_estado.dart';
import 'widgets/estados_panel.dart';

const _zonasTrujillo = [
  'Centro',
  'Víctor Larco',
  'La Esperanza',
  'El Porvenir',
];
const _capacidadMinima = 100;
const _capacidadMaxima = 5000;
const _maximoAnchoFormulario = 600.0;

class PantallaContenedores extends ConsumerStatefulWidget {
  const PantallaContenedores({super.key});

  @override
  ConsumerState<PantallaContenedores> createState() =>
      _PantallaContenedoresState();
}

class _PantallaContenedoresState extends ConsumerState<PantallaContenedores> {
  final _busqueda = TextEditingController();
  String? _zona;
  EstadoOperativo? _operativo;

  @override
  void dispose() {
    _busqueda.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final estado = ref.watch(contenedoresControllerProvider);
    final ancho = MediaQuery.sizeOf(context).width;
    final margen = ancho < EcoLayout.anchoCompacto ? 16.0 : 24.0;
    return estado.when(
      loading: () =>
          _lista(margen, const [SliverToBoxAdapter(child: EsqueletoPanel())]),
      error: (error, stackTrace) => _lista(margen, [
        SliverToBoxAdapter(
          child: ErrorPanel(
            onRetry: () => ref.invalidate(contenedoresControllerProvider),
          ),
        ),
      ]),
      data: (nodos) {
        final visibles = nodos.where((nodo) {
          final texto = _busqueda.text.trim().toLowerCase();
          return (texto.isEmpty ||
                  nodo.nombre.toLowerCase().contains(texto) ||
                  nodo.codigo.toLowerCase().contains(texto)) &&
              (_zona == null || nodo.zona == _zona) &&
              (_operativo == null || nodo.estadoOperativo == _operativo);
        }).toList()..sort((a, b) => a.codigo.compareTo(b.codigo));
        return _lista(margen, [
          SliverToBoxAdapter(
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Contenedores',
                    style: Theme.of(context).textTheme.headlineMedium
                        ?.copyWith(color: EcoColors.primario),
                  ),
                ),
                FilledButton.icon(
                  onPressed: () => _abrirFormulario(),
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('Agregar'),
                ),
              ],
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: TextField(
                controller: _busqueda,
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.search_rounded),
                  hintText: 'Buscar por nombre o código',
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                DropdownButton<String?>(
                  value: _zona,
                  hint: const Text('Todas las zonas'),
                  items: [
                    const DropdownMenuItem<String?>(
                      value: null,
                      child: Text('Todas las zonas'),
                    ),
                    for (final zona in _zonasTrujillo)
                      DropdownMenuItem(value: zona, child: Text(zona)),
                  ],
                  onChanged: (value) => setState(() => _zona = value),
                ),
                DropdownButton<EstadoOperativo?>(
                  value: _operativo,
                  hint: const Text('Estado operativo'),
                  items: [
                    const DropdownMenuItem<EstadoOperativo?>(
                      value: null,
                      child: Text('Todos los estados'),
                    ),
                    for (final estado in EstadoOperativo.values)
                      DropdownMenuItem(
                        value: estado,
                        child: Text(_nombreOperativo(estado)),
                      ),
                  ],
                  onChanged: (value) => setState(() => _operativo = value),
                ),
              ],
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 16)),
          if (visibles.isEmpty)
            SliverToBoxAdapter(
              child: _VacioContenedores(
                mensaje: nodos.isEmpty
                    ? 'Aún no hay contenedores registrados.'
                    : 'No encontramos contenedores con estos filtros.',
              ),
            )
          else
            SliverList.builder(
              itemCount: visibles.length,
              itemBuilder: (context, index) => _FilaContenedor(
                nodo: visibles[index],
                onEditar: () => _abrirFormulario(nodo: visibles[index]),
                onEstado: (estado) => _confirmarEstado(visibles[index], estado),
                onEliminar: () => _confirmarEliminar(visibles[index]),
              ),
            ),
        ]);
      },
    );
  }

  Widget _lista(double margen, List<Widget> slivers) => Center(
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: EcoLayout.anchoContenido),
      child: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(contenedoresControllerProvider);
          await ref.read(contenedoresControllerProvider.future);
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

  Future<void> _abrirFormulario({NodoEstado? nodo}) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(builder: (_) => FormularioContenedor(nodo: nodo)),
    );
  }

  Future<void> _confirmarEstado(NodoEstado nodo, EstadoOperativo estado) async {
    final confirmado = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('${_nombreOperativo(estado)} · ${nodo.codigo}'),
        content: Text(
          '¿Confirmas cambiar el estado operativo de ${nodo.nombre}?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Confirmar'),
          ),
        ],
      ),
    );
    if (confirmado != true || !mounted) return;
    await _guardar(nodo.copiar(estadoOperativo: estado));
  }

  Future<void> _confirmarEliminar(NodoEstado nodo) async {
    final confirmado = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar contenedor'),
        content: Text(
          'Se quitará ${nodo.codigo} del panel y del mapa. Esta acción no se puede deshacer.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (confirmado != true || !mounted) return;
    await _accion(
      () => ref.read(contenedoresControllerProvider.notifier).eliminar(nodo.id),
    );
  }

  Future<void> _guardar(NodoEstado nodo) => _accion(
    () => ref.read(contenedoresControllerProvider.notifier).guardar(nodo),
  );

  Future<void> _accion(Future<void> Function() accion) async {
    try {
      await accion();
    } on StateError catch (error) {
      if (mounted) _mensaje(context, error.message.toString());
    }
  }
}

class _FilaContenedor extends StatelessWidget {
  const _FilaContenedor({
    required this.nodo,
    required this.onEditar,
    required this.onEstado,
    required this.onEliminar,
  });

  final NodoEstado nodo;
  final VoidCallback onEditar;
  final ValueChanged<EstadoOperativo> onEstado;
  final VoidCallback onEliminar;

  @override
  Widget build(BuildContext context) {
    final proceso = Theme.of(context).extension<ColoresProceso>()!;
    final estadoProceso = switch (nodo.estadoOperativo) {
      EstadoOperativo.activo => EstadoProcesoPanel.activo,
      EstadoOperativo.mantenimiento => EstadoProcesoPanel.mantenimiento,
      EstadoOperativo.inactivo => EstadoProcesoPanel.inactivo,
    };
    final visual = proceso.para(estadoProceso);
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onEditar,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 8, 16),
            child: Column(
              children: [
                Row(
                  children: [
                    Icon(visual.icono, color: visual.color),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            nodo.nombre,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          Text(
                            '${nodo.codigo} · ${nodo.zona}',
                            style: Theme.of(context).textTheme.labelMedium
                                ?.copyWith(color: EcoColors.textoSecundario),
                          ),
                        ],
                      ),
                    ),
                    PopupMenuButton<String>(
                      tooltip: 'Acciones del contenedor',
                      onSelected: (accion) {
                        switch (accion) {
                          case 'editar':
                            onEditar();
                            break;
                          case 'activo':
                            onEstado(EstadoOperativo.activo);
                            break;
                          case 'mantenimiento':
                            onEstado(EstadoOperativo.mantenimiento);
                            break;
                          case 'inactivo':
                            onEstado(EstadoOperativo.inactivo);
                            break;
                          case 'eliminar':
                            onEliminar();
                            break;
                        }
                      },
                      itemBuilder: (context) => const [
                        PopupMenuItem(value: 'editar', child: Text('Editar')),
                        PopupMenuItem(value: 'activo', child: Text('Activar')),
                        PopupMenuItem(
                          value: 'mantenimiento',
                          child: Text('Poner en mantenimiento'),
                        ),
                        PopupMenuItem(
                          value: 'inactivo',
                          child: Text('Desactivar'),
                        ),
                        PopupMenuItem(
                          value: 'eliminar',
                          child: Text('Eliminar'),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    ChipEstado(estado: nodo.estado),
                    const SizedBox(width: 8),
                    _ChipOperativo(estado: nodo.estadoOperativo),
                    const Spacer(),
                    Text(
                      '${nodo.capacidadLitros} L',
                      style: Theme.of(context).textTheme.labelMedium,
                    ),
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

class _ChipOperativo extends StatelessWidget {
  const _ChipOperativo({required this.estado});

  final EstadoOperativo estado;

  @override
  Widget build(BuildContext context) {
    final proceso = switch (estado) {
      EstadoOperativo.activo => EstadoProcesoPanel.activo,
      EstadoOperativo.mantenimiento => EstadoProcesoPanel.mantenimiento,
      EstadoOperativo.inactivo => EstadoProcesoPanel.inactivo,
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
          Text(_nombreOperativo(estado), style: TextStyle(color: visual.color)),
        ],
      ),
    );
  }
}

class _VacioContenedores extends StatelessWidget {
  const _VacioContenedores({required this.mensaje});

  final String mensaje;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Center(child: Text(mensaje, textAlign: TextAlign.center)),
    ),
  );
}

class FormularioContenedor extends ConsumerStatefulWidget {
  const FormularioContenedor({this.nodo, super.key});

  final NodoEstado? nodo;

  @override
  ConsumerState<FormularioContenedor> createState() =>
      _FormularioContenedorState();
}

class _FormularioContenedorState extends ConsumerState<FormularioContenedor> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _nombre;
  late final TextEditingController _codigo;
  late final TextEditingController _capacidad;
  late final TextEditingController _residuo;
  late String _zona;
  late EstadoOperativo _operativo;
  LatLng? _ubicacion;
  bool _guardando = false;

  bool get _esEdicion => widget.nodo != null;

  @override
  void initState() {
    super.initState();
    final nodo = widget.nodo;
    _nombre = TextEditingController(text: nodo?.nombre);
    _codigo = TextEditingController(
      text:
          nodo?.codigo ??
          _siguienteCodigo(
            ref.read(contenedoresControllerProvider).asData?.value ?? const [],
          ),
    );
    _capacidad = TextEditingController(
      text: '${nodo?.capacidadLitros ?? 1200}',
    );
    _residuo = TextEditingController(
      text: nodo?.tipoResiduo ?? 'Residuos generales',
    );
    _zona = nodo?.zona ?? _zonasTrujillo.first;
    _operativo = nodo?.estadoOperativo ?? EstadoOperativo.activo;
    _ubicacion = nodo?.latitud == null || nodo?.longitud == null
        ? const LatLng(-8.1116, -79.0288)
        : LatLng(nodo!.latitud!, nodo.longitud!);
  }

  @override
  void dispose() {
    _nombre.dispose();
    _codigo.dispose();
    _capacidad.dispose();
    _residuo.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(_esEdicion ? 'Editar contenedor' : 'Nuevo contenedor'),
    ),
    body: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: _maximoAnchoFormulario),
        child: Form(
          key: _form,
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              TextFormField(
                controller: _nombre,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(labelText: 'Nombre'),
                validator: (valor) => _requerido(valor, 'Ingresa el nombre.'),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _codigo,
                readOnly: !_esEdicion,
                textCapitalization: TextCapitalization.characters,
                decoration: const InputDecoration(labelText: 'Código'),
                validator: (valor) {
                  final codigos =
                      ref
                          .read(contenedoresControllerProvider)
                          .asData
                          ?.value
                          .where((nodo) => nodo.id != widget.nodo?.id)
                          .map((nodo) => nodo.codigo.toUpperCase())
                          .toSet() ??
                      const <String>{};
                  return _codigoValido(valor, codigos);
                },
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: _zona,
                decoration: const InputDecoration(labelText: 'Zona'),
                items: [
                  for (final zona in _zonasTrujillo)
                    DropdownMenuItem(value: zona, child: Text(zona)),
                ],
                onChanged: (valor) => setState(() => _zona = valor ?? _zona),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _capacidad,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Capacidad (litros)',
                ),
                validator: _capacidadValida,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _residuo,
                decoration: const InputDecoration(labelText: 'Tipo de residuo'),
                validator: (valor) =>
                    _requerido(valor, 'Indica el tipo de residuo.'),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<EstadoOperativo>(
                initialValue: _operativo,
                decoration: const InputDecoration(
                  labelText: 'Estado operativo',
                ),
                items: [
                  for (final estado in EstadoOperativo.values)
                    DropdownMenuItem(
                      value: estado,
                      child: Text(_nombreOperativo(estado)),
                    ),
                ],
                onChanged: (valor) =>
                    setState(() => _operativo = valor ?? _operativo),
              ),
              const SizedBox(height: 24),
              Text(
                'Ubicación en el mapa',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Text(
                _ubicacion == null
                    ? 'Toca el mapa para elegir una ubicación.'
                    : '${_ubicacion!.latitude.toStringAsFixed(4)}, '
                          '${_ubicacion!.longitude.toStringAsFixed(4)}',
                style: Theme.of(context).textTheme.bodySmall
                    ?.copyWith(color: EcoColors.textoSecundario),
              ),
              const SizedBox(height: 8),
              _SelectorUbicacion(
                inicial: _ubicacion,
                onSeleccion: (punto) => setState(() => _ubicacion = punto),
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: _guardando ? null : _guardar,
                icon: _guardando
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.save_outlined),
                label: Text(
                  _esEdicion ? 'Guardar cambios' : 'Crear contenedor',
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );

  Future<void> _guardar() async {
    if (!_form.currentState!.validate()) return;
    if (_ubicacion == null) {
      _mensaje(context, 'Selecciona una ubicación en el mapa.');
      return;
    }
    setState(() => _guardando = true);
    try {
      final anterior = widget.nodo;
      final nodos =
          ref.read(contenedoresControllerProvider).asData?.value ?? [];
      final id =
          anterior?.id ??
          (nodos.fold<int>(
                0,
                (mayor, nodo) => nodo.id > mayor ? nodo.id : mayor,
              ) +
              1);
      final nodo = NodoEstado(
        id: id,
        codigo: _codigo.text.trim().toUpperCase(),
        nombre: _nombre.text.trim(),
        latitud: _ubicacion!.latitude,
        longitud: _ubicacion!.longitude,
        umbralCritico: anterior?.umbralCritico ?? 80,
        llenado: anterior?.llenado,
        volteado: anterior?.volteado ?? false,
        ultimaLectura: anterior?.ultimaLectura,
        estado: anterior?.estado ?? EstadoNodo.sinDatos,
        zona: _zona,
        capacidadLitros: int.parse(_capacidad.text.trim()),
        bateria: anterior?.bateria,
        senal: anterior?.senal,
        estadoOperativo: _operativo,
        firmware: anterior?.firmware ?? '1.0.0',
        tipoResiduo: _residuo.text.trim(),
        fechaInstalacion: anterior?.fechaInstalacion ?? DateTime(2026, 10, 8),
      );
      await ref.read(contenedoresControllerProvider.notifier).guardar(nodo);
      if (mounted) Navigator.of(context).pop();
    } on StateError catch (error) {
      if (mounted) _mensaje(context, error.message.toString());
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }
}

class _SelectorUbicacion extends StatefulWidget {
  const _SelectorUbicacion({required this.inicial, required this.onSeleccion});

  final LatLng? inicial;
  final ValueChanged<LatLng> onSeleccion;

  @override
  State<_SelectorUbicacion> createState() => _SelectorUbicacionState();
}

class _SelectorUbicacionState extends State<_SelectorUbicacion> {
  late LatLng _punto = widget.inicial ?? const LatLng(-8.1116, -79.0288);

  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(16),
    child: SizedBox(
      height: 240,
      child: FlutterMap(
        options: MapOptions(
          initialCenter: _punto,
          initialZoom: 14,
          onTap: (_, punto) {
            setState(() => _punto = punto);
            widget.onSeleccion(punto);
          },
        ),
        children: [
          TileLayer(
            urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
            userAgentPackageName: 'com.ecoruta.app.ecoruta_frontend_app',
          ),
          MarkerLayer(
            markers: [
              Marker(
                point: _punto,
                width: 48,
                height: 48,
                child: Icon(
                  Icons.location_on_rounded,
                  color: Theme.of(context)
                      .extension<ColoresEstado>()!
                      .critico
                      .color,
                  size: 40,
                ),
              ),
            ],
          ),
        ],
      ),
    ),
  );
}

String? _requerido(String? valor, String mensaje) =>
    valor == null || valor.trim().isEmpty ? mensaje : null;

String? _capacidadValida(String? valor) {
  final numero = int.tryParse(valor?.trim() ?? '');
  if (numero == null) return 'Ingresa una capacidad válida.';
  if (numero < _capacidadMinima || numero > _capacidadMaxima) {
    return 'Usa un valor entre $_capacidadMinima y $_capacidadMaxima litros.';
  }
  return null;
}

String? _codigoValido(String? valor, Set<String> codigos) {
  final codigo = valor?.trim().toUpperCase() ?? '';
  if (!RegExp(r'^TRU-\d{3}$').hasMatch(codigo)) {
    return 'Usa el formato TRU-001.';
  }
  if (codigos.contains(codigo)) return 'Este código ya está registrado.';
  return null;
}

String _siguienteCodigo(List<NodoEstado> nodos) {
  final mayor = nodos.fold<int>(0, (actual, nodo) {
    final numero = int.tryParse(nodo.codigo.split('-').last) ?? 0;
    return numero > actual ? numero : actual;
  });
  return 'TRU-${(mayor + 1).toString().padLeft(3, '0')}';
}

String _nombreOperativo(EstadoOperativo estado) => switch (estado) {
  EstadoOperativo.activo => 'Activo',
  EstadoOperativo.mantenimiento => 'Mantenimiento',
  EstadoOperativo.inactivo => 'Inactivo',
};

void _mensaje(BuildContext context, String texto) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(texto)));
}
