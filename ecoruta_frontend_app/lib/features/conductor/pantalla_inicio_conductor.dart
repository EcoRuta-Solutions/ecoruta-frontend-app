import 'package:flutter/material.dart';

import '../../core/widgets/pantalla_temporal.dart';

class PantallaInicioConductor extends StatelessWidget {
  const PantallaInicioConductor({super.key});

  @override
  Widget build(BuildContext context) {
    return const PantallaTemporal(
      titulo: 'Mi ruta',
      icono: Icons.local_shipping_outlined,
    );
  }
}