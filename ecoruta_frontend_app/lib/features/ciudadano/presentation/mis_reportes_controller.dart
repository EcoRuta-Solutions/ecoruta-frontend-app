import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/modelos_ciudadano.dart';
import '../data/repositorio_ciudadano.dart';

final misReportesControllerProvider =
    AsyncNotifierProvider<MisReportesController, List<ReporteCiudadanoApp>>(
      MisReportesController.new,
      retry: (_, _) => null,
    );

class MisReportesController extends AsyncNotifier<List<ReporteCiudadanoApp>> {
  RepositorioCiudadano get _repositorio =>
      ref.read(repositorioCiudadanoProvider);

  @override
  Future<List<ReporteCiudadanoApp>> build() =>
      ref.watch(repositorioCiudadanoProvider).misReportes();

  Future<void> reportar({
    required double latitud,
    required double longitud,
    required String descripcion,
  }) async {
    await _repositorio.crearReporte(
      latitud: latitud,
      longitud: longitud,
      descripcion: descripcion,
    );
    state = AsyncData(await _repositorio.misReportes());
  }

  Future<void> recargar() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => _repositorio.misReportes());
  }
}
