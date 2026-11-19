import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/app_config.dart';
import '../../../core/network/api_client.dart';
import '../../municipalidad/data/modelos_reportes_campo.dart';
import '../../municipalidad/data/repositorio_puntos_criticos.dart';
import '../../municipalidad/data/repositorio_reportes_campo.dart';
import 'generar_mi_ruta.dart';
import 'modelos_conductor.dart';

final repositorioConductorProvider = Provider<RepositorioConductor>(
  (ref) => AppConfig.usarDatosDeEjemplo
      ? RepositorioConductorMock()
      : RepositorioConductorApi(ref.read(dioProvider)),
);

/// Acceso a las rutas del conductor contra el backend real.
abstract interface class RepositorioConductor {
  Future<List<RutaConductor>> misRutas();

  Future<RutaConductor> detalle(int id);

  Future<RutaConductor> cambiarEstado(int id, EstadoRutaConductor estado);

  Future<ParadaConductor> marcarParada(
    int rutaId,
    int paradaId,
    bool recolectado,
  );

  /// POST /rutas/generar-mia. Lanza [ErrorGenerarMiRuta] (409: ya tiene
  /// una ruta en proceso hoy o no tiene camión; 422: no hay puntos llenos).
  Future<ResultadoGenerarMiRuta> generarMiRuta();
}

class RepositorioConductorApi implements RepositorioConductor {
  RepositorioConductorApi(this._dio);

  final Dio _dio;

  @override
  Future<List<RutaConductor>> misRutas() async {
    final respuesta = await _dio.get('/rutas/mias');
    return (respuesta.data as List)
        .map((e) => RutaConductor.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<RutaConductor> detalle(int id) async {
    final respuesta = await _dio.get('/rutas/$id');
    return RutaConductor.fromJson(respuesta.data as Map<String, dynamic>);
  }

  @override
  Future<RutaConductor> cambiarEstado(
    int id,
    EstadoRutaConductor estado,
  ) async {
    final respuesta = await _dio.patch(
      '/rutas/$id',
      data: {'estado': estadoRutaATexto(estado)},
    );
    return RutaConductor.fromJson(respuesta.data as Map<String, dynamic>);
  }

  @override
  Future<ParadaConductor> marcarParada(
    int rutaId,
    int paradaId,
    bool recolectado,
  ) async {
    final respuesta = await _dio.patch(
      '/rutas/$rutaId/paradas/$paradaId',
      data: {'recolectado': recolectado},
    );
    return ParadaConductor.fromJson(respuesta.data as Map<String, dynamic>);
  }

  @override
  Future<ResultadoGenerarMiRuta> generarMiRuta() async {
    try {
      final respuesta = await _dio.post('/rutas/generar-mia');
      return ResultadoGenerarMiRuta.fromJson(
        respuesta.data as Map<String, dynamic>,
      );
    } on DioException catch (error) {
      throw errorGenerarMiRutaDesde(error);
    }
  }
}

/// Repositorio en memoria para probar los flujos del conductor sin backend
/// (USE_MOCK=true). Usa los puntos críticos "EJEMPLO-0X" del mock de puntos
/// y la pantalla muestra el aviso "Datos de ejemplo".
class RepositorioConductorMock implements RepositorioConductor {
  RepositorioConductorMock({DateTime? hoy})
    : _rutas = crearRutasEjemplo(hoy ?? DateTime.now());

  final List<RutaConductor> _rutas;

  @override
  Future<List<RutaConductor>> misRutas() async =>
      List<RutaConductor>.unmodifiable(_rutas);

  @override
  Future<RutaConductor> detalle(int id) async => _rutaPorId(id);

  @override
  Future<RutaConductor> cambiarEstado(
    int id,
    EstadoRutaConductor estado,
  ) async {
    final actualizada = _rutaPorId(id).copiar(estado: estado);
    _reemplazarRuta(actualizada);
    return actualizada;
  }

  @override
  Future<ParadaConductor> marcarParada(
    int rutaId,
    int paradaId,
    bool recolectado,
  ) async {
    final ruta = _rutaPorId(rutaId);
    final indice = ruta.paradas.indexWhere((parada) => parada.id == paradaId);
    if (indice < 0) {
      throw StateError('No existe la parada solicitada.');
    }

    final actualizada = ruta.paradas[indice].copiar(recolectado: recolectado);
    final paradas = [...ruta.paradas]..[indice] = actualizada;
    _reemplazarRuta(ruta.copiar(paradas: paradas));
    return actualizada;
  }

  /// Como el backend: 409 si hoy ya hay una ruta en proceso, 422 si no hay
  /// puntos llenos (según los reportes de ejemplo). Reemplaza las rutas
  /// pendientes de hoy por una nueva con los puntos llenos.
  @override
  Future<ResultadoGenerarMiRuta> generarMiRuta() async {
    final ahora = DateTime.now();
    final deHoy = _rutas.where((ruta) => ruta.esDelDia(ahora)).toList();
    if (deHoy.any((ruta) => ruta.estado == EstadoRutaConductor.enProceso)) {
      throw const ErrorGenerarMiRuta(mensajeYaTieneRuta, codigo: 409);
    }
    final llenos = [
      for (final punto in RepositorioPuntosCriticosMock.todos)
        if (const {
          NivelLlenado.lleno,
          NivelLlenado.desbordado,
        }.contains(ReportesCampoEjemplo.ultimoDe(punto.codigo).estadoLlenado))
          punto.codigo,
    ];
    if (llenos.isEmpty) {
      throw const ErrorGenerarMiRuta(mensajeSinPuntosLlenos, codigo: 422);
    }
    final pendientes = deHoy
        .where((ruta) => ruta.estado == EstadoRutaConductor.pendiente)
        .map((ruta) => ruta.id)
        .toSet();
    _rutas.removeWhere((ruta) => pendientes.contains(ruta.id));
    final id =
        _rutas.fold(100, (maximo, ruta) => ruta.id > maximo ? ruta.id : maximo) +
        1;
    _rutas.insert(
      0,
      _rutaEjemplo(
        id: id,
        dia: DateTime(ahora.year, ahora.month, ahora.day),
        camion: _camionEjemplo,
        estado: EstadoRutaConductor.pendiente,
        codigos: llenos,
      ),
    );
    return ResultadoGenerarMiRuta(
      nroPuntos: llenos.length,
      metodoDistancia: 'ejemplo',
      rutasReemplazadas: pendientes.length,
      rutaId: id,
    );
  }

  RutaConductor _rutaPorId(int id) => _rutas.firstWhere(
    (ruta) => ruta.id == id,
    orElse: () => throw StateError('No existe la ruta solicitada.'),
  );

  void _reemplazarRuta(RutaConductor ruta) {
    final indice = _rutas.indexWhere((actual) => actual.id == ruta.id);
    _rutas[indice] = ruta;
  }
}

/// Dos rutas de ejemplo: una pendiente para [hoy] y una completada del día
/// anterior. Las paradas son los puntos "EJEMPLO-0X"; el llenado sale de
/// los reportes de ejemplo (o "Sin datos").
const _camionEjemplo = CamionConductor(
  id: 1,
  placa: 'EJEMPLO-1',
  turno: 'manana',
);

List<RutaConductor> crearRutasEjemplo(DateTime hoy) {
  const camion = _camionEjemplo;
  final dia = DateTime(hoy.year, hoy.month, hoy.day);
  final ayer = dia.subtract(const Duration(days: 1));
  return [
    _rutaEjemplo(
      id: 101,
      dia: dia,
      camion: camion,
      estado: EstadoRutaConductor.pendiente,
      codigos: const ['EJEMPLO-02', 'EJEMPLO-01', 'EJEMPLO-03', 'EJEMPLO-04'],
    ),
    _rutaEjemplo(
      id: 102,
      dia: ayer,
      camion: camion,
      estado: EstadoRutaConductor.completado,
      codigos: const ['EJEMPLO-05', 'EJEMPLO-03'],
      recolectadas: 2,
    ),
  ];
}

RutaConductor _rutaEjemplo({
  required int id,
  required DateTime dia,
  required CamionConductor camion,
  required EstadoRutaConductor estado,
  required List<String> codigos,
  int recolectadas = 0,
}) {
  final puntos = {
    for (final punto in RepositorioPuntosCriticosMock.todos)
      punto.codigo: punto,
  };
  return RutaConductor(
    id: id,
    fechaInicio: dia,
    fechaFin: dia,
    horaInicio: dia.add(const Duration(hours: 5)),
    horaFin: dia.add(const Duration(hours: 9)),
    camionId: camion.id,
    conductorId: 1,
    estado: estado,
    turno: 'manana',
    camion: camion,
    paradas: [
      for (var i = 0; i < codigos.length; i++)
        ParadaConductor(
          id: id * 10 + i + 1,
          rutaId: id,
          orden: i + 1,
          recolectado: i < recolectadas,
          puntoCriticoId: puntos[codigos[i]]!.id,
          puntoCritico: PuntoParada(
            id: puntos[codigos[i]]!.id ?? 0,
            codigo: codigos[i],
            direccion: puntos[codigos[i]]!.direccion,
            referencia: puntos[codigos[i]]!.referencia,
            lat: puntos[codigos[i]]!.latitud!,
            lon: puntos[codigos[i]]!.longitud!,
            priorizacionObligatoria:
                puntos[codigos[i]]!.priorizacionObligatoria,
            estadoLlenado: ReportesCampoEjemplo.ultimoDe(
              codigos[i],
            ).estadoLlenado,
          ),
        ),
    ],
  );
}
