import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/modelos_conductor.dart';
import '../data/repositorio_conductor.dart';

final misRutasControllerProvider =
    AsyncNotifierProvider<MisRutasController, List<RutaConductor>>(
      MisRutasController.new,
      retry: (_, _) => null,
    );

class MisRutasController extends AsyncNotifier<List<RutaConductor>> {
  @override
  Future<List<RutaConductor>> build() =>
      ref.watch(repositorioConductorProvider).misRutas();

  Future<void> recargar() async {
    state = const AsyncLoading<List<RutaConductor>>();
    state = await AsyncValue.guard(
      () => ref.read(repositorioConductorProvider).misRutas(),
    );
  }

  Future<void> cambiarEstado(int id, EstadoRutaConductor estado) async {
    await ref.read(repositorioConductorProvider).cambiarEstado(id, estado);
    await recargar();
  }

  Future<void> marcarParada(int rutaId, int paradaId, bool recolectado) async {
    await ref
        .read(repositorioConductorProvider)
        .marcarParada(rutaId, paradaId, recolectado);
    await recargar();
  }
}

/// Detalle de una ruta puntual para la pantalla de paradas.
final detalleRutaProvider = FutureProvider.autoDispose
    .family<RutaConductor, int>(
      (ref, id) => ref.watch(repositorioConductorProvider).detalle(id),
    );
