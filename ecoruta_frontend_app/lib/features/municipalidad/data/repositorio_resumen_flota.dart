import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/app_config.dart';
import '../../../core/network/api_client.dart';
import 'modelos_flota.dart';

abstract interface class RepositorioResumenFlota {
  Future<ResumenFlota> cargar();
}

final repositorioResumenFlotaProvider = Provider<RepositorioResumenFlota>(
  (ref) => AppConfig.usarDatosDeEjemplo
      ? RepositorioResumenFlotaMock()
      : RepositorioResumenFlotaApi(ref.read(dioProvider)),
);

/// GET /flota/resumen (solo municipalidad). Se usa el valor por defecto del
/// backend para `incluir_demo`; el panel avisa cuántos camiones son demo.
class RepositorioResumenFlotaApi implements RepositorioResumenFlota {
  RepositorioResumenFlotaApi(this._dio);

  final Dio _dio;

  @override
  Future<ResumenFlota> cargar() async {
    final respuesta = await _dio.get('/flota/resumen');
    return ResumenFlota.fromJson(respuesta.data as Map<String, dynamic>);
  }
}

/// Resumen de flota de ejemplo para USE_MOCK=true.
class RepositorioResumenFlotaMock implements RepositorioResumenFlota {
  static const resumen = ResumenFlota(
    total: 6,
    porEstado: ConteoEstadosFlota(
      operativo: 4,
      reserva: 1,
      mantenimiento: 1,
      total: 6,
    ),
    porTurno: {
      TurnoFlota.manana: ConteoEstadosFlota(operativo: 2, reserva: 1, total: 3),
      TurnoFlota.tarde: ConteoEstadosFlota(
        operativo: 1,
        mantenimiento: 1,
        total: 2,
      ),
      TurnoFlota.noche: ConteoEstadosFlota(operativo: 1, total: 1),
    },
    demo: 6,
  );

  @override
  Future<ResumenFlota> cargar() async {
    await Future<void>.delayed(const Duration(milliseconds: 300));
    return resumen;
  }
}
