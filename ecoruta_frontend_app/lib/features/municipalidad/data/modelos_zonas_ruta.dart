/// Turno de recolección tal como lo envía el backend (`manana`, `tarde`,
/// `noche`).
enum TurnoZona {
  manana('manana', 'Mañana'),
  tarde('tarde', 'Tarde'),
  noche('noche', 'Noche');

  const TurnoZona(this.valorApi, this.etiqueta);

  /// Valor del enum `Turno` del backend y del filtro `?turno=`.
  final String valorApi;

  /// Texto para la pestaña.
  final String etiqueta;

  static TurnoZona desdeApi(String valor) => TurnoZona.values.firstWhere(
    (turno) => turno.valorApi == valor,
    orElse: () => throw FormatException('Turno desconocido: $valor'),
  );

  /// Turno al que pertenece una hora, con los horarios de SEGAT del backend
  /// (`app/core/turnos.py`): mañana 05–13, tarde 13–21, noche 21–05.
  /// Inicio inclusivo y fin exclusivo.
  static TurnoZona deHora(DateTime ahora) {
    final hora = ahora.hour;
    if (hora >= 5 && hora < 13) return TurnoZona.manana;
    if (hora >= 13 && hora < 21) return TurnoZona.tarde;
    return TurnoZona.noche;
  }
}

/// Hora del día sin fecha (los campos `format: time` del backend).
class HoraDia {
  const HoraDia(this.hora, this.minuto);

  final int hora;
  final int minuto;

  /// Acepta `HH:MM` o `HH:MM:SS` (con fracción de segundo opcional).
  factory HoraDia.parse(String valor) {
    final partes = valor.split(':');
    if (partes.length < 2) throw FormatException('Hora inválida: $valor');
    final hora = int.parse(partes[0]);
    final minuto = int.parse(partes[1]);
    if (hora < 0 || hora > 23 || minuto < 0 || minuto > 59) {
      throw FormatException('Hora inválida: $valor');
    }
    return HoraDia(hora, minuto);
  }

  static HoraDia? parseOpcional(Object? valor) =>
      valor == null ? null : HoraDia.parse(valor as String);

  int get minutosDelDia => hora * 60 + minuto;

  /// `21:00`
  String get texto =>
      '${hora.toString().padLeft(2, '0')}:${minuto.toString().padLeft(2, '0')}';

  @override
  bool operator ==(Object other) =>
      other is HoraDia && other.hora == hora && other.minuto == minuto;

  @override
  int get hashCode => Object.hash(hora, minuto);

  @override
  String toString() => texto;
}

/// Una zona de ruta de GET /zonas-ruta (`ZonaRutaOut` en el backend).
class ZonaRuta {
  const ZonaRuta({
    required this.id,
    required this.codigo,
    required this.turno,
    required this.tramo,
    required this.sectores,
    required this.recojoInicio,
    required this.recojoFin,
    required this.sacarBasuraInicio,
    required this.sacarBasuraFin,
    required this.cruzaMedianoche,
    required this.revisar,
  });

  final int id;

  /// M-1…M-10, N-1…N-9, etc.
  final String codigo;
  final TurnoZona turno;
  final String? tramo;
  final String? sectores;
  final HoraDia recojoInicio;
  final HoraDia recojoFin;
  final HoraDia? sacarBasuraInicio;
  final HoraDia? sacarBasuraFin;
  final bool cruzaMedianoche;

  /// Dato transcrito de la hoja de la municipalidad, pendiente de confirmar.
  final bool revisar;

  factory ZonaRuta.fromJson(Map<String, dynamic> json) => ZonaRuta(
    id: json['id'] as int,
    codigo: json['codigo'] as String,
    turno: TurnoZona.desdeApi(json['turno'] as String),
    tramo: json['tramo'] as String?,
    sectores: json['sectores'] as String?,
    recojoInicio: HoraDia.parse(json['recojo_inicio'] as String),
    recojoFin: HoraDia.parse(json['recojo_fin'] as String),
    sacarBasuraInicio: HoraDia.parseOpcional(json['sacar_basura_inicio']),
    sacarBasuraFin: HoraDia.parseOpcional(json['sacar_basura_fin']),
    cruzaMedianoche: json['cruza_medianoche'] as bool,
    revisar: json['revisar'] as bool,
  );

  /// `21:00 – 05:00`
  String get ventanaRecojo => '${recojoInicio.texto} – ${recojoFin.texto}';

  /// `20:00 – 21:00`, o null si el backend no trae el horario completo.
  String? get ventanaSacarBasura {
    final inicio = sacarBasuraInicio;
    final fin = sacarBasuraFin;
    if (inicio == null || fin == null) return null;
    return '${inicio.texto} – ${fin.texto}';
  }

  /// La ventana de recojo termina al día siguiente (p. ej. 21:00 – 05:00).
  /// Se usa el indicador del backend y, por si viene apagado, también se
  /// considera nocturna si el fin es anterior al inicio.
  bool get ventanaCruzaMedianoche =>
      cruzaMedianoche || recojoFin.minutosDelDia < recojoInicio.minutosDelDia;

  /// Indica si [ahora] cae en la ventana de recojo (inicio inclusivo, fin
  /// exclusivo). Si la ventana cruza la medianoche (p. ej. 21:00 – 05:00)
  /// vale tanto a las 23:00 como a las 03:00.
  bool recogiendoA(DateTime ahora) {
    final minuto = ahora.hour * 60 + ahora.minute;
    final inicio = recojoInicio.minutosDelDia;
    final fin = recojoFin.minutosDelDia;
    if (ventanaCruzaMedianoche) return minuto >= inicio || minuto < fin;
    return minuto >= inicio && minuto < fin;
  }
}

/// Una ruta de SEGAT con todos sus tramos. GET /zonas-ruta devuelve una
/// fila por tramo; aquí se juntan las del mismo código.
class RutaZona {
  const RutaZona({required this.codigo, required this.tramos});

  final String codigo;

  /// En el orden del backend (por código y tramo).
  final List<ZonaRuta> tramos;

  TurnoZona get turno => tramos.first.turno;

  /// Algún tramo está pendiente de confirmación.
  bool get revisar => tramos.any((tramo) => tramo.revisar);

  /// Algún tramo está en su ventana de recojo a esta hora.
  bool recogiendoA(DateTime ahora) =>
      tramos.any((tramo) => tramo.recogiendoA(ahora));
}

/// Junta las filas por `codigo`, conservando el orden en que llegan: cada
/// ruta aparece una sola vez, en la posición de su primer tramo.
List<RutaZona> agruparPorCodigo(List<ZonaRuta> filas) {
  final porCodigo = <String, List<ZonaRuta>>{};
  for (final fila in filas) {
    porCodigo.putIfAbsent(fila.codigo, () => []).add(fila);
  }
  return [
    for (final entrada in porCodigo.entries)
      RutaZona(codigo: entrada.key, tramos: entrada.value),
  ];
}
