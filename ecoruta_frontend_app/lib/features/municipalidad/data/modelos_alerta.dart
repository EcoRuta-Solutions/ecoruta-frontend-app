enum TipoAlerta { critico, enAlerta, volteado, bateriaBaja, sinDatos }

enum EstadoAlerta { nueva, reconocida, asignada, atendida }

class AccionAlerta {
  const AccionAlerta({
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

class AlertaPanel {
  const AlertaPanel({
    required this.id,
    required this.nodoId,
    required this.tipo,
    required this.estado,
    required this.creada,
    required this.historial,
    this.asignadoA,
  });

  final String id;
  final int nodoId;
  final TipoAlerta tipo;
  final EstadoAlerta estado;
  final String? asignadoA;
  final DateTime creada;
  final List<AccionAlerta> historial;

  bool get activaSinReconocer => estado == EstadoAlerta.nueva;

  AlertaPanel copyWith({
    EstadoAlerta? estado,
    String? asignadoA,
    List<AccionAlerta>? historial,
  }) => AlertaPanel(
    id: id,
    nodoId: nodoId,
    tipo: tipo,
    estado: estado ?? this.estado,
    asignadoA: asignadoA ?? this.asignadoA,
    creada: creada,
    historial: historial ?? this.historial,
  );
}
