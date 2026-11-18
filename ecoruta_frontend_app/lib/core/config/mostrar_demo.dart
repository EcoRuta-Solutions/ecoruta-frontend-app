import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app_config.dart';

/// Si se muestran las pantallas con datos simulados ("Contenedores · demo"
/// del mapa y "Contenedores" de Más). Ver [AppConfig.mostrarDemo]; se
/// sobrescribe en tests.
final mostrarDemoProvider = Provider<bool>((ref) => AppConfig.mostrarDemo);
