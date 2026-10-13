/// Estado de una ruta tal como lo maneja el backend.
enum EstadoRutaConductor { pendiente, enProceso, completado, cancelado }

EstadoRutaConductor estadoRutaDesde(String? valor) => switch (valor) {
  'en_proceso' => EstadoRutaConductor.enProceso,
  'Completado' => EstadoRutaConductor.completado,
  'Cancelado' => EstadoRutaConductor.cancelado,
  _ => EstadoRutaConductor.pendiente,
};

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

/// Camión asignado a una ruta (GET /rutas/mias).
class CamionConductor {
  final int id;
  final String placa;
  final int capacidad;
  final String turno;

  const CamionConductor({
    required this.id,
    required this.placa,
    required this.capacidad,
    required this.turno,
  });

  factory CamionConductor.fromJson(Map<String, dynamic> j) => CamionConductor(
    id: j['id'] as int,
    placa: j['placa'] as String,
    capacidad: (j['capacidad'] as num).toInt(),
    turno: j['turno'] as String,
  );
}

/// Contenedor al que apunta una parada (incluido en ParadaOut).
class NodoConductor {
  final int id;
  final String codigo;
  final String nombre;
  final double latitud;
  final double longitud;
  final int umbralCritico;
  final double? llenado;
  final String? prioridad;

  const NodoConductor({
    required this.id,
    required this.codigo,
    required this.nombre,
    required this.latitud,
    required this.longitud,
    required this.umbralCritico,
    this.llenado,
    this.prioridad,
  });

  factory NodoConductor.fromJson(Map<String, dynamic> j) => NodoConductor(
    id: j['id'] as int,
    codigo: j['codigo'] as String,
    nombre: j['nombre'] as String,
    latitud: (j['latitud'] as num).toDouble(),
    longitud: (j['longitud'] as num).toDouble(),
    umbralCritico: (j['umbral_critico'] as num).toInt(),
    llenado: (j['llenado'] as num?)?.toDouble(),
    prioridad: j['prioridad'] as String?,
  );
}

/// Una parada dentro de la ruta del conductor.
class ParadaConductor {
  final int id;
  final int rutaId;
  final int nodoId;
  final int orden;
  final bool recolectado;
  // El backend aún no envía la hora estimada en las paradas.
  final DateTime? horaEstimada;
  final NodoConductor? nodo;

  const ParadaConductor({
    required this.id,
    required this.rutaId,
    required this.nodoId,
    required this.orden,
    required this.recolectado,
    this.horaEstimada,
    this.nodo,
  });

  String get titulo => nodo == null
      ? 'Contenedor #$nodoId'
      : '${nodo!.nombre} (${nodo!.codigo})';

  factory ParadaConductor.fromJson(Map<String, dynamic> j) => ParadaConductor(
    id: j['id'] as int,
    rutaId: j['ruta_id'] as int,
    nodoId: j['nodo_id'] as int,
    orden: j['orden'] as int,
    recolectado: j['recolectado'] as bool? ?? false,
    horaEstimada: j['hora_estimada'] == null
        ? null
        : DateTime.parse(j['hora_estimada'] as String).toLocal(),
    nodo: j['nodo'] == null
        ? null
        : NodoConductor.fromJson(j['nodo'] as Map<String, dynamic>),
  );

  ParadaConductor copiar({bool? recolectado}) => ParadaConductor(
    id: id,
    rutaId: rutaId,
    nodoId: nodoId,
    orden: orden,
    recolectado: recolectado ?? this.recolectado,
    horaEstimada: horaEstimada,
    nodo: nodo,
  );
}

/// Ruta asignada al conductor (GET /rutas/mias y GET /rutas/{id}).
class RutaConductor {
  final int id;
  final DateTime fechaInicio;
  final DateTime fechaFin;
  final DateTime horaInicio;
  final DateTime horaFin;
  final int camionId;
  final int? conductorId;
  final EstadoRutaConductor estado;
  final CamionConductor? camion;
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
  });

  int get paradasTotal => paradas.length;

  int get paradasHechas => paradas.where((p) => p.recolectado).length;

  double get progreso => paradasTotal == 0 ? 0 : paradasHechas / paradasTotal;

  factory RutaConductor.fromJson(Map<String, dynamic> j) {
    final paradas =
        (j['paradas'] as List? ?? const [])
            .map((e) => ParadaConductor.fromJson(e as Map<String, dynamic>))
            .toList()
          ..sort((a, b) => a.orden.compareTo(b.orden));

    return RutaConductor(
      id: j['id'] as int,
      fechaInicio: DateTime.parse(j['fecha_inicio'] as String),
      fechaFin: DateTime.parse(j['fecha_fin'] as String),
      horaInicio: DateTime.parse(j['hora_inicio'] as String).toLocal(),
      horaFin: DateTime.parse(j['hora_fin'] as String).toLocal(),
      camionId: j['camion_id'] as int,
      conductorId: (j['conductor_id'] as num?)?.toInt(),
      estado: estadoRutaDesde(j['estado'] as String?),
      camion: j['camion'] == null
          ? null
          : CamionConductor.fromJson(j['camion'] as Map<String, dynamic>),
      paradas: paradas,
    );
  }
}

/// Elige la ruta "del día": primero la que está en proceso, luego una
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
