import '../../../core/navegacion/navegacion_externa.dart';
import '../data/modelos_conductor.dart';

/// Abre la app de mapas hacia el punto de la parada. Devuelve false si la
/// parada no tiene ubicación o no se pudo abrir.
Future<bool> abrirNavegacionParada(ParadaConductor parada) async {
  final lat = parada.latitud;
  final lon = parada.longitud;
  if (lat == null || lon == null) return false;
  return abrirComoLlegar(
    latitud: lat,
    longitud: lon,
    nombre: parada.direccion.isEmpty ? parada.codigo : parada.direccion,
  );
}
