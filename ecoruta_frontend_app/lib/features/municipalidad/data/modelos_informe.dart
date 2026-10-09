enum RangoInforme { hoy, sieteDias, treintaDias, personalizado }

abstract final class MetasKpiInforme {
  static const reduccionKm = 15.0;
  static const reduccionDesbordes = 40.0;
  static const errorPrediccionHoras = 4.0;
  static const disponibilidadNodos = 90.0;
  static const rutasEjecutadas = 70.0;
}

class PuntoSerieInforme {
  const PuntoSerieInforme({required this.fecha, required this.valor});

  final DateTime fecha;
  final double valor;
}

class KpiInforme {
  const KpiInforme({
    required this.clave,
    required this.nombre,
    required this.valor,
    required this.meta,
    required this.unidad,
    required this.mayorEsMejor,
  });

  final String clave;
  final String nombre;
  final double valor;
  final double meta;
  final String unidad;
  final bool mayorEsMejor;

  bool get cumple => mayorEsMejor ? valor >= meta : valor <= meta;
}

class DatosInforme {
  const DatosInforme({
    required this.inicio,
    required this.fin,
    required this.kpis,
    required this.llenadoPromedio,
    required this.desbordesPorZona,
    required this.kilometrosOptimizados,
    required this.kilometrosFijos,
  });

  final DateTime inicio;
  final DateTime fin;
  final List<KpiInforme> kpis;
  final List<PuntoSerieInforme> llenadoPromedio;
  final Map<String, int> desbordesPorZona;
  final List<PuntoSerieInforme> kilometrosOptimizados;
  final List<PuntoSerieInforme> kilometrosFijos;
}
