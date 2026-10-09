import 'package:flutter/foundation.dart';

class AppConfig {
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