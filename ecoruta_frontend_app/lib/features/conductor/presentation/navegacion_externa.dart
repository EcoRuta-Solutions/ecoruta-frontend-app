import 'package:url_launcher/url_launcher.dart';

import '../data/modelos_conductor.dart';

Future<bool> abrirNavegacionExterna(NodoConductor nodo) async {
  final coordenadas = '${nodo.latitud},${nodo.longitud}';
  final geoUri = Uri(
    scheme: 'geo',
    path: coordenadas,
    queryParameters: {'q': '$coordenadas(${nodo.nombre})'},
  );

  if (await canLaunchUrl(geoUri) &&
      await launchUrl(geoUri, mode: LaunchMode.externalApplication)) {
    return true;
  }

  final mapsUri = Uri.https('www.google.com', '/maps/dir/', {
    'api': '1',
    'destination': coordenadas,
  });
  return launchUrl(mapsUri, mode: LaunchMode.externalApplication);
}
