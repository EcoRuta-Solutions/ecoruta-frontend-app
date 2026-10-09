import '../data/modelos_panel.dart';

List<NodoEstado> alertasActivas(List<NodoEstado> nodos) {
  final alertas =
      nodos
          .where(
            (nodo) =>
                nodo.estado == EstadoNodo.critico ||
                nodo.estado == EstadoNodo.alerta ||
                nodo.volteado == true,
          )
          .toList()
        ..sort((a, b) {
          final gravedad = a.estado.index.compareTo(b.estado.index);
          if (gravedad != 0) return gravedad;
          return (b.llenado ?? -1).compareTo(a.llenado ?? -1);
        });
  return alertas;
}

String tiempoDesdeLectura(DateTime? ultimaLectura, {DateTime? ahora}) {
  if (ultimaLectura == null) return 'Sin lectura';
  return formatearTiempoRelativo(ultimaLectura, ahora: ahora ?? DateTime.now());
}

String formatearTiempoRelativo(DateTime fecha, {required DateTime ahora}) {
  final diferencia = ahora.difference(fecha);
  if (diferencia.isNegative) return 'ahora';
  if (diferencia.inMinutes < 1) return 'hace <1 min';
  if (diferencia.inHours < 1) return 'hace ${diferencia.inMinutes} min';
  if (diferencia.inDays < 1) return 'hace ${diferencia.inHours} h';
  return 'hace ${diferencia.inDays} d';
}
