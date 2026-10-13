import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/app_config.dart';
import '../../../core/network/api_client.dart';

/// Camión que puede recibir una ruta generada (GET /camiones/).
class CamionDisponible {
  const CamionDisponible({
    required this.id,
    required this.placa,
    required this.turno,
  });

  final int id;
  final String placa;
  final String turno;

  factory CamionDisponible.fromJson(Map<String, dynamic> j) => CamionDisponible(
    id: j['id'] as int,
    placa: j['placa'] as String,
    turno: j['turno'] as String? ?? '',
  );
}

/// Conductor activo al que se le puede asignar la ruta
/// (GET /usuarios/conductores).
class ConductorDisponible {
  const ConductorDisponible({
    required this.id,
    required this.nombre,
    required this.email,
  });

  final int id;
  final String nombre;
  final String email;

  factory ConductorDisponible.fromJson(Map<String, dynamic> j) =>
      ConductorDisponible(
        id: j['id'] as int,
        nombre: (j['nombre'] ?? j['email'] ?? '') as String,
        email: (j['email'] ?? '') as String,
      );
}

/// Resultado de POST /rutas/generar.
class ResultadoRutaOptima {
  const ResultadoRutaOptima({
    required this.rutaId,
    required this.metodo,
    required this.distanciaKm,
    required this.paradas,
  });

  final int rutaId;
  final String metodo;
  final double distanciaKm;
  final int paradas;
}

/// Genera rutas óptimas a partir de los contenedores críticos.
abstract interface class RepositorioOptimizacionRutas {
  Future<List<CamionDisponible>> camiones();
  Future<List<ConductorDisponible>> conductores();
  Future<ResultadoRutaOptima> generarOptima({
    required int camionId,
    int? conductorId,
  });
}

class RepositorioOptimizacionRutasApi implements RepositorioOptimizacionRutas {
  RepositorioOptimizacionRutasApi(this._dio);

  final Dio _dio;

  @override
  Future<List<CamionDisponible>> camiones() async {
    final respuesta = await _dio.get('/camiones/');
    return (respuesta.data as List)
        .map((e) => CamionDisponible.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<List<ConductorDisponible>> conductores() async {
    final respuesta = await _dio.get('/usuarios/conductores');
    return (respuesta.data as List)
        .map((e) => ConductorDisponible.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<ResultadoRutaOptima> generarOptima({
    required int camionId,
    int? conductorId,
  }) async {
    final respuesta = await _dio.post(
      '/rutas/generar',
      data: {
        'fecha': DateTime.now().toIso8601String().split('T').first,
        'camion_id': camionId,
        'conductor_id': ?conductorId,
      },
    );
    final datos = respuesta.data as Map<String, dynamic>;
    final ruta = datos['ruta'] as Map<String, dynamic>;
    return ResultadoRutaOptima(
      rutaId: ruta['id'] as int,
      metodo: datos['metodo'] as String? ?? 'optimizado',
      distanciaKm: (datos['distancia_km'] as num?)?.toDouble() ?? 0,
      paradas: (ruta['paradas'] as List? ?? const []).length,
    );
  }
}

/// Resultado simulado para la demo sin backend.
class RepositorioOptimizacionRutasMock implements RepositorioOptimizacionRutas {
  @override
  Future<List<CamionDisponible>> camiones() async => const [
    CamionDisponible(id: 1, placa: 'TCA-241', turno: 'Mañana'),
    CamionDisponible(id: 2, placa: 'TCA-508', turno: 'Tarde'),
    CamionDisponible(id: 3, placa: 'TCA-316', turno: 'Noche'),
  ];

  @override
  Future<List<ConductorDisponible>> conductores() async => const [
    ConductorDisponible(
      id: 2,
      nombre: 'Conductor de prueba',
      email: 'conductor@ecoruta.com',
    ),
  ];

  @override
  Future<ResultadoRutaOptima> generarOptima({
    required int camionId,
    int? conductorId,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 500));
    return const ResultadoRutaOptima(
      rutaId: 900,
      metodo: 'ortools',
      distanciaKm: 12.4,
      paradas: 2,
    );
  }
}

final repositorioOptimizacionRutasProvider =
    Provider<RepositorioOptimizacionRutas>(
      (ref) => AppConfig.usarDatosDeEjemplo
          ? RepositorioOptimizacionRutasMock()
          : RepositorioOptimizacionRutasApi(ref.read(dioProvider)),
    );
