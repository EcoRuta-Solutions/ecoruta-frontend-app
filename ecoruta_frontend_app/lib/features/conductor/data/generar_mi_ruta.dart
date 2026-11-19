/// POST /rutas/generar-mia (rol conductor, sin cuerpo): arma la ruta del
/// conductor con los contenedores llenos.
library;

import 'package:dio/dio.dart';

/// Respuesta 201. Solo se leen los campos que usa la app; la ruta nueva se
/// vuelve a pedir con GET /rutas/mias para mostrarla en "Mi ruta".
class ResultadoGenerarMiRuta {
  const ResultadoGenerarMiRuta({
    required this.nroPuntos,
    required this.metodoDistancia,
    required this.rutasReemplazadas,
    this.rutaId,
  });

  final int nroPuntos;
  final String metodoDistancia;
  final int rutasReemplazadas;

  /// Id de la ruta creada, si el backend lo envía en `ruta`.
  final int? rutaId;

  factory ResultadoGenerarMiRuta.fromJson(Map<String, dynamic> j) {
    final ruta = j['ruta'];
    final id = ruta is Map ? (ruta['id'] ?? ruta['ruta_id']) : null;
    final reemplazadas = j['rutas_reemplazadas'];
    return ResultadoGenerarMiRuta(
      nroPuntos: (j['nro_puntos'] as num?)?.toInt() ?? 0,
      metodoDistancia: (j['metodo_distancia'] as String?) ?? '',
      // Número de rutas reemplazadas; si llegara como lista, su largo.
      rutasReemplazadas: reemplazadas is num
          ? reemplazadas.toInt()
          : reemplazadas is List
          ? reemplazadas.length
          : 0,
      rutaId: id is num ? id.toInt() : null,
    );
  }
}

/// Error de POST /rutas/generar-mia con un mensaje en español.
class ErrorGenerarMiRuta implements Exception {
  const ErrorGenerarMiRuta(this.mensaje, {this.codigo, this.detalle});

  final String mensaje;
  final int? codigo;

  /// Explicación del backend (`detail`), si la envió como texto.
  final String? detalle;

  @override
  String toString() => detalle == null ? mensaje : '$mensaje ($detalle)';
}

const mensajeYaTieneRuta =
    'No se pudo generar tu ruta: ya tienes una ruta en proceso hoy o no '
    'tienes un camión asignado. Consulta con la municipalidad si necesitas '
    'un cambio.';

const mensajeSinPuntosLlenos =
    'No hay contenedores llenos en este momento, así que no hay ruta que '
    'generar.';

/// Traduce el error HTTP de POST /rutas/generar-mia.
ErrorGenerarMiRuta errorGenerarMiRutaDesde(DioException error) {
  final codigo = error.response?.statusCode;
  final datos = error.response?.data;
  final detalle = datos is Map && datos['detail'] is String
      ? datos['detail'] as String
      : null;
  final mensaje = switch (codigo) {
    null => 'No se pudo conectar con el servidor. Revisa tu conexión.',
    409 => mensajeYaTieneRuta,
    422 => mensajeSinPuntosLlenos,
    401 => 'Tu sesión venció. Inicia sesión nuevamente.',
    403 => 'Solo un conductor puede generar su ruta.',
    _ => 'El servidor respondió con un error ($codigo).',
  };
  return ErrorGenerarMiRuta(mensaje, codigo: codigo, detalle: detalle);
}
