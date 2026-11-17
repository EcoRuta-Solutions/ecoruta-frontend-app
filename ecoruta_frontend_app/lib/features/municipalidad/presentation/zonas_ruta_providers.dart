import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/presentation/auth_controller.dart';
import '../data/modelos_zonas_ruta.dart';
import '../data/repositorio_zonas_ruta.dart';

/// Zonas de ruta de un turno (GET /zonas-ruta?turno=...). Cada pestaña
/// carga la suya; al volver a una pestaña ya cargada no se repite la petición.
final zonasRutaPorTurnoProvider = FutureProvider.family<List<ZonaRuta>, TurnoZona>(
  (ref, turno) => ref.watch(repositorioZonasRutaProvider).listar(turno: turno),
  retry: (_, _) => null,
);

/// Hora actual. Se sobrescribe en los tests para fijar el reloj.
final relojZonasRutaProvider = Provider<DateTime Function()>(
  (ref) => DateTime.now,
);

/// La zona activa solo se resalta para el rol municipalidad.
final resaltarZonaActivaProvider = Provider<bool>(
  (ref) =>
      ref.watch(authProvider.select((auth) => auth.user?.rol)) ==
      'municipalidad',
);
