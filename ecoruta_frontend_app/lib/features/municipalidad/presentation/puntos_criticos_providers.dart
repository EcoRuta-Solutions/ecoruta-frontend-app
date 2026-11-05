import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/modelos_flota.dart';
import '../data/modelos_puntos_criticos.dart';
import '../data/repositorio_puntos_criticos.dart';
import '../data/repositorio_resumen_flota.dart';

/// Todos los puntos críticos (las páginas ya vienen unidas).
final puntosCriticosProvider = FutureProvider<List<PuntoCritico>>(
  (ref) => ref.watch(repositorioPuntosCriticosProvider).listarTodos(),
  retry: (_, _) => null,
);

final resumenPuntosCriticosProvider = FutureProvider<ResumenPuntosCriticos>(
  (ref) => ref.watch(repositorioPuntosCriticosProvider).resumen(),
  retry: (_, _) => null,
);

final detallePuntoCriticoProvider = FutureProvider.family
    .autoDispose<PuntoCritico?, String>(
      (ref, codigo) =>
          ref.watch(repositorioPuntosCriticosProvider).obtener(codigo),
      retry: (_, _) => null,
    );

final resumenFlotaProvider = FutureProvider<ResumenFlota>(
  (ref) => ref.watch(repositorioResumenFlotaProvider).cargar(),
  retry: (_, _) => null,
);
