import 'package:url_launcher/url_launcher.dart';

/// Abre la app de mapas del teléfono con indicaciones hasta un punto.
/// Intenta primero `geo:` y, si no hay app que lo atienda, Google Maps web.
Future<bool> abrirComoLlegar({
  required double latitud,
  required double longitud,
  required String nombre,
}) async {
  final coordenadas = '$latitud,$longitud';
  final geoUri = Uri(
    scheme: 'geo',
    path: coordenadas,
    queryParameters: {'q': '$coordenadas($nombre)'},
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
