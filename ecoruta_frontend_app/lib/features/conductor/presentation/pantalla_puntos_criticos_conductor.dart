import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../municipalidad/presentation/mapa_puntos_criticos.dart';

/// Mapa de puntos críticos para el conductor. Reutiliza el del panel
/// municipal: al tocar un punto se ve su llenado y se puede reportar.
class PantallaPuntosCriticosConductor extends StatelessWidget {
  const PantallaPuntosCriticosConductor({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      backgroundColor: EcoColors.fondo,
      title: const Text('Puntos críticos'),
    ),
    body: const MapaPuntosCriticos(margenSuperior: 0),
  );
}
