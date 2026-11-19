/// Alertas de contenedor que genera el backend a partir de los sensores
/// (GET /alertas/activas, roles municipalidad y conductor).
///
/// No confundir con `AlertaPanel` (modelos_alerta.dart), que es el flujo
/// demo de los contenedores simulados.
library;

/// Una alerta activa. Los campos que el backend no envíe quedan en null y
/// la pantalla los muestra como "por confirmar"; nunca se suponen.
class AlertaActiva {
  const AlertaActiva({
    required this.id,
    required this.tipo,
    required this.mensaje,
    required this.puntoCodigo,
    required this.direccion,
    this.nivelPct,
    this.puntoCriticoId,
    this.lat,
    this.lon,
    this.creadaEn,
  });

  final int id;

  /// Tipo tal como lo envía el backend.
  final String tipo;
  final String mensaje;

  /// Porcentaje de llenado medido por el sensor.
  final double? nivelPct;
  final int? puntoCriticoId;
  final String puntoCodigo;
  final String direccion;
  final double? lat;
  final double? lon;

  /// En hora local.
  final DateTime? creadaEn;

  factory AlertaActiva.fromJson(Map<String, dynamic> j) => AlertaActiva(
    id: (j['id'] as num).toInt(),
    tipo: (j['tipo'] as String?) ?? '',
    mensaje: (j['mensaje'] as String?) ?? '',
    nivelPct: (j['nivel_pct'] as num?)?.toDouble(),
    puntoCriticoId: (j['punto_critico_id'] as num?)?.toInt(),
    puntoCodigo: (j['punto_codigo'] as String?) ?? '',
    direccion: (j['direccion'] as String?) ?? '',
    lat: (j['lat'] as num?)?.toDouble(),
    lon: (j['lon'] as num?)?.toDouble(),
    creadaEn: _fechaONula(j['creada_en']),
  );

  /// `92%` o "por confirmar".
  String get nivelTexto {
    final nivel = nivelPct;
    return nivel == null ? 'por confirmar' : '${nivel.round()}%';
  }

  String get codigoTexto => puntoCodigo.isEmpty ? 'por confirmar' : puntoCodigo;

  String get direccionTexto => direccion.isEmpty ? 'por confirmar' : direccion;

  /// `14:05` en hora local, o "por confirmar".
  String get horaTexto {
    final fecha = creadaEn;
    if (fecha == null) return 'por confirmar';
    String dos(int n) => n.toString().padLeft(2, '0');
    return '${dos(fecha.hour)}:${dos(fecha.minute)}';
  }
}

/// Lista de GET /alertas/activas. Ignora elementos que no sean objetos.
List<AlertaActiva> alertasActivasDesdeJson(Object? datos) => [
  for (final item in (datos as List? ?? const []))
    if (item is Map<String, dynamic>) AlertaActiva.fromJson(item),
];

DateTime? _fechaONula(Object? valor) =>
    valor is String ? DateTime.tryParse(valor)?.toLocal() : null;
