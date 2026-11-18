/// Modelos de los reportes de campo del nivel de llenado (POST/GET
/// /reportes-campo, /reportes-campo/resumen y
/// /puntos-criticos/{codigo}/ultimo-reporte). Los nombres de campo siguen
/// `ReporteCampoCreate`, `ReporteCampoOut`, `ResumenReportesOut`,
/// `UltimoReportePuntoOut` y `UltimoReporteBreve` del OpenAPI del backend.
library;

/// Nivel de llenado. [sinDatos] solo lo calcula el backend (no hay reporte
/// vigente); nunca se envía en un reporte.
enum NivelLlenado {
  vacio('vacio', 'Vacío'),
  medio('medio', 'Medio'),
  lleno('lleno', 'Lleno'),
  desbordado('desbordado', 'Desbordado'),
  sinDatos('sin_datos', 'Sin datos');

  const NivelLlenado(this.valorApi, this.etiqueta);

  final String valorApi;
  final String etiqueta;

  /// Los cuatro estados que se pueden reportar.
  static const reportables = [vacio, medio, lleno, desbordado];

  /// Un valor desconocido o ausente se muestra como "Sin datos", nunca
  /// como un nivel supuesto.
  static NivelLlenado desdeApi(Object? valor) => NivelLlenado.values
      .firstWhere((nivel) => nivel.valorApi == valor, orElse: () => sinDatos);
}

/// Fechas del backend (ISO 8601 con zona horaria), en hora local.
DateTime _fecha(Object? valor) => DateTime.parse(valor as String).toLocal();

double? _decimal(Object? valor) => (valor as num?)?.toDouble();

/// `ultimo_reporte` dentro de cada punto crítico (`UltimoReporteBreve`).
class UltimoReporteBreve {
  const UltimoReporteBreve({required this.estado, required this.creadoEn});

  final NivelLlenado estado;
  final DateTime creadoEn;

  factory UltimoReporteBreve.fromJson(Map<String, dynamic> j) =>
      UltimoReporteBreve(
        estado: NivelLlenado.desdeApi(j['estado']),
        creadoEn: _fecha(j['creado_en']),
      );
}

/// Cuerpo de POST /reportes-campo. lat y lon van juntas o no van.
class NuevoReporteCampo {
  NuevoReporteCampo({
    required this.codigoPunto,
    required this.estado,
    String? observacion,
    this.lat,
    this.lon,
  }) : observacion = (observacion?.trim().isEmpty ?? true)
           ? null
           : observacion!.trim(),
       assert(NivelLlenado.reportables.contains(estado)),
       assert((lat == null) == (lon == null), 'lat y lon van juntas');

  /// Máximo que acepta el backend en `observacion`.
  static const maximoObservacion = 1000;

  final String codigoPunto;
  final NivelLlenado estado;
  final String? observacion;
  final double? lat;
  final double? lon;

  Map<String, dynamic> toJson() => {
    'codigo_punto': codigoPunto,
    'estado': estado.valorApi,
    if (observacion != null) 'observacion': observacion,
    if (lat != null && lon != null) ...{'lat': lat, 'lon': lon},
  };
}

/// Un reporte guardado (`ReporteCampoOut`).
class ReporteCampo {
  const ReporteCampo({
    required this.id,
    required this.puntoCriticoId,
    required this.codigoPunto,
    required this.usuarioId,
    required this.usuarioNombre,
    required this.estado,
    required this.creadoEn,
    this.observacion,
    this.lat,
    this.lon,
    this.distanciaM,
    this.lejosDelPunto = false,
    this.fotoUrl,
    this.esDemo = false,
  });

  final int id;
  final int puntoCriticoId;
  final String codigoPunto;
  final int usuarioId;
  final String usuarioNombre;
  final NivelLlenado estado;
  final String? observacion;
  final double? lat;
  final double? lon;

  /// Distancia al punto en metros; null si el reporte no trajo GPS.
  final double? distanciaM;

  /// Más de 150 m del punto. El backend lo guarda igual.
  final bool lejosDelPunto;
  final String? fotoUrl;
  final DateTime creadoEn;

  /// Hecho por una cuenta demo: no cuenta para el estado del punto.
  final bool esDemo;

  factory ReporteCampo.fromJson(Map<String, dynamic> j) => ReporteCampo(
    id: (j['id'] as num).toInt(),
    puntoCriticoId: (j['punto_critico_id'] as num).toInt(),
    codigoPunto: j['codigo_punto'] as String,
    usuarioId: (j['usuario_id'] as num).toInt(),
    usuarioNombre: (j['usuario_nombre'] as String?) ?? '',
    estado: NivelLlenado.desdeApi(j['estado']),
    observacion: j['observacion'] as String?,
    lat: _decimal(j['lat']),
    lon: _decimal(j['lon']),
    distanciaM: _decimal(j['distancia_m']),
    lejosDelPunto: (j['lejos_del_punto'] as bool?) ?? false,
    fotoUrl: j['foto_url'] as String?,
    creadoEn: _fecha(j['creado_en']),
    esDemo: (j['es_demo'] as bool?) ?? false,
  );
}

/// GET /puntos-criticos/{codigo}/ultimo-reporte.
class UltimoReportePunto {
  const UltimoReportePunto({
    required this.codigo,
    required this.reporteVigente,
    required this.estadoLlenado,
    required this.vigenciaHoras,
    this.reporte,
  });

  final String codigo;
  final bool reporteVigente;

  /// Nivel a mostrar: el del último reporte si está vigente; si no,
  /// [NivelLlenado.sinDatos].
  final NivelLlenado estadoLlenado;
  final double vigenciaHoras;

  /// Último reporte aunque ya no esté vigente; null si nunca se reportó.
  final ReporteCampo? reporte;

  factory UltimoReportePunto.fromJson(Map<String, dynamic> j) {
    final reporte = j['reporte'];
    return UltimoReportePunto(
      codigo: j['codigo'] as String,
      reporteVigente: (j['reporte_vigente'] as bool?) ?? false,
      estadoLlenado: NivelLlenado.desdeApi(j['estado_llenado']),
      vigenciaHoras: _decimal(j['vigencia_horas']) ?? 0,
      reporte: reporte is Map<String, dynamic>
          ? ReporteCampo.fromJson(reporte)
          : null,
    );
  }
}

/// GET /reportes-campo/resumen.
class ResumenReportes {
  const ResumenReportes({
    required this.totalPuntos,
    required this.vigenciaHoras,
    required this.porEstado,
    required this.sinDatos,
  });

  final int totalPuntos;
  final double vigenciaHoras;

  /// Puntos cuyo último reporte vigente tiene cada estado.
  final Map<NivelLlenado, int> porEstado;
  final int sinDatos;

  int cantidad(NivelLlenado nivel) =>
      nivel == NivelLlenado.sinDatos ? sinDatos : (porEstado[nivel] ?? 0);

  factory ResumenReportes.fromJson(Map<String, dynamic> j) {
    final porEstado = j['por_estado'] as Map<String, dynamic>? ?? const {};
    return ResumenReportes(
      totalPuntos: (j['total_puntos'] as num?)?.toInt() ?? 0,
      vigenciaHoras: _decimal(j['vigencia_horas']) ?? 0,
      porEstado: {
        for (final nivel in NivelLlenado.reportables)
          nivel: (porEstado[nivel.valorApi] as num?)?.toInt() ?? 0,
      },
      sinDatos: (j['sin_datos'] as num?)?.toInt() ?? 0,
    );
  }
}

/// `17/11/2026 14:05` en hora local.
String fechaHoraReporte(DateTime fecha) {
  final local = fecha.toLocal();
  String dos(int n) => n.toString().padLeft(2, '0');
  return '${dos(local.day)}/${dos(local.month)}/${local.year} '
      '${dos(local.hour)}:${dos(local.minute)}';
}

/// "hace 3 horas", "hace 1 hora", "hace 25 minutos", "hace 2 días".
String haceCuanto(DateTime fecha, DateTime ahora) {
  final diferencia = ahora.difference(fecha);
  if (diferencia.inMinutes < 1) return 'hace menos de un minuto';
  if (diferencia.inHours < 1) {
    final m = diferencia.inMinutes;
    return m == 1 ? 'hace 1 minuto' : 'hace $m minutos';
  }
  if (diferencia.inHours < 48) {
    final h = diferencia.inHours;
    return h == 1 ? 'hace 1 hora' : 'hace $h horas';
  }
  return 'hace ${diferencia.inDays} días';
}

/// `24 h` o `1,5 h`.
String horasVigencia(double horas) => horas == horas.roundToDouble()
    ? '${horas.toInt()} h'
    : '${horas.toStringAsFixed(1).replaceAll('.', ',')} h';
