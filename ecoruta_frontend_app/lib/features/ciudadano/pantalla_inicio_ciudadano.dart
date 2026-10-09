import 'package:flutter/material.dart';

import '../../core/widgets/pantalla_temporal.dart';

class PantallaInicioCiudadano extends StatelessWidget {
  const PantallaInicioCiudadano({super.key});

  @override
  Widget build(BuildContext context) {
    return const PantallaTemporal(
      titulo: 'Ciudadano',
      icono: Icons.campaign_outlined,
    );
  }
}