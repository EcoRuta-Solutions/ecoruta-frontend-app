import 'dart:math' as math;

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/app_config.dart';
import '../../../core/network/api_client.dart';
import 'modelos_puntos_criticos.dart';
import 'modelos_reportes_campo.dart';
import 'repositorio_puntos_criticos.dart';

abstract interface class RepositorioReportesCampo {
  /// POST /reportes-campo. Lanza [DioException] con 404 si el punto no
  /// existe y 422 si los datos no son válidos.
  Future<ReporteCampo> crear(NuevoReporteCampo reporte);

  /// GET /puntos-criticos/{codigo}/ultimo-reporte.
  Future<UltimoReportePunto> ultimoReporte(String codigo);

  /// GET /reportes-campo/resumen.
  Future<ResumenReportes> resumen();
}

final repositorioReportesCampoProvider = Provider<RepositorioReportesCampo>(
  (ref) => AppConfig.usarDatosDeEjemplo
      ? RepositorioReportesCampoMock()
      : RepositorioReportesCampoApi(ref.read(dioProvider)),
);

/// Reportes de campo contra el backend real. Usa el cliente dio
/// compartido, que ya adjunta el token (el usuario sale del token).
class RepositorioReportesCampoApi implements RepositorioReportesCampo {
  RepositorioReportesCampoApi(this._dio);

  final Dio _dio;

  @override
  Future<ReporteCampo> crear(NuevoReporteCampo reporte) async {
    final respuesta = await _dio.post(
      '/reportes-campo',
      data: reporte.toJson(),
    );
    return ReporteCampo.fromJson(respuesta.data as Map<String, dynamic>);
  }

  @override
  Future<UltimoReportePunto> ultimoReporte(String codigo) async {
    final respuesta = await _dio.get(
      '/puntos-criticos/${Uri.encodeComponent(codigo)}/ultimo-reporte',
    );
    return UltimoReportePunto.fromJson(respuesta.data as Map<String, dynamic>);
  }

  @override
  Future<ResumenReportes> resumen() async {
    final respuesta = await _dio.get('/reportes-campo/resumen');
    return ResumenReportes.fromJson(respuesta.data as Map<String, dynamic>);
  }
}

/// Datos de ejemplo para USE_MOCK=true, sobre los puntos "EJEMPLO-0X" de
/// [RepositorioPuntosCriticosMock]. Las pantallas muestran el aviso
/// "Datos de ejemplo". Sigue las reglas del backend: 24 h de vigencia y
/// aviso a más de 150 m.
class RepositorioReportesCampoMock implements RepositorioReportesCampo {
  static const _latencia = Duration(milliseconds: 300);

  @override
  Future<ReporteCampo> crear(NuevoReporteCampo reporte) async {
    await Future<void>.delayed(_latencia);
    final punto = RepositorioPuntosCriticosMock.puntos
        .where((punto) => punto.codigo == reporte.codigoPunto)
        .firstOrNull;
    if (punto == null) {
      final pedido = RequestOptions(path: '/reportes-campo');
      throw DioException(
        requestOptions: pedido,
        response: Response(
          requestOptions: pedido,
          statusCode: 404,
          data: {'detail': 'Punto crítico no encontrado'},
        ),
        type: DioExceptionType.badResponse,
      );
    }
    return ReportesCampoEjemplo.agregar(reporte, punto);
  }

  @override
  Future<UltimoReportePunto> ultimoReporte(String codigo) async {
    await Future<void>.delayed(_latencia);
    return ReportesCampoEjemplo.ultimoDe(codigo);
  }

  @override
  Future<ResumenReportes> resumen() async {
    await Future<void>.delayed(_latencia);
    final conteo = {for (final nivel in NivelLlenado.values) nivel: 0};
    for (final punto in RepositorioPuntosCriticosMock.puntos) {
      final nivel = ReportesCampoEjemplo.ultimoDe(punto.codigo).estadoLlenado;
      conteo[nivel] = conteo[nivel]! + 1;
    }
    return ResumenReportes(
      totalPuntos: RepositorioPuntosCriticosMock.puntos.length,
      vigenciaHoras: ReportesCampoEjemplo.vigenciaHoras,
      porEstado: {
        for (final nivel in NivelLlenado.reportables) nivel: conteo[nivel]!,
      },
      sinDatos: conteo[NivelLlenado.sinDatos]!,
    );
  }
}

/// Reportes de ejemplo en memoria, compartidos con el mock de puntos para
/// que el mapa de ejemplo cambie al reportar.
class ReportesCampoEjemplo {
  ReportesCampoEjemplo._();

  static const vigenciaHoras = 24.0;
  static const distanciaMaximaM = 150.0;

  static List<ReporteCampo>? _reportes;

  static List<ReporteCampo> get _lista => _reportes ??= _iniciales();

  /// Un reporte vigente de cada nivel y uno vencido (que se ve como
  /// "Sin datos"). El resto de puntos no tiene reportes.
  static List<ReporteCampo> _iniciales() {
    final ahora = DateTime.now();
    ReporteCampo ejemplo(int id, int punto, NivelLlenado estado, int horas) =>
        ReporteCampo(
          id: id,
          puntoCriticoId: punto,
          codigoPunto: 'EJEMPLO-0$punto',
          usuarioId: 0,
          usuarioNombre: 'Usuario de ejemplo',
          estado: estado,
          observacion: 'Observación de ejemplo',
          creadoEn: ahora.subtract(Duration(hours: horas)),
          esDemo: false,
        );
    return [
      ejemplo(1, 1, NivelLlenado.desbordado, 2),
      ejemplo(2, 2, NivelLlenado.lleno, 5),
      ejemplo(3, 3, NivelLlenado.vacio, 30),
    ];
  }

  /// Vuelve al estado inicial (para los tests).
  static void reiniciar() => _reportes = null;

  static ReporteCampo agregar(NuevoReporteCampo nuevo, PuntoCritico punto) {
    final lat = nuevo.lat;
    final lon = nuevo.lon;
    final distancia =
        lat != null && lon != null && punto.tieneCoordenadas
        ? distanciaMetros(lat, lon, punto.latitud!, punto.longitud!)
        : null;
    final reporte = ReporteCampo(
      id: _lista.length + 1,
      puntoCriticoId: punto.id ?? 0,
      codigoPunto: punto.codigo,
      usuarioId: 0,
      usuarioNombre: 'Usuario de ejemplo',
      estado: nuevo.estado,
      observacion: nuevo.observacion,
      lat: lat,
      lon: lon,
      distanciaM: distancia,
      lejosDelPunto: distancia != null && distancia > distanciaMaximaM,
      creadoEn: DateTime.now(),
    );
    _lista.add(reporte);
    return reporte;
  }

  static UltimoReportePunto ultimoDe(String codigo, {DateTime? ahora}) {
    // Como el backend: más reciente primero y, si empatan, el de mayor id.
    final delPunto = _lista.where((r) => r.codigoPunto == codigo).toList()
      ..sort((a, b) {
        final porFecha = b.creadoEn.compareTo(a.creadoEn);
        return porFecha != 0 ? porFecha : b.id.compareTo(a.id);
      });
    final ultimo = delPunto.firstOrNull;
    final momento = ahora ?? DateTime.now();
    final vigente =
        ultimo != null &&
        momento.difference(ultimo.creadoEn) <
            Duration(minutes: (vigenciaHoras * 60).round());
    return UltimoReportePunto(
      codigo: codigo,
      reporteVigente: vigente,
      estadoLlenado: vigente ? ultimo.estado : NivelLlenado.sinDatos,
      vigenciaHoras: vigenciaHoras,
      reporte: ultimo,
    );
  }

  /// Aplica el último reporte de ejemplo a un punto del mock.
  static PuntoCritico conLlenado(PuntoCritico punto) {
    final ultimo = ultimoDe(punto.codigo);
    final reporte = ultimo.reporte;
    return punto.conLlenado(
      estadoLlenado: ultimo.estadoLlenado,
      reporteVigente: ultimo.reporteVigente,
      ultimoReporte: reporte == null
          ? null
          : UltimoReporteBreve(
              estado: reporte.estado,
              creadoEn: reporte.creadoEn,
            ),
    );
  }
}

/// Distancia en metros entre dos coordenadas (fórmula del haversine).
double distanciaMetros(double lat1, double lon1, double lat2, double lon2) {
  const radioTierra = 6371000.0;
  double rad(double grados) => grados * math.pi / 180;
  final dLat = rad(lat2 - lat1);
  final dLon = rad(lon2 - lon1);
  final a =
      math.pow(math.sin(dLat / 2), 2) +
      math.cos(rad(lat1)) * math.cos(rad(lat2)) * math.pow(math.sin(dLon / 2), 2);
  return 2 * radioTierra * math.asin(math.sqrt(a));
}
