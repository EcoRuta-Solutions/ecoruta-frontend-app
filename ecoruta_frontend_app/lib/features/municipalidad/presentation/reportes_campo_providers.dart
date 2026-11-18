import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/modelos_reportes_campo.dart';
import '../data/repositorio_reportes_campo.dart';
import 'puntos_criticos_providers.dart';

/// GET /reportes-campo/resumen: puntos por estado de llenado y sin datos.
final resumenReportesProvider = FutureProvider<ResumenReportes>(
  (ref) => ref.watch(repositorioReportesCampoProvider).resumen(),
  retry: (_, _) => null,
);

/// Último reporte de un punto, para su detalle.
final ultimoReportePuntoProvider = FutureProvider.family
    .autoDispose<UltimoReportePunto, String>(
      (ref, codigo) =>
          ref.watch(repositorioReportesCampoProvider).ultimoReporte(codigo),
      retry: (_, _) => null,
    );

/// Hora actual para "hace X horas". Se sobrescribe en los tests.
final relojReportesProvider = Provider<DateTime Function()>(
  (ref) => DateTime.now,
);

/// Tras un reporte: refresca el mapa, el detalle del punto y el resumen.
void refrescarTrasReporte(WidgetRef ref, String codigo) {
  ref
    ..invalidate(ultimoReportePuntoProvider(codigo))
    ..invalidate(puntosCriticosProvider)
    ..invalidate(resumenReportesProvider);
}
