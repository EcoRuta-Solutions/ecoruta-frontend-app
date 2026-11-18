import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../conductor/data/modelos_conductor.dart';
import '../data/modelos_generacion_rutas.dart';
import '../data/repositorio_rutas_turno.dart';

/// Rutas del día (GET /rutas/hoy).
final rutasHoyProvider = FutureProvider<List<RutaConductor>>(
  (ref) => ref.watch(repositorioRutasTurnoProvider).rutasDeHoy(),
  retry: (_, _) => null,
);

/// Última generación de rutas de esta sesión: null antes de generar,
/// cargando, error ([ErrorGeneracionRutas]) o el resultado.
final generacionRutasProvider =
    NotifierProvider<
      GeneracionRutasController,
      AsyncValue<ResultadoGeneracionRutas>?
    >(GeneracionRutasController.new);

class GeneracionRutasController
    extends Notifier<AsyncValue<ResultadoGeneracionRutas>?> {
  @override
  AsyncValue<ResultadoGeneracionRutas>? build() => null;

  Future<void> generar(SolicitudGenerarRutas solicitud) async {
    state = const AsyncLoading();
    try {
      final resultado = await ref
          .read(repositorioRutasTurnoProvider)
          .generar(solicitud);
      state = AsyncData(resultado);
      ref.invalidate(rutasHoyProvider);
    } catch (error, pila) {
      state = AsyncError(error, pila);
    }
  }
}
