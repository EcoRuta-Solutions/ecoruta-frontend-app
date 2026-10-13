import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/app_config.dart';
import '../../../core/network/api_client.dart';
import 'modelos_conductor.dart';

final repositorioConductorProvider = Provider<RepositorioConductor>(
  (ref) => AppConfig.usarDatosDeEjemplo
      ? RepositorioConductorMock()
      : RepositorioConductorApi(ref.read(dioProvider)),
);

/// Acceso a las rutas del conductor contra el backend real.
abstract interface class RepositorioConductor {
  Future<List<RutaConductor>> misRutas();

  Future<RutaConductor> detalle(int id);

  Future<RutaConductor> cambiarEstado(int id, EstadoRutaConductor estado);

  Future<ParadaConductor> marcarParada(
    int rutaId,
    int paradaId,
    bool recolectado,
  );

  Future<void> crearReporte({
    required double latitud,
    required double longitud,
    required String descripcion,
  });
}

class RepositorioConductorApi implements RepositorioConductor {
  RepositorioConductorApi(this._dio);

  final Dio _dio;

  @override
  Future<List<RutaConductor>> misRutas() async {
    final respuesta = await _dio.get('/rutas/mias');
    return (respuesta.data as List)
        .map((e) => RutaConductor.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<RutaConductor> detalle(int id) async {
    final respuesta = await _dio.get('/rutas/$id');
    return RutaConductor.fromJson(respuesta.data as Map<String, dynamic>);
  }

  @override
  Future<RutaConductor> cambiarEstado(
    int id,
    EstadoRutaConductor estado,
  ) async {
    final respuesta = await _dio.patch(
      '/rutas/$id',
      data: {'estado': estadoRutaATexto(estado)},
    );
    return RutaConductor.fromJson(respuesta.data as Map<String, dynamic>);
  }

  @override
  Future<ParadaConductor> marcarParada(
    int rutaId,
    int paradaId,
    bool recolectado,
  ) async {
    final respuesta = await _dio.patch(
      '/rutas/$rutaId/paradas/$paradaId',
      data: {'recolectado': recolectado},
    );
    return ParadaConductor.fromJson(respuesta.data as Map<String, dynamic>);
  }

  @override
  Future<void> crearReporte({
    required double latitud,
    required double longitud,
    required String descripcion,
  }) async {
    await _dio.post(
      '/reportes',
      data: {
        'latitud': latitud,
        'longitud': longitud,
        'descripcion': descripcion,
      },
    );
  }
}

class ReporteConductorMock {
  const ReporteConductorMock({
    required this.latitud,
    required this.longitud,
    required this.descripcion,
  });

  // EJEMPLO: reemplazar por API
  final double latitud;

  // EJEMPLO: reemplazar por API
  final double longitud;

  // EJEMPLO: reemplazar por API
  final String descripcion;
}

/// Repositorio en memoria para probar los flujos del conductor sin backend.
class RepositorioConductorMock implements RepositorioConductor {
  RepositorioConductorMock() : _rutas = _crearRutasEjemplo(), _reportes = [];

  // EJEMPLO: reemplazar por API
  final List<RutaConductor> _rutas;

  // EJEMPLO: reemplazar por API
  final List<ReporteConductorMock> _reportes;

  List<ReporteConductorMock> get reportes =>
      List<ReporteConductorMock>.unmodifiable(_reportes);

  @override
  Future<List<RutaConductor>> misRutas() async =>
      List<RutaConductor>.unmodifiable(_rutas);

  @override
  Future<RutaConductor> detalle(int id) async => _rutaPorId(id);

  @override
  Future<RutaConductor> cambiarEstado(
    int id,
    EstadoRutaConductor estado,
  ) async {
    final ruta = _rutaPorId(id);
    final actualizada = _copiarRuta(ruta, estado: estado);
    _reemplazarRuta(actualizada);
    return actualizada;
  }

  @override
  Future<ParadaConductor> marcarParada(
    int rutaId,
    int paradaId,
    bool recolectado,
  ) async {
    final ruta = _rutaPorId(rutaId);
    final indice = ruta.paradas.indexWhere((parada) => parada.id == paradaId);
    if (indice < 0) {
      throw StateError('No existe la parada solicitada.');
    }

    final actualizada = ruta.paradas[indice].copiar(recolectado: recolectado);
    final paradas = [...ruta.paradas]..[indice] = actualizada;
    _reemplazarRuta(_copiarRuta(ruta, paradas: paradas));
    return actualizada;
  }

  @override
  Future<void> crearReporte({
    required double latitud,
    required double longitud,
    required String descripcion,
  }) async {
    _reportes.add(
      ReporteConductorMock(
        // EJEMPLO: reemplazar por API
        latitud: latitud,
        // EJEMPLO: reemplazar por API
        longitud: longitud,
        // EJEMPLO: reemplazar por API
        descripcion: descripcion,
      ),
    );
  }

  RutaConductor _rutaPorId(int id) => _rutas.firstWhere(
    (ruta) => ruta.id == id,
    orElse: () => throw StateError('No existe la ruta solicitada.'),
  );

  void _reemplazarRuta(RutaConductor ruta) {
    final indice = _rutas.indexWhere((actual) => actual.id == ruta.id);
    _rutas[indice] = ruta;
  }

  RutaConductor _copiarRuta(
    RutaConductor ruta, {
    EstadoRutaConductor? estado,
    List<ParadaConductor>? paradas,
  }) => RutaConductor(
    id: ruta.id,
    fechaInicio: ruta.fechaInicio,
    fechaFin: ruta.fechaFin,
    horaInicio: ruta.horaInicio,
    horaFin: ruta.horaFin,
    camionId: ruta.camionId,
    conductorId: ruta.conductorId,
    estado: estado ?? ruta.estado,
    camion: ruta.camion,
    paradas: paradas ?? ruta.paradas,
  );
}

List<RutaConductor> _crearRutasEjemplo() {
  // EJEMPLO: reemplazar por API
  const camion = CamionConductor(
    id: 1,
    placa: 'TCA-241',
    capacidad: 8000,
    turno: 'Mañana',
  );
  final fecha = DateTime(2026, 10, 12);

  return [
    // EJEMPLO: reemplazar por API
    _crearRuta(
      id: 101,
      fecha: fecha,
      camion: camion,
      estado: EstadoRutaConductor.pendiente,
      horaInicio: const TimeOfDay(hour: 6, minute: 0),
      horaFin: const TimeOfDay(hour: 10, minute: 0),
      nodos: const [1, 2, 3, 4, 5],
    ),
    // EJEMPLO: reemplazar por API
    _crearRuta(
      id: 102,
      fecha: fecha,
      camion: camion,
      estado: EstadoRutaConductor.enProceso,
      horaInicio: const TimeOfDay(hour: 10, minute: 30),
      horaFin: const TimeOfDay(hour: 14, minute: 0),
      nodos: const [3, 4, 5, 6, 7],
      paradasHechas: 2,
    ),
    // EJEMPLO: reemplazar por API
    _crearRuta(
      id: 103,
      fecha: fecha.subtract(const Duration(days: 1)),
      camion: camion,
      estado: EstadoRutaConductor.completado,
      horaInicio: const TimeOfDay(hour: 6, minute: 0),
      horaFin: const TimeOfDay(hour: 9, minute: 45),
      nodos: const [4, 5, 6, 7, 8, 1],
      paradasHechas: 6,
    ),
  ];
}

RutaConductor _crearRuta({
  required int id,
  required DateTime fecha,
  required CamionConductor camion,
  required EstadoRutaConductor estado,
  required TimeOfDay horaInicio,
  required TimeOfDay horaFin,
  required List<int> nodos,
  int paradasHechas = 0,
}) {
  // EJEMPLO: reemplazar por API
  final paradas = [
    for (var indice = 0; indice < nodos.length; indice++)
      ParadaConductor(
        id: id * 10 + indice + 1,
        rutaId: id,
        nodoId: nodos[indice],
        orden: indice + 1,
        recolectado: indice < paradasHechas,
        // EJEMPLO: reemplazar por API
        horaEstimada: DateTime(
          fecha.year,
          fecha.month,
          fecha.day,
          horaInicio.hour,
          horaInicio.minute,
        ).add(Duration(minutes: 15 * (indice + 1))),
        nodo: _nodoEjemplo(nodos[indice]),
      ),
  ];
  return RutaConductor(
    id: id,
    fechaInicio: fecha,
    fechaFin: fecha,
    horaInicio: DateTime(
      fecha.year,
      fecha.month,
      fecha.day,
      horaInicio.hour,
      horaInicio.minute,
    ),
    horaFin: DateTime(
      fecha.year,
      fecha.month,
      fecha.day,
      horaFin.hour,
      horaFin.minute,
    ),
    camionId: camion.id,
    conductorId: 1,
    estado: estado,
    camion: camion,
    paradas: paradas,
  );
}

NodoConductor _nodoEjemplo(int id) {
  // EJEMPLO: reemplazar por API
  const nodos = <int, NodoConductor>{
    1: NodoConductor(
      id: 1,
      codigo: 'TRU-001',
      nombre: 'Mercado Central',
      latitud: -8.1116,
      longitud: -79.0288,
      umbralCritico: 80,
      // EJEMPLO: reemplazar por API
      llenado: 94,
      // EJEMPLO: reemplazar por API
      prioridad: 'Crítica',
    ),
    2: NodoConductor(
      id: 2,
      codigo: 'TRU-002',
      nombre: 'Av. España',
      latitud: -8.1099,
      longitud: -79.0310,
      umbralCritico: 80,
      // EJEMPLO: reemplazar por API
      llenado: 86,
      // EJEMPLO: reemplazar por API
      prioridad: 'Crítica',
    ),
    3: NodoConductor(
      id: 3,
      codigo: 'TRU-003',
      nombre: 'Plaza de Armas',
      latitud: -8.1110,
      longitud: -79.0279,
      umbralCritico: 80,
      // EJEMPLO: reemplazar por API
      llenado: 77,
      // EJEMPLO: reemplazar por API
      prioridad: 'Alta',
    ),
    4: NodoConductor(
      id: 4,
      codigo: 'TRU-004',
      nombre: 'Urb. Primavera',
      latitud: -8.1048,
      longitud: -79.0322,
      umbralCritico: 80,
      // EJEMPLO: reemplazar por API
      llenado: 70,
      // EJEMPLO: reemplazar por API
      prioridad: 'Alta',
    ),
    5: NodoConductor(
      id: 5,
      codigo: 'TRU-005',
      nombre: 'Av. Larco',
      latitud: -8.1232,
      longitud: -79.0358,
      umbralCritico: 80,
      // EJEMPLO: reemplazar por API
      llenado: 54,
      // EJEMPLO: reemplazar por API
      prioridad: 'Media',
    ),
    6: NodoConductor(
      id: 6,
      codigo: 'TRU-006',
      nombre: 'Parque César Vallejo',
      latitud: -8.1162,
      longitud: -79.0209,
      umbralCritico: 80,
      // EJEMPLO: reemplazar por API
      llenado: 39,
      // EJEMPLO: reemplazar por API
      prioridad: 'Media',
    ),
    7: NodoConductor(
      id: 7,
      codigo: 'TRU-007',
      nombre: 'Urb. El Recreo',
      latitud: -8.1181,
      longitud: -79.0271,
      umbralCritico: 80,
      // EJEMPLO: reemplazar por API
      llenado: 18,
      // EJEMPLO: reemplazar por API
      prioridad: 'Baja',
    ),
    8: NodoConductor(
      id: 8,
      codigo: 'TRU-008',
      nombre: 'Av. América Oeste',
      latitud: -8.1080,
      longitud: -79.0390,
      umbralCritico: 80,
      // EJEMPLO: reemplazar por API
      llenado: null,
      // EJEMPLO: reemplazar por API
      prioridad: null,
    ),
  };
  return nodos[id]!;
}
