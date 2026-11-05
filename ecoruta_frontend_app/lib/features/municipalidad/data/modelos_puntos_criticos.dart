/// Modelos de los puntos críticos de acumulación de residuos que expone el
/// backend en GET /puntos-criticos, /puntos-criticos/resumen y
/// /puntos-criticos/{codigo}. Los nombres de campo siguen el esquema
/// `PuntoCriticoOut` / `ResumenPuntosCriticos` del OpenAPI del backend.
library;

enum EstadoPuntoCritico { potencial, recuperado, desconocido }

/// Cómo se pinta un punto en el mapa. Un punto recuperado se muestra como
/// recuperado aunque haya tenido priorización obligatoria.
enum CategoriaPuntoCritico { prioritario, potencial, recuperado }

/// Chips de filtro del mapa.
enum FiltroPuntosCriticos { todos, prioritarios, potenciales, recuperados }

EstadoPuntoCritico estadoPuntoCriticoDesdeTexto(Object? valor) =>
    switch (valor) {
      'potencial' => EstadoPuntoCritico.potencial,
      'recuperado' => EstadoPuntoCritico.recuperado,
      _ => EstadoPuntoCritico.desconocido,
    };

class PuntoCritico {
  const PuntoCritico({
    required this.codigo,
    required this.estado,
    required this.priorizacionObligatoria,
    required this.direccion,
    this.id,
    this.referencia,
    this.latitud,
    this.longitud,
  });

  final int? id;
  final String codigo;
  final EstadoPuntoCritico estado;
  final bool priorizacionObligatoria;
  final String direccion;
  final String? referencia;
  final double? latitud;
  final double? longitud;

  factory PuntoCritico.fromJson(Map<String, dynamic> j) => PuntoCritico(
    id: (j['id'] as num?)?.toInt(),
    codigo: (j['codigo'] ?? j['codigo_unico'] ?? '').toString(),
    estado: estadoPuntoCriticoDesdeTexto(j['estado']),
    priorizacionObligatoria: (j['priorizacion_obligatoria'] as bool?) ?? false,
    direccion: (j['direccion'] as String?) ?? '',
    referencia: _textoONulo(j['referencia']),
    latitud: (j['lat'] as num?)?.toDouble(),
    longitud: (j['lon'] as num?)?.toDouble(),
  );

  /// Coordenadas válidas para dibujarlo en el mapa.
  bool get tieneCoordenadas {
    final lat = latitud;
    final lon = longitud;
    return lat != null &&
        lon != null &&
        lat.isFinite &&
        lon.isFinite &&
        lat >= -90 &&
        lat <= 90 &&
        lon >= -180 &&
        lon <= 180;
  }

  CategoriaPuntoCritico get categoria {
    if (estado == EstadoPuntoCritico.recuperado) {
      return CategoriaPuntoCritico.recuperado;
    }
    return priorizacionObligatoria
        ? CategoriaPuntoCritico.prioritario
        : CategoriaPuntoCritico.potencial;
  }
}

/// Aplica un chip de filtro del mapa.
/// - Prioritarios: los de priorización obligatoria (cualquier estado), igual
///   que el conteo `por_prioridad.prioritarios` del resumen.
/// - Potenciales / Recuperados: por `estado`.
List<PuntoCritico> filtrarPuntosCriticos(
  Iterable<PuntoCritico> puntos,
  FiltroPuntosCriticos filtro,
) => [
  for (final punto in puntos)
    if (switch (filtro) {
      FiltroPuntosCriticos.todos => true,
      FiltroPuntosCriticos.prioritarios => punto.priorizacionObligatoria,
      FiltroPuntosCriticos.potenciales =>
        punto.estado == EstadoPuntoCritico.potencial,
      FiltroPuntosCriticos.recuperados =>
        punto.estado == EstadoPuntoCritico.recuperado,
    })
      punto,
];

/// Una página de GET /puntos-criticos.
class PaginaPuntosCriticos {
  const PaginaPuntosCriticos({
    required this.total,
    required this.limit,
    required this.offset,
    required this.items,
  });

  final int total;
  final int limit;
  final int offset;
  final List<PuntoCritico> items;

  factory PaginaPuntosCriticos.fromJson(Map<String, dynamic> j) {
    final items = [
      for (final item in (j['items'] as List? ?? const []))
        if (item is Map<String, dynamic>) PuntoCritico.fromJson(item),
    ];
    return PaginaPuntosCriticos(
      total: (j['total'] as num?)?.toInt() ?? items.length,
      limit: (j['limit'] as num?)?.toInt() ?? items.length,
      offset: (j['offset'] as num?)?.toInt() ?? 0,
      items: items,
    );
  }
}

/// GET /puntos-criticos/resumen.
class ResumenPuntosCriticos {
  const ResumenPuntosCriticos({
    required this.total,
    required this.potenciales,
    required this.recuperados,
    required this.prioritarios,
    required this.noPrioritarios,
  });

  final int total;
  final int potenciales;
  final int recuperados;
  final int prioritarios;
  final int noPrioritarios;

  factory ResumenPuntosCriticos.fromJson(Map<String, dynamic> j) {
    final porEstado = j['por_estado'] as Map<String, dynamic>? ?? const {};
    final porPrioridad =
        j['por_prioridad'] as Map<String, dynamic>? ?? const {};
    return ResumenPuntosCriticos(
      total: _entero(j['total']),
      potenciales: _entero(porEstado['potencial']),
      recuperados: _entero(porEstado['recuperado']),
      prioritarios: _entero(porPrioridad['prioritarios']),
      noPrioritarios: _entero(porPrioridad['no_prioritarios']),
    );
  }

  factory ResumenPuntosCriticos.desdePuntos(List<PuntoCritico> puntos) {
    final prioritarios = puntos
        .where((punto) => punto.priorizacionObligatoria)
        .length;
    return ResumenPuntosCriticos(
      total: puntos.length,
      potenciales: puntos
          .where((punto) => punto.estado == EstadoPuntoCritico.potencial)
          .length,
      recuperados: puntos
          .where((punto) => punto.estado == EstadoPuntoCritico.recuperado)
          .length,
      prioritarios: prioritarios,
      noPrioritarios: puntos.length - prioritarios,
    );
  }
}

int _entero(Object? valor) => (valor as num?)?.toInt() ?? 0;

String? _textoONulo(Object? valor) {
  if (valor == null) return null;
  final texto = valor.toString().trim();
  return texto.isEmpty ? null : texto;
}
