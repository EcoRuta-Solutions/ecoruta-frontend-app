import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import 'modelos_conductor.dart';

final repositorioConductorProvider = Provider<RepositorioConductor>(
  (ref) => RepositorioConductorApi(ref.read(dioProvider)),
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
