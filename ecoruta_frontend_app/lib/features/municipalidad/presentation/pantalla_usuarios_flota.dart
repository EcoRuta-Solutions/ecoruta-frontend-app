import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../data/modelos_flota.dart';
import 'controladores_dominio.dart';
import 'widgets/estados_panel.dart';

const _anchoUsuariosFlota = 920.0;

enum TipoRegistroFlota { usuario, conductor, vehiculo }

class PantallaUsuariosFlota extends ConsumerStatefulWidget {
  const PantallaUsuariosFlota({super.key});

  @override
  ConsumerState<PantallaUsuariosFlota> createState() =>
      _PantallaUsuariosFlotaState();
}

class _PantallaUsuariosFlotaState extends ConsumerState<PantallaUsuariosFlota>
    with SingleTickerProviderStateMixin {
  late final TabController _pestanas = TabController(length: 3, vsync: this);
  final _busqueda = TextEditingController();

  @override
  void dispose() {
    _pestanas.dispose();
    _busqueda.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final flota = ref.watch(flotaControllerProvider);
    final ancho = MediaQuery.sizeOf(context).width;
    return Column(
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(
            ancho < EcoLayout.anchoCompacto ? 16 : 24,
            16,
            ancho < EcoLayout.anchoCompacto ? 16 : 24,
            8,
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: _anchoUsuariosFlota),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Usuarios y flota',
                  style: Theme.of(context).textTheme.headlineMedium
                      ?.copyWith(color: EcoColors.primario),
                ),
                const SizedBox(height: 16),
                TabBar(
                  controller: _pestanas,
                  tabs: const [
                    Tab(text: 'Usuarios'),
                    Tab(text: 'Conductores'),
                    Tab(text: 'Vehículos'),
                  ],
                ),
              ],
            ),
          ),
        ),
        Expanded(
          child: flota.when(
            loading: () => const _CargaFlota(),
            error: (error, stackTrace) => ErrorPanel(
              onRetry: () => ref.invalidate(flotaControllerProvider),
            ),
            data: (datos) => TabBarView(
              controller: _pestanas,
              children: [
                _lista(
                  context,
                  TipoRegistroFlota.usuario,
                  datos.usuarios.where(_coincideUsuario).toList(),
                  datos,
                ),
                _lista(
                  context,
                  TipoRegistroFlota.conductor,
                  datos.conductores.where(_coincideConductor).toList(),
                  datos,
                ),
                _lista(
                  context,
                  TipoRegistroFlota.vehiculo,
                  datos.vehiculos.where(_coincideVehiculo).toList(),
                  datos,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _lista(
    BuildContext context,
    TipoRegistroFlota tipo,
    List<Object> registros,
    DatosFlota datos,
  ) {
    final ancho = MediaQuery.sizeOf(context).width;
    final margen = ancho < EcoLayout.anchoCompacto ? 16.0 : 24.0;
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: _anchoUsuariosFlota),
        child: RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(flotaControllerProvider);
            await ref.read(flotaControllerProvider.future);
          },
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverPadding(
                padding: EdgeInsets.fromLTRB(margen, 16, margen, 32),
                sliver: SliverMainAxisGroup(
                  slivers: [
                    SliverToBoxAdapter(
                      child: Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _busqueda,
                              onChanged: (_) => setState(() {}),
                              decoration: const InputDecoration(
                                prefixIcon: Icon(Icons.search_rounded),
                                hintText: 'Buscar',
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          IconButton.filled(
                            tooltip: 'Agregar ${_nombreTipoFlota(tipo)}',
                            onPressed: () => _abrirFormulario(tipo, datos),
                            icon: const Icon(Icons.add_rounded),
                          ),
                        ],
                      ),
                    ),
                    const SliverToBoxAdapter(child: SizedBox(height: 16)),
                    if (registros.isEmpty)
                      SliverToBoxAdapter(
                        child: _VacioFlota(
                          mensaje: _busqueda.text.isEmpty
                              ? 'Aún no hay ${_pluralTipoFlota(tipo)}.'
                              : 'No encontramos coincidencias.',
                        ),
                      )
                    else
                      SliverList.builder(
                        itemCount: registros.length,
                        itemBuilder: (context, index) => _FilaFlota(
                          tipo: tipo,
                          registro: registros[index],
                          onEditar: () =>
                              _abrirFormulario(tipo, datos, registros[index]),
                          onAlternar: () =>
                              _alternarActivo(tipo, registros[index]),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  bool _coincideUsuario(UsuarioPanel usuario) {
    final consulta = _busqueda.text.trim().toLowerCase();
    return consulta.isEmpty ||
        usuario.nombre.toLowerCase().contains(consulta) ||
        usuario.correo.toLowerCase().contains(consulta);
  }

  bool _coincideConductor(Conductor conductor) {
    final consulta = _busqueda.text.trim().toLowerCase();
    return consulta.isEmpty ||
        conductor.nombre.toLowerCase().contains(consulta) ||
        conductor.telefono.contains(consulta);
  }

  bool _coincideVehiculo(Vehiculo vehiculo) {
    final consulta = _busqueda.text.trim().toLowerCase();
    return consulta.isEmpty ||
        vehiculo.placa.toLowerCase().contains(consulta) ||
        vehiculo.tipo.toLowerCase().contains(consulta);
  }

  Future<void> _abrirFormulario(
    TipoRegistroFlota tipo,
    DatosFlota datos, [
    Object? registro,
  ]) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) =>
            FormularioFlota(tipo: tipo, existente: registro, datos: datos),
      ),
    );
  }

  Future<void> _alternarActivo(TipoRegistroFlota tipo, Object registro) async {
    final activo = switch (tipo) {
      TipoRegistroFlota.usuario => (registro as UsuarioPanel).activo,
      TipoRegistroFlota.conductor => (registro as Conductor).activo,
      TipoRegistroFlota.vehiculo => (registro as Vehiculo).activo,
    };
    final confirmado = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(activo ? 'Desactivar registro' : 'Activar registro'),
        content: Text(
          activo
              ? '¿Confirmas desactivar ${_identidadRegistro(tipo, registro)}?'
              : '¿Confirmas volver a activar ${_identidadRegistro(tipo, registro)}?',
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
    try {
      switch (tipo) {
        case TipoRegistroFlota.usuario:
          final usuario = registro as UsuarioPanel;
          await ref
              .read(flotaControllerProvider.notifier)
              .guardarUsuario(usuario.copiar(activo: !activo));
          break;
        case TipoRegistroFlota.conductor:
          final conductor = registro as Conductor;
          await ref
              .read(flotaControllerProvider.notifier)
              .guardarConductor(conductor.copiar(activo: !activo));
          break;
        case TipoRegistroFlota.vehiculo:
          final vehiculo = registro as Vehiculo;
          await ref
              .read(flotaControllerProvider.notifier)
              .guardarVehiculo(vehiculo.copiar(activo: !activo));
          break;
      }
    } on StateError catch (error) {
      if (mounted) _mensaje(context, error.message.toString());
    }
  }
}

class FormularioFlota extends ConsumerStatefulWidget {
  const FormularioFlota({
    required this.tipo,
    required this.datos,
    this.existente,
    super.key,
  });

  final TipoRegistroFlota tipo;
  final DatosFlota datos;
  final Object? existente;

  @override
  ConsumerState<FormularioFlota> createState() => _FormularioFlotaState();
}

class _FormularioFlotaState extends ConsumerState<FormularioFlota> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _nombre;
  late final TextEditingController _correo;
  late final TextEditingController _telefono;
  late final TextEditingController _licencia;
  late final TextEditingController _placa;
  late final TextEditingController _tipoVehiculo;
  late final TextEditingController _capacidad;
  late RolPanel _rol;
  late EstadoConductor _estadoConductor;
  late EstadoVehiculo _estadoVehiculo;
  int? _vehiculoAsignado;
  bool _activo = true;
  bool _guardando = false;

  @override
  void initState() {
    super.initState();
    final existente = widget.existente;
    final usuario = existente is UsuarioPanel ? existente : null;
    final conductor = existente is Conductor ? existente : null;
    final vehiculo = existente is Vehiculo ? existente : null;
    _nombre = TextEditingController(text: usuario?.nombre ?? conductor?.nombre);
    _correo = TextEditingController(text: usuario?.correo);
    _telefono = TextEditingController(text: conductor?.telefono);
    _licencia = TextEditingController(text: conductor?.categoriaLicencia);
    _placa = TextEditingController(text: vehiculo?.placa);
    _tipoVehiculo = TextEditingController(text: vehiculo?.tipo);
    _capacidad = TextEditingController(
      text: vehiculo == null ? '' : '${vehiculo.capacidadToneladas}',
    );
    _rol = usuario?.rol ?? RolPanel.operador;
    _estadoConductor = conductor?.estado ?? EstadoConductor.disponible;
    _estadoVehiculo = vehiculo?.estado ?? EstadoVehiculo.operativo;
    _vehiculoAsignado = conductor?.vehiculoAsignado;
    _activo = usuario?.activo ?? conductor?.activo ?? vehiculo?.activo ?? true;
  }

  @override
  void dispose() {
    _nombre.dispose();
    _correo.dispose();
    _telefono.dispose();
    _licencia.dispose();
    _placa.dispose();
    _tipoVehiculo.dispose();
    _capacidad.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final edicion = widget.existente != null;
    return Scaffold(
      appBar: AppBar(
        title: Text(
          '${edicion ? 'Editar' : 'Nuevo'} ${_nombreTipoFlota(widget.tipo)}',
        ),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: Form(
            key: _form,
            child: ListView(
              padding: const EdgeInsets.all(24),
              children: [
                if (widget.tipo != TipoRegistroFlota.vehiculo)
                  TextFormField(
                    controller: _nombre,
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(labelText: 'Nombre'),
                    validator: (valor) =>
                        _requerido(valor, 'Ingresa el nombre.'),
                  ),
                if (widget.tipo == TipoRegistroFlota.usuario) ...[
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _correo,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(labelText: 'Correo'),
                    validator: _validarCorreo,
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<RolPanel>(
                    initialValue: _rol,
                    decoration: const InputDecoration(labelText: 'Rol'),
                    items: [
                      for (final rol in RolPanel.values)
                        DropdownMenuItem(
                          value: rol,
                          child: Text(_nombreRol(rol)),
                        ),
                    ],
                    onChanged: (rol) => setState(() => _rol = rol ?? _rol),
                  ),
                ],
                if (widget.tipo == TipoRegistroFlota.conductor) ...[
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _telefono,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(labelText: 'Teléfono'),
                    validator: _validarTelefono,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _licencia,
                    textCapitalization: TextCapitalization.characters,
                    decoration: const InputDecoration(
                      labelText: 'Categoría de licencia',
                    ),
                    validator: (valor) =>
                        _requerido(valor, 'Indica la categoría de licencia.'),
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<EstadoConductor>(
                    initialValue: _estadoConductor,
                    decoration: const InputDecoration(labelText: 'Estado'),
                    items: [
                      for (final estado in EstadoConductor.values)
                        DropdownMenuItem(
                          value: estado,
                          child: Text(_nombreEstadoConductor(estado)),
                        ),
                    ],
                    onChanged: (estado) => setState(
                      () => _estadoConductor = estado ?? _estadoConductor,
                    ),
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<int?>(
                    initialValue: _vehiculoAsignado,
                    decoration: const InputDecoration(
                      labelText: 'Vehículo asignado',
                    ),
                    items: [
                      const DropdownMenuItem<int?>(
                        value: null,
                        child: Text('Sin asignar'),
                      ),
                      for (final vehiculo in widget.datos.vehiculos)
                        DropdownMenuItem(
                          value: vehiculo.id,
                          child: Text(vehiculo.placa),
                        ),
                    ],
                    onChanged: (id) => setState(() => _vehiculoAsignado = id),
                  ),
                ],
                if (widget.tipo == TipoRegistroFlota.vehiculo) ...[
                  TextFormField(
                    controller: _placa,
                    textCapitalization: TextCapitalization.characters,
                    decoration: const InputDecoration(labelText: 'Placa'),
                    validator: _validarPlaca,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _tipoVehiculo,
                    decoration: const InputDecoration(labelText: 'Tipo'),
                    validator: (valor) =>
                        _requerido(valor, 'Indica el tipo de vehículo.'),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _capacidad,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(
                      labelText: 'Capacidad (toneladas)',
                    ),
                    validator: _validarCapacidad,
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<EstadoVehiculo>(
                    initialValue: _estadoVehiculo,
                    decoration: const InputDecoration(labelText: 'Estado'),
                    items: [
                      for (final estado in EstadoVehiculo.values)
                        DropdownMenuItem(
                          value: estado,
                          child: Text(_nombreEstadoVehiculo(estado)),
                        ),
                    ],
                    onChanged: (estado) => setState(
                      () => _estadoVehiculo = estado ?? _estadoVehiculo,
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    _activo ? 'Registro activo' : 'Registro inactivo',
                  ),
                  value: _activo,
                  onChanged: (valor) => setState(() => _activo = valor),
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
                  label: const Text('Guardar'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _guardar() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _guardando = true);
    try {
      final existente = widget.existente;
      switch (widget.tipo) {
        case TipoRegistroFlota.usuario:
          final anterior = existente as UsuarioPanel?;
          final usuarios = widget.datos.usuarios;
          final id =
              anterior?.id ??
              _siguienteId(usuarios.map((usuario) => usuario.id));
          await ref
              .read(flotaControllerProvider.notifier)
              .guardarUsuario(
                UsuarioPanel(
                  id: id,
                  nombre: _nombre.text.trim(),
                  correo: _correo.text.trim().toLowerCase(),
                  rol: _rol,
                  activo: _activo,
                ),
              );
          break;
        case TipoRegistroFlota.conductor:
          final anterior = existente as Conductor?;
          final id =
              anterior?.id ??
              _siguienteId(widget.datos.conductores.map((item) => item.id));
          await ref
              .read(flotaControllerProvider.notifier)
              .guardarConductor(
                Conductor(
                  id: id,
                  nombre: _nombre.text.trim(),
                  telefono: _telefono.text.trim(),
                  categoriaLicencia: _licencia.text.trim().toUpperCase(),
                  estado: _estadoConductor,
                  vehiculoAsignado: _vehiculoAsignado,
                  activo: _activo,
                ),
              );
          break;
        case TipoRegistroFlota.vehiculo:
          final anterior = existente as Vehiculo?;
          final id =
              anterior?.id ??
              _siguienteId(widget.datos.vehiculos.map((item) => item.id));
          await ref
              .read(flotaControllerProvider.notifier)
              .guardarVehiculo(
                Vehiculo(
                  id: id,
                  placa: _placa.text.trim().toUpperCase(),
                  tipo: _tipoVehiculo.text.trim(),
                  capacidadToneladas: double.parse(_capacidad.text.trim()),
                  estado: _estadoVehiculo,
                  activo: _activo,
                ),
              );
          break;
      }
      if (mounted) Navigator.of(context).pop();
    } on StateError catch (error) {
      if (mounted) _mensaje(context, error.message.toString());
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }
}

class _FilaFlota extends StatelessWidget {
  const _FilaFlota({
    required this.tipo,
    required this.registro,
    required this.onEditar,
    required this.onAlternar,
  });

  final TipoRegistroFlota tipo;
  final Object registro;
  final VoidCallback onEditar;
  final VoidCallback onAlternar;

  @override
  Widget build(BuildContext context) {
    final resumen = switch (tipo) {
      TipoRegistroFlota.usuario => _resumenUsuario(registro as UsuarioPanel),
      TipoRegistroFlota.conductor => _resumenConductor(registro as Conductor),
      TipoRegistroFlota.vehiculo => _resumenVehiculo(registro as Vehiculo),
    };
    final activo = switch (tipo) {
      TipoRegistroFlota.usuario => (registro as UsuarioPanel).activo,
      TipoRegistroFlota.conductor => (registro as Conductor).activo,
      TipoRegistroFlota.vehiculo => (registro as Vehiculo).activo,
    };
    final visual = Theme.of(context)
        .extension<ColoresProceso>()!
        .para(activo ? EstadoProcesoPanel.activo : EstadoProcesoPanel.inactivo);
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onEditar,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(visual.icono, color: visual.color),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        resumen.$1,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(color: EcoColors.primario),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        resumen.$2,
                        style: Theme.of(context).textTheme.bodySmall
                            ?.copyWith(color: EcoColors.textoSecundario),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(visual.icono, size: 16, color: visual.color),
                          const SizedBox(width: 8),
                          Text(
                            activo ? 'Activo' : 'Inactivo',
                            style: TextStyle(color: visual.color),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                PopupMenuButton<String>(
                  tooltip: 'Acciones de registro',
                  onSelected: (accion) {
                    if (accion == 'editar') onEditar();
                    if (accion == 'alternar') onAlternar();
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(value: 'editar', child: Text('Editar')),
                    PopupMenuItem(
                      value: 'alternar',
                      child: Text(activo ? 'Desactivar' : 'Activar'),
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

class _CargaFlota extends StatelessWidget {
  const _CargaFlota();
  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.all(24),
    children: [
      for (var indice = 0; indice < 4; indice++)
        Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Container(
            height: 100,
            decoration: BoxDecoration(
              color: EcoColors.borde.withValues(alpha: 0.7),
              borderRadius: BorderRadius.circular(16),
            ),
          ),
        ),
    ],
  );
}

class _VacioFlota extends StatelessWidget {
  const _VacioFlota({required this.mensaje});
  final String mensaje;
  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Text(mensaje, textAlign: TextAlign.center),
    ),
  );
}

int _siguienteId(Iterable<int> ids) =>
    ids.fold<int>(0, (maximo, id) => id > maximo ? id : maximo) + 1;

String? _requerido(String? valor, String mensaje) =>
    valor == null || valor.trim().isEmpty ? mensaje : null;

String? _validarCorreo(String? valor) {
  final correo = valor?.trim() ?? '';
  if (correo.isEmpty) return 'Ingresa el correo.';
  return RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(correo)
      ? null
      : 'Ingresa un correo válido.';
}

String? _validarTelefono(String? valor) {
  final telefono = (valor ?? '').replaceAll(RegExp(r'\D'), '');
  if (!RegExp(r'^9\d{8}$').hasMatch(telefono)) {
    return 'Usa un celular peruano de 9 dígitos.';
  }
  return null;
}

String? _validarPlaca(String? valor) {
  final placa = valor?.trim().toUpperCase() ?? '';
  if (!RegExp(r'^[A-Z]{3}-\d{3}$').hasMatch(placa)) {
    return 'Usa el formato ABC-123.';
  }
  return null;
}

String? _validarCapacidad(String? valor) {
  final capacidad = double.tryParse((valor ?? '').trim());
  return capacidad == null || capacidad <= 0
      ? 'Ingresa una capacidad mayor que cero.'
      : null;
}

String _nombreTipoFlota(TipoRegistroFlota tipo) => switch (tipo) {
  TipoRegistroFlota.usuario => 'usuario',
  TipoRegistroFlota.conductor => 'conductor',
  TipoRegistroFlota.vehiculo => 'vehículo',
};

String _pluralTipoFlota(TipoRegistroFlota tipo) => switch (tipo) {
  TipoRegistroFlota.usuario => 'usuarios',
  TipoRegistroFlota.conductor => 'conductores',
  TipoRegistroFlota.vehiculo => 'vehículos',
};

String _nombreRol(RolPanel rol) => switch (rol) {
  RolPanel.administrador => 'Administrador',
  RolPanel.operador => 'Operador',
  RolPanel.supervisor => 'Supervisor',
};

String _nombreEstadoConductor(EstadoConductor estado) => switch (estado) {
  EstadoConductor.disponible => 'Disponible',
  EstadoConductor.enRuta => 'En ruta',
  EstadoConductor.descanso => 'Descanso',
};

String _nombreEstadoVehiculo(EstadoVehiculo estado) => switch (estado) {
  EstadoVehiculo.operativo => 'Operativo',
  EstadoVehiculo.mantenimiento => 'Mantenimiento',
};

(String, String) _resumenUsuario(UsuarioPanel usuario) =>
    (usuario.nombre, '${usuario.correo} · ${_nombreRol(usuario.rol)}');

(String, String) _resumenConductor(Conductor conductor) => (
  conductor.nombre,
  '${conductor.telefono} · ${conductor.categoriaLicencia} · '
      '${_nombreEstadoConductor(conductor.estado)}',
);

(String, String) _resumenVehiculo(Vehiculo vehiculo) => (
  vehiculo.placa,
  '${vehiculo.tipo} · ${vehiculo.capacidadToneladas} t · '
      '${_nombreEstadoVehiculo(vehiculo.estado)}',
);

String _identidadRegistro(TipoRegistroFlota tipo, Object registro) =>
    switch (tipo) {
      TipoRegistroFlota.usuario => (registro as UsuarioPanel).nombre,
      TipoRegistroFlota.conductor => (registro as Conductor).nombre,
      TipoRegistroFlota.vehiculo => (registro as Vehiculo).placa,
    };

void _mensaje(BuildContext context, String texto) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(texto)));
}
