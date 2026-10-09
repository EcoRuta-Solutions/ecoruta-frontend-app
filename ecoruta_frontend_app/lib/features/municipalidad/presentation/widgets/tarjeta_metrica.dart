import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../data/modelos_panel.dart';

class TarjetaMetrica extends StatelessWidget {
  const TarjetaMetrica({
    required this.etiqueta,
    required this.valor,
    required this.estado,
    super.key,
  });

  final String etiqueta;
  final int valor;
  final EstadoNodo estado;

  @override
  Widget build(BuildContext context) {
    final visual = Theme.of(context).extension<ColoresEstado>()!.para(estado);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: visual.fondo,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(visual.icono, color: visual.color, size: 19),
            ),
            const Spacer(),
            Text(
              '$valor',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                color: EcoColors.texto,
                fontWeight: FontWeight.w700,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              etiqueta,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelLarge
                  ?.copyWith(color: EcoColors.textoSecundario),
            ),
          ],
        ),
      ),
    );
  }
}
