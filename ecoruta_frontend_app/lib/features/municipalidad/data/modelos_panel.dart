/// Estado de un contenedor, tal como lo calcula el backend.
enum EstadoNodo { critico, alerta, normal, sinDatos }

enum EstadoOperativo { activo, mantenimiento, inactivo }

/// Referencia visual del gráfico; no determina el estado operativo del nodo.
const double umbralReferenciaGrafico = 80;

EstadoNodo estadoDesdeTexto(String? valor) {
  switch (valor) {
    case 'critico':
      return EstadoNodo.critico;
    case 'alerta':
      return EstadoNodo.alerta;
    case 'normal':
      return EstadoNodo.normal;
    default:
      return EstadoNodo.sinDatos;
  }
}

/// Un contenedor con su última lectura (GET /panel/estado).
class NodoEstado {
  final int id;
  final String codigo;
  final String nombre;
  final double? latitud;
  final double? longitud;
  final String zona;
  final int capacidadLitros;
  final int? bateria;
  final int? senal;
  final EstadoOperativo estadoOperativo;
  final String firmware;
  final String tipoResiduo;
  final DateTime fechaInstalacion;
  final int umbralCritico;
  final double? llenado; // fill_pct: es null si aún no hay lecturas
  final bool? volteado; // tilt_alert
  final DateTime? ultimaLectura;
  final EstadoNodo estado;

  NodoEstado({
    required this.id,
    required this.codigo,
    required this.nombre,
    required this.latitud,
    required this.longitud,
    required this.umbralCritico,
    required this.llenado,
    required this.volteado,
    required this.ultimaLectura,
    required this.estado,
    this.zona = 'Centro',
    this.capacidadLitros = 1200,
    this.bateria = 88,
    this.senal = 4,
    this.estadoOperativo = EstadoOperativo.activo,
    this.firmware = '1.0.0',
    this.tipoResiduo = 'Residuos generales',
    DateTime? fechaInstalacion,
  }) : fechaInstalacion = fechaInstalacion ?? DateTime.utc(2025, 1, 1);

  factory NodoEstado.fromJson(Map<String, dynamic> j) => NodoEstado(
    id: j['id'] as int,
    codigo: j['codigo'] as String,
    nombre: j['nombre'] as String,
    latitud: (j['latitud'] as num?)?.toDouble(),
    longitud: (j['longitud'] as num?)?.toDouble(),
    umbralCritico: (j['umbral_critico'] as num).toInt(),
    llenado: (j['fill_pct'] as num?)?.toDouble(),
    volteado: j['tilt_alert'] as bool?,
    ultimaLectura: j['ultima_lectura'] == null
        ? null
        : DateTime.parse(j['ultima_lectura'] as String).toLocal(),
    estado: estadoDesdeTexto(j['estado'] as String?),
    zona: j['zona'] as String? ?? 'Centro',
    capacidadLitros: (j['capacidad_litros'] as num?)?.toInt() ?? 1200,
    bateria: (j['bateria'] as num?)?.toInt(),
    senal: (j['senal'] as num?)?.toInt(),
    estadoOperativo: switch (j['estado_operativo'] as String?) {
      'mantenimiento' => EstadoOperativo.mantenimiento,
      'inactivo' => EstadoOperativo.inactivo,
      _ => EstadoOperativo.activo,
    },
    firmware: j['firmware'] as String? ?? '1.0.0',
    tipoResiduo: j['tipo_residuo'] as String? ?? 'Residuos generales',
    fechaInstalacion:
        DateTime.tryParse(j['fecha_instalacion'] as String? ?? '') ??
        DateTime.utc(2025, 1, 1),
  );

  /// Copia del nodo con los datos nuevos que llegan por WebSocket.
  NodoEstado conLectura({
    required double llenado,
    required EstadoNodo estado,
    bool? volteado,
    DateTime? ultimaLectura,
  }) => NodoEstado(
    id: id,
    codigo: codigo,
    nombre: nombre,
    latitud: latitud,
    longitud: longitud,
    umbralCritico: umbralCritico,
    llenado: llenado,
    volteado: volteado ?? this.volteado,
    ultimaLectura: ultimaLectura ?? this.ultimaLectura,
    estado: estado,
    zona: zona,
    capacidadLitros: capacidadLitros,
    bateria: bateria,
    senal: senal,
    estadoOperativo: estadoOperativo,
    firmware: firmware,
    tipoResiduo: tipoResiduo,
    fechaInstalacion: fechaInstalacion,
  );

  NodoEstado copiar({
    String? nombre,
    String? codigo,
    String? zona,
    int? capacidadLitros,
    String? tipoResiduo,
    double? latitud,
    double? longitud,
    EstadoOperativo? estadoOperativo,
  }) => NodoEstado(
    id: id,
    codigo: codigo ?? this.codigo,
    nombre: nombre ?? this.nombre,
    latitud: latitud ?? this.latitud,
    longitud: longitud ?? this.longitud,
    umbralCritico: umbralCritico,
    llenado: llenado,
    volteado: volteado,
    ultimaLectura: ultimaLectura,
    estado: estado,
    zona: zona ?? this.zona,
    capacidadLitros: capacidadLitros ?? this.capacidadLitros,
    bateria: bateria,
    senal: senal,
    estadoOperativo: estadoOperativo ?? this.estadoOperativo,
    firmware: firmware,
    tipoResiduo: tipoResiduo ?? this.tipoResiduo,
    fechaInstalacion: fechaInstalacion,
  );
}

/// Totales del panel (GET /panel/resumen).
class ResumenPanel {
  final int totalNodos;
  final int criticos;
  final int alertas;
  final int normales;
  final int sinDatos;
  final double? promedioLlenado;

  int get nodosConDatos => totalNodos - sinDatos;

  const ResumenPanel({
    required this.totalNodos,
    required this.criticos,
    required this.alertas,
    required this.normales,
    required this.sinDatos,
    required this.promedioLlenado,
  });

  factory ResumenPanel.fromJson(Map<String, dynamic> j) => ResumenPanel(
    totalNodos: (j['total_nodos'] as num).toInt(),
    criticos: (j['criticos'] as num).toInt(),
    alertas: (j['alertas'] as num).toInt(),
    normales: (j['normales'] as num).toInt(),
    sinDatos: (j['sin_datos'] as num).toInt(),
    promedioLlenado: (j['promedio_llenado'] as num?)?.toDouble(),
  );
}
