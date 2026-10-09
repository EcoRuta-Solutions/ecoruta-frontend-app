import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../data/modelos_panel.dart';

class ChipEstado extends StatelessWidget {
  const ChipEstado({required this.estado, super.key});

  final EstadoNodo estado;

  @override
  Widget build(BuildContext context) {
    final visual = Theme.of(context).extension<ColoresEstado>()!.para(estado);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: visual.fondo,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(visual.icono, size: 14, color: visual.color),
          const SizedBox(width: 8),
          Text(
            switch (estado) {
              EstadoNodo.critico => 'Crítico',
              EstadoNodo.alerta => 'Alerta',
              EstadoNodo.normal => 'Normal',
              EstadoNodo.sinDatos => 'Sin datos',
            },
            style: Theme.of(context).textTheme.labelSmall
                ?.copyWith(color: visual.color, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}
