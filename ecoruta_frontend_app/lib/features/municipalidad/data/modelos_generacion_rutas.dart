/// Modelos de POST /rutas/generar (rutas de todo un turno con los puntos
/// críticos y la flota real). Los nombres siguen `RutaGenerarRequest`,
/// `RutasTurnoOut`, `ParametrosGeneracionOut`, `RutaGeneradaOut`,
/// `CamionRutaOut` y `ParadaGeneradaOut` del OpenAPI del backend.
library;

import '../../conductor/data/modelos_conductor.dart';
import 'modelos_zonas_ruta.dart';

double _decimal(Object? valor) => (valor as num?)?.toDouble() ?? 0;

String _fechaIso(DateTime fecha) =>
    '${fecha.year.toString().padLeft(4, '0')}-'
    '${fecha.month.toString().padLeft(2, '0')}-'
    '${fecha.day.toString().padLeft(2, '0')}';

/// Cuerpo de POST /rutas/generar.
class SolicitudGenerarRutas {
  const SolicitudGenerarRutas({
    required this.turno,
    this.fecha,
    this.soloPrioritarios = false,
    this.soloConReporteLleno = false,
    this.incluirReserva = false,
    this.maxParadasPorRuta,
  });

  final TurnoZona turno;

  /// Sin fecha, el backend usa la de hoy.
  final DateTime? fecha;
  final bool soloPrioritarios;
  final bool soloConReporteLleno;
  final bool incluirReserva;
  final int? maxParadasPorRuta;

  Map<String, dynamic> toJson() => {
    'turno': turno.valorApi,
    if (fecha != null) 'fecha': _fechaIso(fecha!),
    'solo_prioritarios': soloPrioritarios,
    'solo_con_reporte_lleno': soloConReporteLleno,
    'incluir_reserva': incluirReserva,
    'max_paradas_por_ruta': maxParadasPorRuta,
  };
}

/// `parametros` de la respuesta: supuestos del cálculo.
class ParametrosGeneracion {
  const ParametrosGeneracion({
    required this.velocidadMediaKmh,
    required this.minutosPorParada,
    required this.factorCircuito,
    required this.capacidadCamionUsada,
    required this.provisionales,
    required this.notas,
  });

  final double velocidadMediaKmh;
  final double minutosPorParada;
  final double? factorCircuito;
  final bool capacidadCamionUsada;

  /// Nombres de los parámetros que aún no son definitivos.
  final List<String> provisionales;
  final List<String> notas;

  factory ParametrosGeneracion.fromJson(Map<String, dynamic> j) =>
      ParametrosGeneracion(
        velocidadMediaKmh: _decimal(j['velocidad_media_kmh']),
        minutosPorParada: _decimal(j['minutos_por_parada']),
        factorCircuito: (j['factor_circuito'] as num?)?.toDouble(),
        capacidadCamionUsada: (j['capacidad_camion_usada'] as bool?) ?? false,
        provisionales: [
          for (final p in (j['provisionales'] as List? ?? const [])) '$p',
        ],
        notas: [for (final n in (j['notas'] as List? ?? const [])) '$n'],
      );
}

/// Parada de una ruta generada (`ParadaGeneradaOut`).
class ParadaGenerada {
  const ParadaGenerada({
    required this.orden,
    required this.puntoCriticoId,
    required this.codigo,
    required this.lat,
    required this.lon,
    required this.direccion,
  });

  final int orden;
  final int puntoCriticoId;
  final String codigo;
  final double lat;
  final double lon;
  final String direccion;

  factory ParadaGenerada.fromJson(Map<String, dynamic> j) => ParadaGenerada(
    orden: (j['orden'] as num).toInt(),
    puntoCriticoId: (j['punto_critico_id'] as num).toInt(),
    codigo: j['codigo'] as String,
    lat: (j['lat'] as num).toDouble(),
    lon: (j['lon'] as num).toDouble(),
    direccion: (j['direccion'] as String?) ?? '',
  );
}

/// Ruta de un camión (`RutaGeneradaOut`).
class RutaGenerada {
  const RutaGenerada({
    required this.rutaId,
    required this.camionId,
    required this.placa,
    required this.conductorId,
    required this.horaInicio,
    required this.horaFin,
    required this.excedeTurno,
    required this.distanciaKm,
    required this.tiempoEstimadoMin,
    required this.paradas,
  });

  final int rutaId;
  final int camionId;
  final String placa;
  final int? conductorId;
  final DateTime horaInicio;
  final DateTime horaFin;

  /// La ruta termina después del fin del turno.
  final bool excedeTurno;
  final double distanciaKm;
  final double tiempoEstimadoMin;

  /// Ordenadas por `orden`.
  final List<ParadaGenerada> paradas;

  factory RutaGenerada.fromJson(Map<String, dynamic> j) {
    final camion = j['camion'] as Map<String, dynamic>;
    return RutaGenerada(
      rutaId: (j['ruta_id'] as num).toInt(),
      camionId: (camion['id'] as num).toInt(),
      placa: camion['placa'] as String,
      conductorId: (j['conductor_id'] as num?)?.toInt(),
      horaInicio: DateTime.parse(j['hora_inicio'] as String).toLocal(),
      horaFin: DateTime.parse(j['hora_fin'] as String).toLocal(),
      excedeTurno: (j['excede_turno'] as bool?) ?? false,
      distanciaKm: _decimal(j['distancia_km']),
      tiempoEstimadoMin: _decimal(j['tiempo_estimado_min']),
      paradas: [
        for (final p in (j['paradas'] as List? ?? const []))
          ParadaGenerada.fromJson(p as Map<String, dynamic>),
      ]..sort((a, b) => a.orden.compareTo(b.orden)),
    );
  }
}

/// Respuesta 201 de POST /rutas/generar (`RutasTurnoOut`).
class ResultadoGeneracionRutas {
  const ResultadoGeneracionRutas({
    required this.turno,
    required this.fecha,
    required this.nroCamiones,
    required this.nroPuntos,
    required this.maxParadasPorRuta,
    required this.metodoDistancia,
    required this.distanciaTotalKm,
    required this.tiempoTotalMin,
    required this.rutasReemplazadas,
    required this.camionesConRutaEnCurso,
    required this.parametros,
    required this.rutas,
  });

  final TurnoZona turno;
  final DateTime fecha;
  final int nroCamiones;
  final int nroPuntos;
  final int maxParadasPorRuta;
  final String metodoDistancia;
  final double distanciaTotalKm;
  final double tiempoTotalMin;

  /// Rutas pendientes del mismo turno y fecha que se reemplazaron.
  final int rutasReemplazadas;

  /// Placas de los camiones que se dejaron fuera por tener ruta en curso.
  final List<String> camionesConRutaEnCurso;
  final ParametrosGeneracion parametros;
  final List<RutaGenerada> rutas;

  /// Distancias en línea recta corregida, no por calles.
  bool get distanciasAproximadas =>
      metodoDistancia == metodoDistanciaAproximada;

  factory ResultadoGeneracionRutas.fromJson(Map<String, dynamic> j) =>
      ResultadoGeneracionRutas(
        turno: TurnoZona.desdeApi(j['turno'] as String),
        fecha: DateTime.parse(j['fecha'] as String),
        nroCamiones: (j['nro_camiones'] as num).toInt(),
        nroPuntos: (j['nro_puntos'] as num).toInt(),
        maxParadasPorRuta: (j['max_paradas_por_ruta'] as num).toInt(),
        metodoDistancia: (j['metodo_distancia'] as String?) ?? '',
        distanciaTotalKm: _decimal(j['distancia_total_km']),
        tiempoTotalMin: _decimal(j['tiempo_total_min']),
        rutasReemplazadas: (j['rutas_reemplazadas'] as num?)?.toInt() ?? 0,
        camionesConRutaEnCurso: [
          for (final c in (j['camiones_con_ruta_en_curso'] as List? ?? const []))
            '$c',
        ],
        parametros: ParametrosGeneracion.fromJson(
          j['parametros'] as Map<String, dynamic>,
        ),
        rutas: [
          for (final r in (j['rutas'] as List? ?? const []))
            RutaGenerada.fromJson(r as Map<String, dynamic>),
        ],
      );
}

/// Error de POST /rutas/generar con un mensaje claro para la pantalla.
class ErrorGeneracionRutas implements Exception {
  const ErrorGeneracionRutas(this.mensaje, {this.codigo, this.detalle});

  final String mensaje;
  final int? codigo;

  /// Explicación del backend (`detail`), si la envió como texto.
  final String? detalle;

  @override
  String toString() => detalle == null ? mensaje : '$mensaje ($detalle)';
}

/// `1 h 35 min` o `45 min`.
String duracionTexto(double minutos) {
  final total = minutos.round();
  if (total < 60) return '$total min';
  final horas = total ~/ 60;
  final resto = total % 60;
  return resto == 0 ? '$horas h' : '$horas h $resto min';
}

/// `05:30` en hora local.
String horaTexto(DateTime fecha) =>
    '${fecha.hour.toString().padLeft(2, '0')}:'
    '${fecha.minute.toString().padLeft(2, '0')}';
