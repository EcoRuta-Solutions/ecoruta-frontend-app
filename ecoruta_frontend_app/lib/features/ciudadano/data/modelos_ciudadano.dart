enum EstadoReporteCiudadano { recibido, enAtencion, resuelto }

class ReporteCiudadanoApp {
  const ReporteCiudadanoApp({
    required this.id,
    required this.descripcion,
    required this.latitud,
    required this.longitud,
    required this.fecha,
    required this.estado,
    this.asignadoA,
  });

  final int id;
  final String descripcion;
  final double latitud;
  final double longitud;
  final DateTime fecha;
  final EstadoReporteCiudadano estado;
  final String? asignadoA;
}
