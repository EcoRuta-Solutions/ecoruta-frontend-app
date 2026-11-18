import '../../municipalidad/data/modelos_reportes_campo.dart';

/// Modelos de `RutaOut` / `ParadaOut` del backend (GET /rutas/mias,
/// /rutas/hoy y /rutas/{id}). Los usa el conductor y también la
/// municipalidad para las rutas del día.
///
/// Las rutas generadas por turno traen cada parada con `punto_critico` y
/// `nodo_id`/`nodo` en null; las rutas antiguas pueden traer solo `nodo`.

/// Estado de una ruta tal como lo maneja el backend.
enum EstadoRutaConductor { pendiente, enProceso, completado, cancelado }

EstadoRutaConductor estadoRutaDesde(String? valor) => switch (valor) {
  'en_proceso' => EstadoRutaConductor.enProceso,
  'Completado' => EstadoRutaConductor.completado,
  'Cancelado' => EstadoRutaConductor.cancelado,
  _ => EstadoRutaConductor.pendiente,
};

/// Valor de `RutaEstadoUpdate.estado` para PATCH /rutas/{id}.
String estadoRutaATexto(EstadoRutaConductor estado) => switch (estado) {
  EstadoRutaConductor.pendiente => 'Pendiente',
  EstadoRutaConductor.enProceso => 'en_proceso',
  EstadoRutaConductor.completado => 'Completado',
  EstadoRutaConductor.cancelado => 'Cancelado',
};

String etiquetaEstadoRuta(EstadoRutaConductor estado) => switch (estado) {
  EstadoRutaConductor.pendiente => 'Pendiente',
  EstadoRutaConductor.enProceso => 'En proceso',
  EstadoRutaConductor.completado => 'Completado',
  EstadoRutaConductor.cancelado => 'Cancelado',
};

/// `manana` → `Mañana`. Acepta también textos antiguos como `Mañana`.
String etiquetaTurno(String? turno) => switch (turno?.toLowerCase()) {
  null || '' => 'Sin turno',
  'manana' || 'mañana' => 'Mañana',
  'tarde' => 'Tarde',
  'noche' => 'Noche',
  final otro => otro,
};

double? _decimal(Object? valor) => (valor as num?)?.toDouble();

/// Camión de la ruta (`CamionOut`). Capacidad y turno pueden venir nulos.
class CamionConductor {
  final int id;
  final String placa;
  final int? capacidad;
  final String? turno;

  const CamionConductor({
    required this.id,
    required this.placa,
    this.capacidad,
    this.turno,
  });

  factory CamionConductor.fromJson(Map<String, dynamic> j) => CamionConductor(
    id: (j['id'] as num).toInt(),
    placa: j['placa'] as String,
    capacidad: (j['capacidad'] as num?)?.toInt(),
    turno: j['turno'] as String?,
  );
}

/// Punto crítico de una parada (`PuntoParadaOut`).
class PuntoParada {
  final int id;
  final String codigo;
  final String direccion;
  final String? referencia;
  final double lat;
  final double lon;
  final bool priorizacionObligatoria;

  /// Nivel del último reporte vigente o [NivelLlenado.sinDatos].
  final NivelLlenado estadoLlenado;

  const PuntoParada({
    required this.id,
    required this.codigo,
    required this.direccion,
    required this.lat,
    required this.lon,
    this.referencia,
    this.priorizacionObligatoria = false,
    this.estadoLlenado = NivelLlenado.sinDatos,
  });

  factory PuntoParada.fromJson(Map<String, dynamic> j) {
    final referencia = (j['referencia'] as String?)?.trim();
    return PuntoParada(
      id: (j['id'] as num).toInt(),
      codigo: j['codigo'] as String,
      direccion: (j['direccion'] as String?) ?? '',
      referencia: (referencia == null || referencia.isEmpty)
          ? null
          : referencia,
      lat: (j['lat'] as num).toDouble(),
      lon: (j['lon'] as num).toDouble(),
      priorizacionObligatoria:
          (j['priorizacion_obligatoria'] as bool?) ?? false,
      estadoLlenado: NivelLlenado.desdeApi(j['estado_llenado']),
    );
  }
}

/// Contenedor de una parada de las rutas antiguas (`NodoParadaOut`).
/// Se conserva solo para leer esas rutas; las nuevas no lo traen.
class NodoConductor {
  final int id;
  final String codigo;
  final String nombre;
  final double latitud;
  final double longitud;

  const NodoConductor({
    required this.id,
    required this.codigo,
    required this.nombre,
    required this.latitud,
    required this.longitud,
  });

  factory NodoConductor.fromJson(Map<String, dynamic> j) => NodoConductor(
    id: (j['id'] as num).toInt(),
    codigo: j['codigo'] as String,
    nombre: j['nombre'] as String,
    latitud: (j['latitud'] as num).toDouble(),
    longitud: (j['longitud'] as num).toDouble(),
  );
}

/// Una parada de la ruta (`ParadaOut`).
class ParadaConductor {
  final int id;
  final int rutaId;
  final int orden;
  final bool recolectado;
  final int? puntoCriticoId;
  final PuntoParada? puntoCritico;

  /// Solo en rutas antiguas.
  final int? nodoId;
  final NodoConductor? nodo;

  const ParadaConductor({
    required this.id,
    required this.rutaId,
    required this.orden,
    required this.recolectado,
    this.puntoCriticoId,
    this.puntoCritico,
    this.nodoId,
    this.nodo,
  });

  /// Código del punto (o del contenedor en rutas antiguas).
  String get codigo =>
      puntoCritico?.codigo ?? nodo?.codigo ?? 'Parada $orden';

  /// Dirección del punto (o nombre del contenedor en rutas antiguas).
  String get direccion => puntoCritico?.direccion ?? nodo?.nombre ?? '';

  String get titulo => direccion.isEmpty ? codigo : '$codigo · $direccion';

  double? get latitud => puntoCritico?.lat ?? nodo?.latitud;
  double? get longitud => puntoCritico?.lon ?? nodo?.longitud;
  bool get tieneUbicacion => latitud != null && longitud != null;

  /// Sin punto crítico (rutas antiguas) no se sabe el llenado.
  NivelLlenado get estadoLlenado =>
      puntoCritico?.estadoLlenado ?? NivelLlenado.sinDatos;

  factory ParadaConductor.fromJson(Map<String, dynamic> j) {
    final punto = j['punto_critico'];
    final nodo = j['nodo'];
    return ParadaConductor(
      id: (j['id'] as num).toInt(),
      rutaId: (j['ruta_id'] as num).toInt(),
      orden: (j['orden'] as num).toInt(),
      recolectado: (j['recolectado'] as bool?) ?? false,
      puntoCriticoId: (j['punto_critico_id'] as num?)?.toInt(),
      puntoCritico: punto is Map<String, dynamic>
          ? PuntoParada.fromJson(punto)
          : null,
      nodoId: (j['nodo_id'] as num?)?.toInt(),
      nodo: nodo is Map<String, dynamic> ? NodoConductor.fromJson(nodo) : null,
    );
  }

  ParadaConductor copiar({bool? recolectado}) => ParadaConductor(
    id: id,
    rutaId: rutaId,
    orden: orden,
    recolectado: recolectado ?? this.recolectado,
    puntoCriticoId: puntoCriticoId,
    puntoCritico: puntoCritico,
    nodoId: nodoId,
    nodo: nodo,
  );
}

/// Ruta (`RutaOut`).
class RutaConductor {
  final int id;
  final DateTime fechaInicio;
  final DateTime fechaFin;
  final DateTime horaInicio;
  final DateTime horaFin;
  final int camionId;
  final int? conductorId;
  final EstadoRutaConductor estado;
  final String? turno;
  final double? distanciaKm;
  final double? tiempoEstimadoMin;
  final String? metodoDistancia;
  final CamionConductor? camion;

  /// Ordenadas por `orden`.
  final List<ParadaConductor> paradas;

  const RutaConductor({
    required this.id,
    required this.fechaInicio,
    required this.fechaFin,
    required this.horaInicio,
    required this.horaFin,
    required this.camionId,
    required this.conductorId,
    required this.estado,
    required this.camion,
    required this.paradas,
    this.turno,
    this.distanciaKm,
    this.tiempoEstimadoMin,
    this.metodoDistancia,
  });

  int get paradasTotal => paradas.length;

  int get paradasHechas => paradas.where((p) => p.recolectado).length;

  double get progreso => paradasTotal == 0 ? 0 : paradasHechas / paradasTotal;

  /// Turno de la ruta; en rutas antiguas, el del camión.
  String get turnoTexto => etiquetaTurno(turno ?? camion?.turno);

  /// La ruta abarca [dia] (se comparan solo las fechas).
  bool esDelDia(DateTime dia) {
    final d = DateTime(dia.year, dia.month, dia.day);
    final inicio = DateTime(
      fechaInicio.year,
      fechaInicio.month,
      fechaInicio.day,
    );
    final fin = DateTime(fechaFin.year, fechaFin.month, fechaFin.day);
    return !d.isBefore(inicio) && !d.isAfter(fin);
  }

  factory RutaConductor.fromJson(Map<String, dynamic> j) {
    final paradas =
        (j['paradas'] as List? ?? const [])
            .map((e) => ParadaConductor.fromJson(e as Map<String, dynamic>))
            .toList()
          ..sort((a, b) => a.orden.compareTo(b.orden));

    return RutaConductor(
      id: (j['id'] as num).toInt(),
      fechaInicio: DateTime.parse(j['fecha_inicio'] as String),
      fechaFin: DateTime.parse(j['fecha_fin'] as String),
      horaInicio: DateTime.parse(j['hora_inicio'] as String).toLocal(),
      horaFin: DateTime.parse(j['hora_fin'] as String).toLocal(),
      camionId: (j['camion_id'] as num).toInt(),
      conductorId: (j['conductor_id'] as num?)?.toInt(),
      estado: estadoRutaDesde(j['estado'] as String?),
      turno: j['turno'] as String?,
      distanciaKm: _decimal(j['distancia_km']),
      tiempoEstimadoMin: _decimal(j['tiempo_estimado_min']),
      metodoDistancia: j['metodo_distancia'] as String?,
      camion: j['camion'] is Map<String, dynamic>
          ? CamionConductor.fromJson(j['camion'] as Map<String, dynamic>)
          : null,
      paradas: paradas,
    );
  }

  RutaConductor copiar({
    EstadoRutaConductor? estado,
    List<ParadaConductor>? paradas,
  }) => RutaConductor(
    id: id,
    fechaInicio: fechaInicio,
    fechaFin: fechaFin,
    horaInicio: horaInicio,
    horaFin: horaFin,
    camionId: camionId,
    conductorId: conductorId,
    estado: estado ?? this.estado,
    turno: turno,
    distanciaKm: distanciaKm,
    tiempoEstimadoMin: tiempoEstimadoMin,
    metodoDistancia: metodoDistancia,
    camion: camion,
    paradas: paradas ?? this.paradas,
  );
}

/// Elige la ruta a mostrar: primero la que está en proceso, luego una
/// pendiente; si no hay, la primera.
RutaConductor? rutaActivaDe(List<RutaConductor> rutas) {
  if (rutas.isEmpty) return null;
  for (final ruta in rutas) {
    if (ruta.estado == EstadoRutaConductor.enProceso) return ruta;
  }
  for (final ruta in rutas) {
    if (ruta.estado == EstadoRutaConductor.pendiente) return ruta;
  }
  return rutas.first;
}

/// Ruta de [hoy] para "Mi ruta"; null si no hay ninguna asignada ese día.
RutaConductor? rutaDeHoy(List<RutaConductor> rutas, DateTime hoy) =>
    rutaActivaDe([
      for (final ruta in rutas)
        if (ruta.esDelDia(hoy)) ruta,
    ]);

/// `metodo_distancia` cuando las distancias son en línea recta corregida.
const metodoDistanciaAproximada = 'haversine_aprox';
