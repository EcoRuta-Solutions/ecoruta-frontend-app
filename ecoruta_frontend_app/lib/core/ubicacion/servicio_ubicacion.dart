import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

/// Coordenadas del dispositivo en grados decimales.
typedef Coordenadas = ({double lat, double lon});

/// Ubicación opcional del dispositivo. Devuelve null cuando no se puede
/// usar (permiso denegado, GPS apagado, sin señal o plataforma sin soporte):
/// quien la pide sigue sin coordenadas en lugar de fallar.
abstract interface class ServicioUbicacion {
  Future<Coordenadas?> ubicacionActual();
}

final servicioUbicacionProvider = Provider<ServicioUbicacion>(
  (ref) => const ServicioUbicacionGeolocator(),
);

class ServicioUbicacionGeolocator implements ServicioUbicacion {
  const ServicioUbicacionGeolocator();

  /// Tiempo máximo de espera por una posición antes de seguir sin ella.
  static const limite = Duration(seconds: 10);

  @override
  Future<Coordenadas?> ubicacionActual() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) return null;
      var permiso = await Geolocator.checkPermission();
      if (permiso == LocationPermission.denied) {
        permiso = await Geolocator.requestPermission();
      }
      if (permiso == LocationPermission.denied ||
          permiso == LocationPermission.deniedForever ||
          permiso == LocationPermission.unableToDetermine) {
        return null;
      }
      final posicion = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: limite,
        ),
      );
      return (lat: posicion.latitude, lon: posicion.longitude);
    } catch (error) {
      // Sin ubicación el reporte se envía igual.
      debugPrint('Ubicación no disponible: $error');
      return null;
    }
  }
}
