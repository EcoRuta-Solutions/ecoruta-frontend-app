enum CategoriaReporte {
  contenedorLleno,
  danado,
  basuraAcumulada,
  malOlor,
  otro,
}

enum EstadoReporte { recibido, enAtencion, resuelto }

class AccionReporte {
  const AccionReporte({
    required this.que,
    required this.quien,
    required this.cuando,
    this.nota,
  });

  final String que;
  final String quien;
  final DateTime cuando;
  final String? nota;
}

class ReporteCiudadano {
  const ReporteCiudadano({
    required this.id,
    required this.categoria,
    required this.descripcion,
    required this.latitud,
    required this.longitud,
    required this.fecha,
    required this.estado,
    required this.historial,
    this.nodoRelacionado,
    this.asignadoA,
  });

  final String id;
  final CategoriaReporte categoria;
  final String descripcion;
  final double latitud;
  final double longitud;
  final DateTime fecha;
  final EstadoReporte estado;
  final int? nodoRelacionado;
  final String? asignadoA;
  final List<AccionReporte> historial;

  ReporteCiudadano copiar({
    EstadoReporte? estado,
    String? asignadoA,
    List<AccionReporte>? historial,
  }) => ReporteCiudadano(
    id: id,
    categoria: categoria,
    descripcion: descripcion,
    latitud: latitud,
    longitud: longitud,
    fecha: fecha,
    estado: estado ?? this.estado,
    historial: historial ?? this.historial,
    nodoRelacionado: nodoRelacionado,
    asignadoA: asignadoA ?? this.asignadoA,
  );
}
