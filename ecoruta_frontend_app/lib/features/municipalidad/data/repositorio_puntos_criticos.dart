import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/app_config.dart';
import '../../../core/network/api_client.dart';
import 'modelos_puntos_criticos.dart';
import 'repositorio_reportes_campo.dart';

abstract interface class RepositorioPuntosCriticos {
  /// Todos los puntos críticos (recorre las páginas del backend), incluido
  /// el contenedor prototipo con sensor.
  Future<List<PuntoCritico>> listarTodos();
  Future<ResumenPuntosCriticos> resumen();
  Future<PuntoCritico?> obtener(String codigo);
}

final repositorioPuntosCriticosProvider = Provider<RepositorioPuntosCriticos>(
  (ref) => AppConfig.usarDatosDeEjemplo
      ? RepositorioPuntosCriticosMock()
      : RepositorioPuntosCriticosApi(ref.read(dioProvider)),
);

/// Puntos críticos contra el backend real. Usa el cliente dio compartido,
/// que ya adjunta el token.
class RepositorioPuntosCriticosApi implements RepositorioPuntosCriticos {
  RepositorioPuntosCriticosApi(this._dio);

  final Dio _dio;

  /// Máximo que acepta el backend en `limit`.
  static const tamanoPagina = 200;

  /// Tope de páginas para no quedar en un bucle si el backend responde mal.
  static const _maximoPaginas = 50;

  @override
  Future<List<PuntoCritico>> listarTodos() async {
    final puntos = <PuntoCritico>[];
    var offset = 0;
    for (var pagina = 0; pagina < _maximoPaginas; pagina++) {
      final respuesta = await _dio.get(
        '/puntos-criticos',
        queryParameters: {
          'limit': tamanoPagina,
          'offset': offset,
          'incluir_prototipo': true,
        },
      );
      final datos = PaginaPuntosCriticos.fromJson(
        respuesta.data as Map<String, dynamic>,
      );
      puntos.addAll(datos.items);
      offset += datos.items.length;
      if (datos.items.isEmpty || offset >= datos.total) break;
    }
    return puntos;
  }

  @override
  Future<ResumenPuntosCriticos> resumen() async {
    final respuesta = await _dio.get('/puntos-criticos/resumen');
    return ResumenPuntosCriticos.fromJson(
      respuesta.data as Map<String, dynamic>,
    );
  }

  @override
  Future<PuntoCritico?> obtener(String codigo) async {
    try {
      final respuesta = await _dio.get(
        '/puntos-criticos/${Uri.encodeComponent(codigo)}',
      );
      return PuntoCritico.fromJson(respuesta.data as Map<String, dynamic>);
    } on DioException catch (error) {
      if (error.response?.statusCode == 404) return null;
      rethrow;
    }
  }
}

/// Datos de ejemplo para USE_MOCK=true. No son puntos reales de Trujillo:
/// los códigos y direcciones dicen "EJEMPLO" a propósito.
class RepositorioPuntosCriticosMock implements RepositorioPuntosCriticos {
  static const _latencia = Duration(milliseconds: 300);

  static const puntos = <PuntoCritico>[
    PuntoCritico(
      id: 1,
      codigo: 'EJEMPLO-01',
      estado: EstadoPuntoCritico.potencial,
      priorizacionObligatoria: true,
      direccion: 'Dirección de ejemplo 1, Trujillo',
      referencia: 'Referencia de ejemplo',
      latitud: -8.1090,
      longitud: -79.0215,
    ),
    PuntoCritico(
      id: 2,
      codigo: 'EJEMPLO-02',
      estado: EstadoPuntoCritico.potencial,
      priorizacionObligatoria: true,
      direccion: 'Dirección de ejemplo 2, Trujillo',
      latitud: -8.1180,
      longitud: -79.0350,
    ),
    PuntoCritico(
      id: 3,
      codigo: 'EJEMPLO-03',
      estado: EstadoPuntoCritico.potencial,
      priorizacionObligatoria: false,
      direccion: 'Dirección de ejemplo 3, Trujillo',
      referencia: 'Referencia de ejemplo',
      latitud: -8.1005,
      longitud: -79.0400,
    ),
    PuntoCritico(
      id: 4,
      codigo: 'EJEMPLO-04',
      estado: EstadoPuntoCritico.potencial,
      priorizacionObligatoria: false,
      direccion: 'Dirección de ejemplo 4, Trujillo',
      latitud: -8.1250,
      longitud: -79.0230,
    ),
    PuntoCritico(
      id: 5,
      codigo: 'EJEMPLO-05',
      estado: EstadoPuntoCritico.recuperado,
      priorizacionObligatoria: false,
      direccion: 'Dirección de ejemplo 5, Trujillo',
      latitud: -8.0960,
      longitud: -79.0300,
    ),
  ];

  /// Contenedor prototipo de ejemplo (con sensor). Va aparte de [puntos]
  /// porque el backend solo lo envía con `?incluir_prototipo=true`.
  static const prototipo = PuntoCritico(
    id: 6,
    codigo: 'EJEMPLO-PROTO',
    estado: EstadoPuntoCritico.potencial,
    priorizacionObligatoria: false,
    direccion: 'Dirección de ejemplo del prototipo, Trujillo',
    latitud: -8.1116,
    longitud: -79.0288,
    esPrototipo: true,
  );

  /// Lo que devuelve el mapa: [puntos] y el [prototipo].
  static const todos = <PuntoCritico>[...puntos, prototipo];

  @override
  Future<List<PuntoCritico>> listarTodos() async {
    await Future<void>.delayed(_latencia);
    // El llenado sale de los reportes de ejemplo (cambia al reportar).
    return [for (final punto in todos) ReportesCampoEjemplo.conLlenado(punto)];
  }

  @override
  Future<ResumenPuntosCriticos> resumen() async {
    await Future<void>.delayed(_latencia);
    return ResumenPuntosCriticos.desdePuntos(puntos);
  }

  @override
  Future<PuntoCritico?> obtener(String codigo) async {
    await Future<void>.delayed(_latencia);
    final punto = todos.where((punto) => punto.codigo == codigo).firstOrNull;
    return punto == null ? null : ReportesCampoEjemplo.conLlenado(punto);
  }
}
