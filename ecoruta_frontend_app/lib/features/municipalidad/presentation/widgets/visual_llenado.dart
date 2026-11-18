import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../data/modelos_reportes_campo.dart';

/// Color, fondo e ícono de cada nivel de llenado. Es la única fuente para el
/// mapa, el detalle del punto, la hoja "Reportar llenado" y el panel.
/// Cada nivel tiene un ícono distinto para no depender solo del color.
EstadoVisual visualLlenado(BuildContext context, NivelLlenado nivel) {
  final colores = Theme.of(context).extension<ColoresEstado>()!;
  return switch (nivel) {
    NivelLlenado.vacio => EstadoVisual(
      color: colores.normal.color,
      fondo: colores.normal.fondo,
      icono: Icons.hourglass_empty_rounded,
    ),
    NivelLlenado.medio => EstadoVisual(
      color: colores.alerta.color,
      fondo: colores.alerta.fondo,
      icono: Icons.hourglass_bottom_rounded,
    ),
    NivelLlenado.lleno => const EstadoVisual(
      color: Color(0xFFE5702A),
      fondo: Color(0xFFFDEEE4),
      icono: Icons.hourglass_full_rounded,
    ),
    NivelLlenado.desbordado => EstadoVisual(
      color: colores.critico.color,
      fondo: colores.critico.fondo,
      icono: Icons.warning_rounded,
    ),
    // Gris: no hay un reporte vigente, no se supone ningún nivel.
    NivelLlenado.sinDatos => EstadoVisual(
      color: colores.sinDatos.color,
      fondo: colores.sinDatos.fondo,
      icono: Icons.help_outline_rounded,
    ),
  };
}

/// Etiqueta con el ícono y el nombre del nivel ("Lleno", "Sin datos"...).
class ChipLlenado extends StatelessWidget {
  const ChipLlenado({required this.nivel, super.key});

  final NivelLlenado nivel;

  @override
  Widget build(BuildContext context) {
    final visual = visualLlenado(context, nivel);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: visual.fondo,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(visual.icono, size: 16, color: visual.color),
          const SizedBox(width: 6),
          Text(
            nivel.etiqueta,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: visual.color,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
