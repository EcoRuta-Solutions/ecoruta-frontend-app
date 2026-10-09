enum EstadoRuta { propuesta, aprobada, enCurso, completada }

class AccionRuta {
  const AccionRuta({
    required this.que,
    required this.quien,
    required this.cuando,
  });

  final String que;
  final String quien;
  final DateTime cuando;
}

class ParadaRuta {
  const ParadaRuta({
    required this.nodoId,
    required this.orden,
    required this.horaEstimada,
  });

  final int nodoId;
  final int orden;
  final DateTime horaEstimada;
}

class RutaMunicipal {
  const RutaMunicipal({
    required this.id,
    required this.nombre,
    required this.zona,
    required this.estado,
    required this.paradas,
    required this.distanciaKm,
    required this.duracionMin,
    required this.distanciaFijaKm,
    required this.duracionFijaMin,
    required this.paradasFijas,
    this.historial = const [],
    this.conductorId,
    this.vehiculoId,
  });

  final String id;
  final String nombre;
  final String zona;
  final EstadoRuta estado;
  final List<ParadaRuta> paradas;
  final double distanciaKm;
  final int duracionMin;
  final int? conductorId;
  final int? vehiculoId;
  final double distanciaFijaKm;
  final int duracionFijaMin;
  final int paradasFijas;
  final List<AccionRuta> historial;

  double get ahorroKmPorcentaje => distanciaFijaKm <= 0
      ? 0
      : (distanciaFijaKm - distanciaKm) / distanciaFijaKm * 100;

  RutaMunicipal copiar({
    EstadoRuta? estado,
    List<ParadaRuta>? paradas,
    int? conductorId,
    int? vehiculoId,
    List<AccionRuta>? historial,
  }) => RutaMunicipal(
    id: id,
    nombre: nombre,
    zona: zona,
    estado: estado ?? this.estado,
    paradas: paradas ?? this.paradas,
    distanciaKm: distanciaKm,
    duracionMin: duracionMin,
    distanciaFijaKm: distanciaFijaKm,
    duracionFijaMin: duracionFijaMin,
    paradasFijas: paradasFijas,
    conductorId: conductorId ?? this.conductorId,
    vehiculoId: vehiculoId ?? this.vehiculoId,
    historial: historial ?? this.historial,
  );
}
