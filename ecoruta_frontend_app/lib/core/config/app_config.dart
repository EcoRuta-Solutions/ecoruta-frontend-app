import 'package:flutter/foundation.dart';

class AppConfig {
  static const bool usarDatosDeEjemplo =
      bool.fromEnvironment('USE_MOCK', defaultValue: true);

  /// Muestra pantallas con datos simulados (la capa "Contenedores · demo"
  /// del mapa y la opción "Contenedores" de Más). Apagado en la app real para no presentarlos como
  /// operativos: flutter run --dart-define=MOSTRAR_DEMO=true lo enciende.
  /// Con USE_MOCK=true siempre se muestran.
  static const bool mostrarDemo =
      usarDatosDeEjemplo ||
      bool.fromEnvironment('MOSTRAR_DEMO', defaultValue: false);

  // Para un celular real: flutter run --dart-define=API_URL=http://TU_IP:8000
  static const String _override = String.fromEnvironment('API_URL');

  static String get baseUrl {
    if (_override.isNotEmpty) return _override;
    if (kIsWeb) return 'http://localhost:8000';
    if (defaultTargetPlatform == TargetPlatform.android) {
      return 'http://10.0.2.2:8000'; // emulador Android
    }
    return 'http://localhost:8000';
  }
}