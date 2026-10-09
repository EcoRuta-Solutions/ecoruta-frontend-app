import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../data/modelos_panel.dart';

class BarraLlenado extends StatelessWidget {
  const BarraLlenado({required this.llenado, required this.estado, super.key});

  final double? llenado;
  final EstadoNodo estado;

  @override
  Widget build(BuildContext context) {
    final visual = Theme.of(context).extension<ColoresEstado>()!.para(estado);
    final valor = llenado?.clamp(0, 100).toDouble() ?? 0;

    return Semantics(
      label: llenado == null
          ? 'Llenado sin datos'
          : 'Llenado ${valor.round()} por ciento',
      value: llenado == null ? null : '${valor.round()}%',
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: valor / 100),
        duration: const Duration(milliseconds: 420),
        curve: Curves.easeOutCubic,
        builder: (context, progreso, _) => ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: LinearProgressIndicator(
            value: progreso,
            minHeight: 8,
            color: visual.color,
            backgroundColor: visual.fondo,
          ),
        ),
      ),
    );
  }
}
