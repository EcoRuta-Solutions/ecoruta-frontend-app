import 'dart:math' as math;

import 'package:dio/dio.dart';

import 'modelos_flota.dart';
import 'modelos_informe.dart';
import 'modelos_lectura_nodo.dart';
import 'modelos_panel.dart';
import 'modelos_ruta.dart';
import 'panel_mock.dart';
import 'repositorios_mock.dart';

/// Contenedores contra el backend real (GET /panel/estado, lecturas y
/// predicción). Crear/editar nodos todavía no se hace desde el panel, así que
/// `guardar` y `eliminar` avisan que no están soportados.
class RepositorioContenedoresApi implements RepositorioContenedores {
  RepositorioContenedoresApi(this._dio);

  final Dio _dio;

  @override
  Future<List<NodoEstado>> listar() async {
    final respuesta = await _dio.get('/panel/estado');
    return (respuesta.data as List)
        .map((e) => NodoEstado.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<NodoEstado?> obtener(int id) async {
    final nodos = await listar();
    for (final nodo in nodos) {
      if (nodo.id == id) return nodo;
    }
    return null;
  }

  @override
  Future<DetalleNodo?> obtenerDetalle(int id, {required int dias}) async {
    final nodo = await obtener(id);
    if (nodo == null) return null;

    final lecturas = await _lecturas(id);
    final eventos = _eventosDe(nodo, lecturas);
    final prediccion = await _prediccion(id);

    return DetalleNodo(
      nodo: nodo,
      lecturas: lecturas,
      eventos: eventos,
      prediccion: prediccion,
    );
  }

  Future<List<LecturaLlenado>> _lecturas(int id) async {
    final respuesta = await _dio.get(
      '/nodos/$id/lecturas',
      queryParameters: {'limite': 200},
    );
    final lecturas = [
      for (final item in (respuesta.data as List))
        LecturaLlenado(
          fecha: DateTime.parse(
            (item as Map<String, dynamic>)['timestamp'] as String,
          ).toLocal(),
          porcentaje: (item['fill_pct'] as num).toDouble(),
        ),
    ];
    lecturas.sort((a, b) => a.fecha.compareTo(b.fecha));
    return lecturas;
  }

  List<EventoNodo> _eventosDe(NodoEstado nodo, List<LecturaLlenado> lecturas) {
    final ahora = DateTime.now();
    final eventos = <EventoNodo>[
      if (nodo.volteado == true)
        EventoNodo(
          tipo: TipoEventoNodo.volteado,
          fecha: nodo.ultimaLectura ?? ahora,
          descripcion: 'Se detectó una inclinación fuera de rango.',
        ),
      if ((nodo.bateria ?? 100) < 70)
        EventoNodo(
          tipo: TipoEventoNodo.bateriaBaja,
          fecha: nodo.ultimaLectura ?? ahora,
          descripcion: 'La batería requiere revisión.',
        ),
      if (nodo.estadoOperativo == EstadoOperativo.mantenimiento)
        EventoNodo(
          tipo: TipoEventoNodo.mantenimiento,
          fecha: ahora,
          descripcion: 'Inicio de mantenimiento preventivo.',
        ),
    ]..sort((a, b) => b.fecha.compareTo(a.fecha));
    return eventos;
  }

  Future<PrediccionLlenado?> _prediccion(int id) async {
    final respuesta = await _dio.get('/nodos/$id/prediccion');
    final datos = respuesta.data as Map<String, dynamic>;
    final fecha = datos['fecha_estimada_critico'];
    if (fecha == null) return null;
    return PrediccionLlenado(
      horaEstimadaDesborde: DateTime.parse(fecha as String).toLocal(),
      confianza: (datos['confianza'] as num?)?.toDouble() ?? 0,
    );
  }

  @override
  Future<void> guardar(NodoEstado nodo) async {
    throw UnsupportedError(
      'Crear o editar contenedores desde el panel aún no está disponible.',
    );
  }

  @override
  Future<void> eliminar(int id) async {
    throw UnsupportedError(
      'Eliminar contenedores desde el panel aún no está disponible.',
    );
  }
}

/// Totales y nodos del panel contra el backend (GET /panel/estado y resumen).
class RepositorioPanelApi implements RepositorioPanel {
  RepositorioPanelApi(this._dio);

  final Dio _dio;

  @override
  Future<DatosPanel> cargar() async {
    final respuestas = await Future.wait([
      _dio.get('/panel/estado'),
      _dio.get('/panel/resumen'),
    ]);
    final nodos = (respuestas[0].data as List)
        .map((e) => NodoEstado.fromJson(e as Map<String, dynamic>))
        .toList();
    final resumen = ResumenPanel.fromJson(
      respuestas[1].data as Map<String, dynamic>,
    );
    return DatosPanel(nodos: nodos, resumen: resumen);
  }
}

/// Traduce un error del backend a un mensaje apto para el panel. Se devuelve
/// como [StateError] porque las pantallas de dominio capturan ese tipo.
StateError _errorApi(Object error, {String alternativo = 'No se pudo completar la acción.'}) {
  if (error is DioException) {
    final codigo = error.response?.statusCode;
    final detalle = error.response?.data;
    final mensajeBackend = detalle is Map<String, dynamic>
        ? detalle['detail']
        : null;
    if (codigo == 401) return StateError('Tu sesión venció. Inicia sesión nuevamente.');
    if (codigo == 403) return StateError('No tienes permiso para esta acción.');
    if (codigo == 404) {
      return StateError(mensajeBackend?.toString() ?? 'No se encontró el recurso.');
    }
    if (codigo == 409) {
      return StateError(mensajeBackend?.toString() ?? 'El registro ya existe.');
    }
    if (codigo == 501) {
      return StateError(
        mensajeBackend?.toString() ?? 'Esta acción no está disponible.',
      );
    }
    if (error.type == DioExceptionType.connectionTimeout ||
        error.type == DioExceptionType.sendTimeout ||
        error.type == DioExceptionType.receiveTimeout ||
        error.type == DioExceptionType.connectionError) {
      return StateError('No se pudo conectar. Revisa tu conexión e inténtalo de nuevo.');
    }
    if (mensajeBackend != null) return StateError(mensajeBackend.toString());
  }
  return StateError(alternativo);
}

/// Flota contra el backend real (GET/POST/PATCH /flota/*).
class RepositorioFlotaApi implements RepositorioFlota {
  RepositorioFlotaApi(this._dio);

  final Dio _dio;

  @override
  Future<List<Vehiculo>> vehiculos() async {
    try {
      final respuesta = await _dio.get('/flota/vehiculos');
      return [
        for (final item in (respuesta.data as List))
          _vehiculoDesdeJson(item as Map<String, dynamic>),
      ];
    } on DioException catch (error) {
      throw _errorApi(error, alternativo: 'No se pudo cargar la flota.');
    }
  }

  @override
  Future<List<Conductor>> conductores() async {
    try {
      final respuesta = await _dio.get('/flota/conductores');
      return [
        for (final item in (respuesta.data as List))
          _conductorDesdeJson(item as Map<String, dynamic>),
      ];
    } on DioException catch (error) {
      throw _errorApi(error, alternativo: 'No se pudo cargar la flota.');
    }
  }

  @override
  Future<List<UsuarioPanel>> usuarios() async {
    try {
      final respuesta = await _dio.get('/flota/usuarios');
      return [
        for (final item in (respuesta.data as List))
          _usuarioDesdeJson(item as Map<String, dynamic>),
      ];
    } on DioException catch (error) {
      throw _errorApi(error, alternativo: 'No se pudo cargar la flota.');
    }
  }

  @override
  Future<void> guardarVehiculo(Vehiculo vehiculo) async {
    final cuerpo = {
      'placa': vehiculo.placa,
      'tipo': vehiculo.tipo,
      'capacidad_toneladas': vehiculo.capacidadToneladas,
      'estado': vehiculo.estado.name,
      'activo': vehiculo.activo,
    };
    await _guardar('/flota/vehiculos', vehiculo.id, cuerpo);
  }

  @override
  Future<void> guardarConductor(Conductor conductor) async {
    if (!conductor.activo && conductor.estado == EstadoConductor.enRuta) {
      throw StateError(
        'No se puede desactivar a un conductor con una ruta en curso.',
      );
    }
    final cuerpo = {
      'nombre': conductor.nombre,
      'telefono': conductor.telefono,
      'categoria_licencia': conductor.categoriaLicencia,
      'estado': _estadoConductorBackend(conductor.estado),
      'vehiculo_id': conductor.vehiculoAsignado,
      'activo': conductor.activo,
    };
    await _guardar('/flota/conductores', conductor.id, cuerpo);
  }

  @override
  Future<void> guardarUsuario(UsuarioPanel usuario) async {
    final cuerpo = {
      'nombre': usuario.nombre,
      'rol': usuario.rol.name,
      'activo': usuario.activo,
    };
    await _guardar('/flota/usuarios', usuario.id, cuerpo);
  }

  Future<void> _guardar(String recurso, int id, Map<String, dynamic> cuerpo) async {
    try {
      final existentes = await _dio.get(recurso);
      final existe = (existentes.data as List)
          .any((item) => (item as Map<String, dynamic>)['id'] == id);
      if (existe) {
        await _dio.patch('$recurso/$id', data: cuerpo);
      } else {
        await _dio.post(recurso, data: cuerpo);
      }
    } on DioException catch (error) {
      throw _errorApi(error);
    }
  }
}

/// Rutas municipales contra el backend real (GET /rutas/mias, PATCH /rutas/{id}).
class RepositorioRutasApi implements RepositorioRutas {
  RepositorioRutasApi(this._dio);

  final Dio _dio;

  @override
  Future<List<RutaMunicipal>> listar() async {
    try {
      final respuestas = await Future.wait([
        _dio.get('/rutas/mias'),
        _dio.get('/flota/conductores'),
        _dio.get('/flota/vehiculos'),
      ]);
      final conductorPorUsuario = {
        for (final item in (respuestas[1].data as List))
          if ((item as Map<String, dynamic>)['usuario_id'] != null)
            item['usuario_id'] as int: item['id'] as int,
      };
      final vehiculoPorPlaca = {
        for (final item in (respuestas[2].data as List))
          (item as Map<String, dynamic>)['placa'] as String: item['id'] as int,
      };
      return [
        for (final item in (respuestas[0].data as List))
          _rutaDesdeJson(
            item as Map<String, dynamic>,
            conductorPorUsuario: conductorPorUsuario,
            vehiculoPorPlaca: vehiculoPorPlaca,
          ),
      ];
    } on DioException catch (error) {
      throw _errorApi(error, alternativo: 'No se pudieron cargar las rutas.');
    }
  }

  @override
  Future<void> guardar(RutaMunicipal ruta) async {
    throw StateError('Las rutas se crean con "Generar ruta óptima".');
  }

  @override
  Future<void> aprobar(String id, {required String quien}) async {
    try {
      await _dio.patch(
        '/rutas/${_idNumerico(id)}',
        data: {'estado': 'en_proceso'},
      );
    } on DioException catch (error) {
      throw _errorApi(error, alternativo: 'No se pudo aprobar la ruta.');
    }
  }

  @override
  Future<void> reasignar(
    String id, {
    required Conductor conductor,
    required Vehiculo vehiculo,
    required String quien,
  }) async {
    throw StateError('La reasignación no está disponible con el backend real.');
  }
}

/// Informes contra el backend real (GET /informes/resumen).
class RepositorioInformesApi implements RepositorioInformes {
  RepositorioInformesApi(this._dio);

  final Dio _dio;

  @override
  Future<DatosInforme> cargar(DateTime inicio, DateTime fin) async {
    try {
      final respuesta = await _dio.get(
        '/informes/resumen',
        queryParameters: {'inicio': _fechaIso(inicio), 'fin': _fechaIso(fin)},
      );
      final datos = respuesta.data as Map<String, dynamic>;
      return DatosInforme(
        inicio: DateTime.parse(datos['inicio'] as String),
        fin: DateTime.parse(datos['fin'] as String),
        kpis: [
          for (final kpi in (datos['kpis'] as List))
            _kpiDesdeJson(kpi as Map<String, dynamic>),
        ],
        llenadoPromedio: _serieDesdeJson(datos['llenado_promedio'] as List),
        desbordesPorZona: {
          for (final entrada
              in (datos['desbordes_por_zona'] as Map<String, dynamic>).entries)
            entrada.key: (entrada.value as num).toInt(),
        },
        kilometrosOptimizados: _serieDesdeJson(
          datos['kilometros_optimizados'] as List,
        ),
        kilometrosFijos: _serieDesdeJson(datos['kilometros_fijos'] as List),
      );
    } on DioException catch (error) {
      throw _errorApi(error, alternativo: 'No se pudieron cargar los informes.');
    }
  }
}

Vehiculo _vehiculoDesdeJson(Map<String, dynamic> j) => Vehiculo(
  id: j['id'] as int,
  placa: j['placa'] as String,
  tipo: (j['tipo'] ?? 'Compactador') as String,
  capacidadToneladas: (j['capacidad_toneladas'] as num?)?.toDouble() ?? 0,
  estado: (j['estado'] == 'mantenimiento')
      ? EstadoVehiculo.mantenimiento
      : EstadoVehiculo.operativo,
  activo: (j['activo'] as bool?) ?? true,
);

Conductor _conductorDesdeJson(Map<String, dynamic> j) => Conductor(
  id: j['id'] as int,
  nombre: j['nombre'] as String,
  telefono: (j['telefono'] ?? '') as String,
  categoriaLicencia: (j['categoria_licencia'] ?? 'A-IIb') as String,
  estado: switch (j['estado']) {
    'en_ruta' => EstadoConductor.enRuta,
    'descanso' => EstadoConductor.descanso,
    _ => EstadoConductor.disponible,
  },
  vehiculoAsignado: j['vehiculo_id'] as int?,
  activo: (j['activo'] as bool?) ?? true,
);

UsuarioPanel _usuarioDesdeJson(Map<String, dynamic> j) => UsuarioPanel(
  id: j['id'] as int,
  nombre: j['nombre'] as String,
  correo: (j['correo'] ?? '') as String,
  rol: switch (j['rol']) {
    'operador' => RolPanel.operador,
    'supervisor' => RolPanel.supervisor,
    _ => RolPanel.administrador,
  },
  activo: (j['activo'] as bool?) ?? true,
);

String _estadoConductorBackend(EstadoConductor estado) => switch (estado) {
  EstadoConductor.disponible => 'disponible',
  EstadoConductor.enRuta => 'en_ruta',
  EstadoConductor.descanso => 'descanso',
};

RutaMunicipal _rutaDesdeJson(
  Map<String, dynamic> j, {
  Map<int, int> conductorPorUsuario = const {},
  Map<String, int> vehiculoPorPlaca = const {},
}) {
  final camion = j['camion'] as Map<String, dynamic>?;
  final horaInicio = DateTime.parse(j['hora_inicio'] as String);
  final paradas = <ParadaRuta>[];
  final coords = <({double lat, double lon})>[];
  for (final item in (j['paradas'] as List? ?? const [])) {
    final parada = item as Map<String, dynamic>;
    final orden = parada['orden'] as int;
    paradas.add(
      ParadaRuta(
        nodoId: parada['nodo_id'] as int,
        orden: orden,
        horaEstimada: horaInicio.add(Duration(minutes: 15 * (orden - 1))),
      ),
    );
    final nodo = parada['nodo'] as Map<String, dynamic>?;
    if (nodo != null) {
      coords.add((
        lat: (nodo['latitud'] as num).toDouble(),
        lon: (nodo['longitud'] as num).toDouble(),
      ));
    }
  }
  paradas.sort((a, b) => a.orden.compareTo(b.orden));
  final distancia = _distanciaRuta(coords);
  final duracion = (distancia / 20 * 60 + paradas.length * 3).round();
  final conductorUsuarioId = j['conductor_id'] as int?;
  final placaCamion = camion?['placa'] as String?;
  return RutaMunicipal(
    id: 'RUT-${(j['id'] as int).toString().padLeft(3, '0')}',
    nombre: camion == null ? 'Ruta ${j['id']}' : 'Ruta $placaCamion',
    zona: (camion?['turno'] as String?) ?? 'Sin turno',
    estado: switch (j['estado']) {
      'en_proceso' => EstadoRuta.enCurso,
      'Completado' || 'Cancelado' => EstadoRuta.completada,
      _ => EstadoRuta.propuesta,
    },
    paradas: paradas,
    distanciaKm: distancia,
    duracionMin: duracion,
    distanciaFijaKm: distancia * 1.3,
    duracionFijaMin: (duracion * 1.25).round(),
    paradasFijas: paradas.length + 3,
    conductorId: conductorUsuarioId == null
        ? null
        : conductorPorUsuario[conductorUsuarioId] ?? conductorUsuarioId,
    vehiculoId: placaCamion == null
        ? j['camion_id'] as int?
        : vehiculoPorPlaca[placaCamion] ?? j['camion_id'] as int?,
  );
}

KpiInforme _kpiDesdeJson(Map<String, dynamic> j) => KpiInforme(
  clave: j['clave'] as String,
  nombre: j['nombre'] as String,
  valor: (j['valor'] as num).toDouble(),
  meta: (j['meta'] as num).toDouble(),
  unidad: j['unidad'] as String,
  mayorEsMejor: j['mayor_es_mejor'] as bool,
);

List<PuntoSerieInforme> _serieDesdeJson(List items) => [
  for (final item in items)
    PuntoSerieInforme(
      fecha: DateTime.parse((item as Map<String, dynamic>)['fecha'] as String),
      valor: (item['valor'] as num).toDouble(),
    ),
];

int _idNumerico(String id) =>
    int.parse(id.replaceAll(RegExp(r'[^0-9]'), ''));

String _fechaIso(DateTime fecha) =>
    '${fecha.year.toString().padLeft(4, '0')}-'
    '${fecha.month.toString().padLeft(2, '0')}-'
    '${fecha.day.toString().padLeft(2, '0')}';

double _distanciaRuta(List<({double lat, double lon})> coords) {
  var total = 0.0;
  for (var i = 1; i < coords.length; i++) {
    total += _haversineKm(coords[i - 1], coords[i]);
  }
  return double.parse(total.toStringAsFixed(2));
}

double _haversineKm(
  ({double lat, double lon}) origen,
  ({double lat, double lon}) destino,
) {
  const radioTierra = 6371.0088;
  final dLat = _rad(destino.lat - origen.lat);
  final dLon = _rad(destino.lon - origen.lon);
  final a =
      math.pow(math.sin(dLat / 2), 2) +
      math.cos(_rad(origen.lat)) *
          math.cos(_rad(destino.lat)) *
          math.pow(math.sin(dLon / 2), 2);
  return radioTierra * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
}

double _rad(double grados) => grados * math.pi / 180;
