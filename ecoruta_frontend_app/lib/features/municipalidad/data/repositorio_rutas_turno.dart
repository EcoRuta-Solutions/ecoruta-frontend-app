import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/app_config.dart';
import '../../../core/network/api_client.dart';
import '../../conductor/data/modelos_conductor.dart';
import 'modelos_generacion_rutas.dart';
import 'modelos_puntos_criticos.dart';
import 'modelos_reportes_campo.dart';
import 'modelos_zonas_ruta.dart';
import 'repositorio_puntos_criticos.dart';
import 'repositorio_reportes_campo.dart';

/// Rutas de recolección de la municipalidad: generar las de un turno y ver
/// las del día.
abstract interface class RepositorioRutasTurno {
  /// POST /rutas/generar. Lanza [ErrorGeneracionRutas] con el motivo.
  Future<ResultadoGeneracionRutas> generar(SolicitudGenerarRutas solicitud);

  /// GET /rutas/hoy (la municipalidad ve todas).
  Future<List<RutaConductor>> rutasDeHoy();
}

final repositorioRutasTurnoProvider = Provider<RepositorioRutasTurno>(
  (ref) => AppConfig.usarDatosDeEjemplo
      ? RepositorioRutasTurnoMock()
      : RepositorioRutasTurnoApi(ref.read(dioProvider)),
);

class RepositorioRutasTurnoApi implements RepositorioRutasTurno {
  RepositorioRutasTurnoApi(this._dio);

  final Dio _dio;

  @override
  Future<ResultadoGeneracionRutas> generar(
    SolicitudGenerarRutas solicitud,
  ) async {
    try {
      final respuesta = await _dio.post(
        '/rutas/generar',
        data: solicitud.toJson(),
      );
      return ResultadoGeneracionRutas.fromJson(
        respuesta.data as Map<String, dynamic>,
      );
    } on DioException catch (error) {
      throw errorGeneracionDesde(error);
    }
  }

  @override
  Future<List<RutaConductor>> rutasDeHoy() async {
    final respuesta = await _dio.get('/rutas/hoy');
    return [
      for (final item in respuesta.data as List)
        RutaConductor.fromJson(item as Map<String, dynamic>),
    ];
  }
}

/// Traduce la respuesta de error de POST /rutas/generar.
ErrorGeneracionRutas errorGeneracionDesde(DioException error) {
  final codigo = error.response?.statusCode;
  final datos = error.response?.data;
  // `detail` es texto en 404/409/422 del generador; en 422 de validación
  // es una lista, que no se muestra tal cual.
  final detalle = datos is Map && datos['detail'] is String
      ? datos['detail'] as String
      : null;
  final mensaje = switch (codigo) {
    null => 'No se pudo conectar con el servidor. Revisa tu conexión.',
    409 =>
      'No hay camiones disponibles en ese turno: no hay camiones operativos '
          'o todos ya tienen una ruta en curso.',
    404 => 'Ningún punto crítico cumple los filtros elegidos.',
    422 =>
      'Los datos no son válidos: revisa el turno o el máximo de paradas '
          'por ruta.',
    401 || 403 => 'Solo la municipalidad puede generar rutas.',
    _ => 'El servidor respondió con un error ($codigo).',
  };
  return ErrorGeneracionRutas(mensaje, codigo: codigo, detalle: detalle);
}

/// Generación de ejemplo para USE_MOCK=true, sobre los puntos "EJEMPLO-0X".
/// Las placas dicen "EJEMPLO" y la pantalla muestra "Datos de ejemplo".
class RepositorioRutasTurnoMock implements RepositorioRutasTurno {
  static const _latencia = Duration(milliseconds: 400);

  /// Inicio de cada turno según los horarios de SEGAT.
  static const _horaTurno = {
    TurnoZona.manana: 5,
    TurnoZona.tarde: 13,
    TurnoZona.noche: 21,
  };

  static const _velocidadKmh = 20.0;
  static const _minutosPorParada = 5.0;
  static const _horasTurno = 8;

  final List<RutaConductor> _rutasHoy = [];

  @override
  Future<ResultadoGeneracionRutas> generar(
    SolicitudGenerarRutas solicitud,
  ) async {
    await Future<void>.delayed(_latencia);
    final hoy = DateTime.now();
    final fecha = solicitud.fecha ?? DateTime(hoy.year, hoy.month, hoy.day);

    final puntos = [
      for (final punto in RepositorioPuntosCriticosMock.puntos)
        if (punto.tieneCoordenadas &&
            (!solicitud.soloPrioritarios || punto.priorizacionObligatoria) &&
            (!solicitud.soloConReporteLleno || _reportadoLleno(punto)))
          punto,
    ];
    if (puntos.isEmpty) {
      throw const ErrorGeneracionRutas(
        'Ningún punto crítico cumple los filtros elegidos.',
        codigo: 404,
        detalle: 'No hay puntos críticos que cumplan los filtros',
      );
    }

    final placas = [
      'EJEMPLO-1',
      'EJEMPLO-2',
      if (solicitud.incluirReserva) 'EJEMPLO-R',
    ];
    final camiones = placas.length.clamp(1, puntos.length);
    final minimo = (puntos.length / camiones).ceil();
    final maximo = solicitud.maxParadasPorRuta ?? minimo;
    if (maximo < minimo) {
      throw ErrorGeneracionRutas(
        'Los datos no son válidos: revisa el turno o el máximo de paradas '
        'por ruta.',
        codigo: 422,
        detalle: 'max_paradas_por_ruta debe ser al menos $minimo',
      );
    }

    final inicio = fecha.add(Duration(hours: _horaTurno[solicitud.turno]!));
    final rutas = <RutaGenerada>[];
    for (var c = 0; c < camiones; c++) {
      final asignados = puntos.skip(c * maximo).take(maximo).toList();
      if (asignados.isEmpty) continue;
      var km = 0.0;
      for (var i = 1; i < asignados.length; i++) {
        km +=
            distanciaMetros(
              asignados[i - 1].latitud!,
              asignados[i - 1].longitud!,
              asignados[i].latitud!,
              asignados[i].longitud!,
            ) /
            1000;
      }
      final minutos =
          km / _velocidadKmh * 60 + asignados.length * _minutosPorParada;
      final fin = inicio.add(Duration(minutes: minutos.round()));
      rutas.add(
        RutaGenerada(
          rutaId: 900 + c,
          camionId: c + 1,
          placa: placas[c],
          conductorId: null,
          horaInicio: inicio,
          horaFin: fin,
          excedeTurno: fin.isAfter(inicio.add(const Duration(hours: _horasTurno))),
          distanciaKm: double.parse(km.toStringAsFixed(2)),
          tiempoEstimadoMin: minutos.roundToDouble(),
          paradas: [
            for (var i = 0; i < asignados.length; i++)
              ParadaGenerada(
                orden: i + 1,
                puntoCriticoId: asignados[i].id ?? 0,
                codigo: asignados[i].codigo,
                lat: asignados[i].latitud!,
                lon: asignados[i].longitud!,
                direccion: asignados[i].direccion,
              ),
          ],
        ),
      );
    }

    final reemplazadas = _rutasHoy
        .where((ruta) => ruta.turno == solicitud.turno.valorApi)
        .length;
    _rutasHoy
      ..removeWhere((ruta) => ruta.turno == solicitud.turno.valorApi)
      ..addAll([
        for (final ruta in rutas) _rutaDelDia(ruta, solicitud.turno, fecha),
      ]);

    return ResultadoGeneracionRutas(
      turno: solicitud.turno,
      fecha: fecha,
      nroCamiones: rutas.length,
      nroPuntos: puntos.length,
      maxParadasPorRuta: maximo,
      metodoDistancia: metodoDistanciaAproximada,
      distanciaTotalKm: rutas.fold(0.0, (suma, r) => suma + r.distanciaKm),
      tiempoTotalMin: rutas.fold(0.0, (suma, r) => suma + r.tiempoEstimadoMin),
      rutasReemplazadas: reemplazadas,
      camionesConRutaEnCurso: const [],
      parametros: const ParametrosGeneracion(
        velocidadMediaKmh: _velocidadKmh,
        minutosPorParada: _minutosPorParada,
        factorCircuito: null,
        capacidadCamionUsada: false,
        provisionales: ['velocidad_media_kmh', 'minutos_por_parada'],
        notas: ['Datos de ejemplo: no son rutas reales de SEGAT.'],
      ),
      rutas: rutas,
    );
  }

  @override
  Future<List<RutaConductor>> rutasDeHoy() async {
    await Future<void>.delayed(_latencia);
    return List.unmodifiable(_rutasHoy);
  }

  static bool _reportadoLleno(PuntoCritico punto) {
    final nivel = ReportesCampoEjemplo.ultimoDe(punto.codigo).estadoLlenado;
    return nivel == NivelLlenado.lleno || nivel == NivelLlenado.desbordado;
  }

  static RutaConductor _rutaDelDia(
    RutaGenerada ruta,
    TurnoZona turno,
    DateTime fecha,
  ) {
    final puntos = {
      for (final punto in RepositorioPuntosCriticosMock.puntos)
        punto.codigo: punto,
    };
    return RutaConductor(
      id: ruta.rutaId,
      fechaInicio: fecha,
      fechaFin: ruta.horaFin,
      horaInicio: ruta.horaInicio,
      horaFin: ruta.horaFin,
      camionId: ruta.camionId,
      conductorId: null,
      estado: EstadoRutaConductor.pendiente,
      turno: turno.valorApi,
      distanciaKm: ruta.distanciaKm,
      tiempoEstimadoMin: ruta.tiempoEstimadoMin,
      metodoDistancia: metodoDistanciaAproximada,
      camion: CamionConductor(
        id: ruta.camionId,
        placa: ruta.placa,
        turno: turno.valorApi,
      ),
      paradas: [
        for (final parada in ruta.paradas)
          ParadaConductor(
            id: ruta.rutaId * 100 + parada.orden,
            rutaId: ruta.rutaId,
            orden: parada.orden,
            recolectado: false,
            puntoCriticoId: parada.puntoCriticoId,
            puntoCritico: PuntoParada(
              id: parada.puntoCriticoId,
              codigo: parada.codigo,
              direccion: parada.direccion,
              referencia: puntos[parada.codigo]?.referencia,
              lat: parada.lat,
              lon: parada.lon,
              priorizacionObligatoria:
                  puntos[parada.codigo]?.priorizacionObligatoria ?? false,
              estadoLlenado: ReportesCampoEjemplo.ultimoDe(
                parada.codigo,
              ).estadoLlenado,
            ),
          ),
      ],
    );
  }
}
