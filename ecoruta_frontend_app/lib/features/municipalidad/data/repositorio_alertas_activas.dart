import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/app_config.dart';
import '../../../core/network/api_client.dart';
import 'modelos_alertas_activas.dart';
import 'repositorio_puntos_criticos.dart';

abstract interface class RepositorioAlertasActivas {
  /// GET /alertas/activas.
  Future<List<AlertaActiva>> listarActivas();
}

final repositorioAlertasActivasProvider = Provider<RepositorioAlertasActivas>(
  (ref) => AppConfig.usarDatosDeEjemplo
      ? RepositorioAlertasActivasMock()
      : RepositorioAlertasActivasApi(ref.read(dioProvider)),
);

class RepositorioAlertasActivasApi implements RepositorioAlertasActivas {
  RepositorioAlertasActivasApi(this._dio);

  final Dio _dio;

  @override
  Future<List<AlertaActiva>> listarActivas() async {
    final respuesta = await _dio.get('/alertas/activas');
    return alertasActivasDesdeJson(respuesta.data);
  }
}

/// Datos de ejemplo para USE_MOCK=true: una alerta del contenedor
/// prototipo de ejemplo ("EJEMPLO-PROTO"). El `tipo` real que usa el
/// backend está por confirmar; aquí se usa uno descriptivo.
class RepositorioAlertasActivasMock implements RepositorioAlertasActivas {
  RepositorioAlertasActivasMock({this.alertas});

  /// Lista fija (tests); sin ella se devuelve la alerta del prototipo.
  final List<AlertaActiva>? alertas;

  static AlertaActiva alertaPrototipo({DateTime? creadaEn}) {
    const punto = RepositorioPuntosCriticosMock.prototipo;
    return AlertaActiva(
      id: 1,
      tipo: 'contenedor_lleno',
      mensaje: 'Contenedor lleno (ejemplo)',
      nivelPct: 92,
      puntoCriticoId: punto.id,
      puntoCodigo: punto.codigo,
      direccion: punto.direccion,
      lat: punto.latitud,
      lon: punto.longitud,
      creadaEn:
          creadaEn ?? DateTime.now().subtract(const Duration(minutes: 10)),
    );
  }

  @override
  Future<List<AlertaActiva>> listarActivas() async {
    // Sin latencia simulada: se consulta en cada sondeo.
    return alertas ?? [alertaPrototipo()];
  }
}
