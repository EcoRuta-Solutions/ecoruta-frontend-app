import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/app_config.dart';
import '../../../core/network/api_client.dart';
import 'modelos_ciudadano.dart';

final repositorioCiudadanoProvider = Provider<RepositorioCiudadano>(
  (ref) => AppConfig.usarDatosDeEjemplo
      ? RepositorioCiudadanoMock()
      : RepositorioCiudadanoApi(ref.read(dioProvider)),
);

/// Acceso del ciudadano a sus propios reportes contra el backend real.
abstract interface class RepositorioCiudadano {
  Future<List<ReporteCiudadanoApp>> misReportes();

  Future<void> crearReporte({
    required double latitud,
    required double longitud,
    required String descripcion,
  });
}

class RepositorioCiudadanoApi implements RepositorioCiudadano {
  RepositorioCiudadanoApi(this._dio);

  final Dio _dio;

  @override
  Future<List<ReporteCiudadanoApp>> misReportes() async {
    try {
      final respuesta = await _dio.get(
        '/reportes/mios',
        queryParameters: {'limit': 200},
      );
      return [
        for (final item in (respuesta.data as List))
          _reporteDesdeJson(item as Map<String, dynamic>),
      ];
    } on DioException catch (error) {
      throw _errorCiudadano(error, alternativo: 'No se pudieron cargar tus reportes.');
    }
  }

  @override
  Future<void> crearReporte({
    required double latitud,
    required double longitud,
    required String descripcion,
  }) async {
    try {
      await _dio.post(
        '/reportes',
        data: {
          'latitud': latitud,
          'longitud': longitud,
          'descripcion': descripcion,
        },
      );
    } on DioException catch (error) {
      throw _errorCiudadano(error, alternativo: 'No se pudo enviar el reporte.');
    }
  }
}

ReporteCiudadanoApp _reporteDesdeJson(Map<String, dynamic> j) => ReporteCiudadanoApp(
  id: j['id'] as int,
  descripcion: j['descripcion'] as String,
  latitud: (j['latitud'] as num).toDouble(),
  longitud: (j['longitud'] as num).toDouble(),
  fecha: DateTime.parse(j['timestamp'] as String).toLocal(),
  estado: switch (j['estado']) {
    'en_atencion' => EstadoReporteCiudadano.enAtencion,
    'atendido' => EstadoReporteCiudadano.resuelto,
    _ => EstadoReporteCiudadano.recibido,
  },
  asignadoA: j['asignado_a'] as String?,
);

StateError _errorCiudadano(
  Object error, {
  String alternativo = 'No se pudo completar la acción.',
}) {
  if (error is DioException) {
    final codigo = error.response?.statusCode;
    final detalle = error.response?.data;
    final mensajeBackend = detalle is Map<String, dynamic>
        ? detalle['detail']
        : null;
    if (codigo == 401) return StateError('Tu sesión venció. Inicia sesión nuevamente.');
    if (codigo == 403) return StateError('No tienes permiso para esta acción.');
    if (mensajeBackend != null) return StateError(mensajeBackend.toString());
  }
  return StateError(alternativo);
}

/// Repositorio en memoria para probar el flujo del ciudadano sin backend.
class RepositorioCiudadanoMock implements RepositorioCiudadano {
  RepositorioCiudadanoMock()
      : _reportes = [
          ReporteCiudadanoApp(
            id: 3,
            descripcion: 'Contenedor desbordado frente al mercado.',
            latitud: -8.1116,
            longitud: -79.0288,
            fecha: DateTime.now().subtract(const Duration(minutes: 40)),
            estado: EstadoReporteCiudadano.recibido,
          ),
          ReporteCiudadanoApp(
            id: 2,
            descripcion: 'Basura acumulada en la esquina.',
            latitud: -8.1099,
            longitud: -79.0310,
            fecha: DateTime.now().subtract(const Duration(hours: 5)),
            estado: EstadoReporteCiudadano.enAtencion,
            asignadoA: 'Cuadrilla municipal',
          ),
          ReporteCiudadanoApp(
            id: 1,
            descripcion: 'Contenedor dañado, la tapa está rota.',
            latitud: -8.1110,
            longitud: -79.0279,
            fecha: DateTime.now().subtract(const Duration(days: 2)),
            estado: EstadoReporteCiudadano.resuelto,
            asignadoA: 'Cuadrilla municipal',
          ),
        ];

  // EJEMPLO: reemplazar por API
  final List<ReporteCiudadanoApp> _reportes;
  int _siguienteId = 4;

  @override
  Future<List<ReporteCiudadanoApp>> misReportes() async =>
      List<ReporteCiudadanoApp>.unmodifiable(_reportes);

  @override
  Future<void> crearReporte({
    required double latitud,
    required double longitud,
    required String descripcion,
  }) async {
    _reportes.insert(
      0,
      ReporteCiudadanoApp(
        id: _siguienteId++,
        descripcion: descripcion,
        latitud: latitud,
        longitud: longitud,
        fecha: DateTime.now(),
        estado: EstadoReporteCiudadano.recibido,
      ),
    );
  }
}
