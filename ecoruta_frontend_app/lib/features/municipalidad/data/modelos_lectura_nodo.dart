import 'modelos_panel.dart';

class LecturaLlenado {
  const LecturaLlenado({required this.fecha, required this.porcentaje});

  final DateTime fecha;
  final double porcentaje;
}

class PrediccionLlenado {
  const PrediccionLlenado({
    required this.horaEstimadaDesborde,
    required this.confianza,
  });

  final DateTime horaEstimadaDesborde;
  final double confianza;
}

enum TipoEventoNodo { volteado, lecturaAtipica, bateriaBaja, mantenimiento }

class EventoNodo {
  const EventoNodo({
    required this.tipo,
    required this.fecha,
    required this.descripcion,
  });

  final TipoEventoNodo tipo;
  final DateTime fecha;
  final String descripcion;
}

class DetalleNodo {
  const DetalleNodo({
    required this.nodo,
    required this.lecturas,
    required this.eventos,
    this.prediccion,
  });

  final NodoEstado nodo;
  final List<LecturaLlenado> lecturas;
  final List<EventoNodo> eventos;
  final PrediccionLlenado? prediccion;
}
