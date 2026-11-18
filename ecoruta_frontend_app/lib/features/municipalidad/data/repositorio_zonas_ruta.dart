import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/app_config.dart';
import '../../../core/network/api_client.dart';
import 'modelos_zonas_ruta.dart';

abstract interface class RepositorioZonasRuta {
  /// Zonas de ruta, opcionalmente de un solo turno. El backend ya las
  /// devuelve ordenadas por turno y código (M-2 antes que M-10).
  Future<List<ZonaRuta>> listar({TurnoZona? turno});

  /// Una zona por su código, o null si no existe.
  Future<ZonaRuta?> obtener(String codigo);
}

final repositorioZonasRutaProvider = Provider<RepositorioZonasRuta>(
  (ref) => AppConfig.usarDatosDeEjemplo
      ? RepositorioZonasRutaMock()
      : RepositorioZonasRutaApi(ref.read(dioProvider)),
);

/// Zonas de ruta contra el backend real (GET /zonas-ruta). Usa el cliente
/// dio compartido, que ya adjunta el token.
class RepositorioZonasRutaApi implements RepositorioZonasRuta {
  RepositorioZonasRutaApi(this._dio);

  final Dio _dio;

  @override
  Future<List<ZonaRuta>> listar({TurnoZona? turno}) async {
    final respuesta = await _dio.get(
      '/zonas-ruta',
      queryParameters: {if (turno != null) 'turno': turno.valorApi},
    );
    return (respuesta.data as List<dynamic>)
        .map((zona) => ZonaRuta.fromJson(zona as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<ZonaRuta?> obtener(String codigo) async {
    try {
      final respuesta = await _dio.get(
        '/zonas-ruta/${Uri.encodeComponent(codigo)}',
      );
      return ZonaRuta.fromJson(respuesta.data as Map<String, dynamic>);
    } on DioException catch (error) {
      if (error.response?.statusCode == 404) return null;
      rethrow;
    }
  }
}

/// Datos de ejemplo para USE_MOCK=true. No son rutas reales de SEGAT:
/// los códigos, tramos y sectores dicen "EJEMPLO" a propósito, y la pantalla
/// muestra el aviso "Datos de ejemplo".
class RepositorioZonasRutaMock implements RepositorioZonasRuta {
  static const _latencia = Duration(milliseconds: 300);

  static const zonas = <ZonaRuta>[
    ZonaRuta(
      id: 1,
      codigo: 'EJEMPLO-M1',
      turno: TurnoZona.manana,
      tramo: 'Tramo de ejemplo A',
      sectores: 'Sector de ejemplo 1, Sector de ejemplo 2',
      recojoInicio: HoraDia(5, 0),
      recojoFin: HoraDia(9, 0),
      sacarBasuraInicio: HoraDia(4, 30),
      sacarBasuraFin: HoraDia(5, 0),
      cruzaMedianoche: false,
      revisar: false,
    ),
    ZonaRuta(
      id: 2,
      codigo: 'EJEMPLO-M2',
      turno: TurnoZona.manana,
      tramo: 'Tramo de ejemplo B',
      sectores: 'Sector de ejemplo 3',
      recojoInicio: HoraDia(9, 0),
      recojoFin: HoraDia(13, 0),
      sacarBasuraInicio: null,
      sacarBasuraFin: null,
      cruzaMedianoche: false,
      revisar: true,
    ),
    ZonaRuta(
      id: 3,
      codigo: 'EJEMPLO-T1',
      turno: TurnoZona.tarde,
      tramo: 'Tramo de ejemplo C',
      sectores: 'Sector de ejemplo 4',
      recojoInicio: HoraDia(13, 0),
      recojoFin: HoraDia(17, 0),
      sacarBasuraInicio: HoraDia(12, 30),
      sacarBasuraFin: HoraDia(13, 0),
      cruzaMedianoche: false,
      revisar: false,
    ),
    ZonaRuta(
      id: 4,
      codigo: 'EJEMPLO-N1',
      turno: TurnoZona.noche,
      tramo: 'Tramo de ejemplo D',
      sectores: 'Sector de ejemplo 5, Sector de ejemplo 6',
      recojoInicio: HoraDia(21, 0),
      recojoFin: HoraDia(5, 0),
      sacarBasuraInicio: HoraDia(20, 0),
      sacarBasuraFin: HoraDia(21, 0),
      cruzaMedianoche: true,
      revisar: true,
    ),
  ];

  @override
  Future<List<ZonaRuta>> listar({TurnoZona? turno}) async {
    await Future<void>.delayed(_latencia);
    return [
      for (final zona in zonas)
        if (turno == null || zona.turno == turno) zona,
    ];
  }

  @override
  Future<ZonaRuta?> obtener(String codigo) async {
    await Future<void>.delayed(_latencia);
    return zonas.where((zona) => zona.codigo == codigo).firstOrNull;
  }
}
