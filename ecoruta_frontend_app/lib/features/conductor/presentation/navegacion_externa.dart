import '../../../core/navegacion/navegacion_externa.dart';
import '../data/modelos_conductor.dart';

Future<bool> abrirNavegacionExterna(NodoConductor nodo) => abrirComoLlegar(
  latitud: nodo.latitud,
  longitud: nodo.longitud,
  nombre: nodo.nombre,
);
