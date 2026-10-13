import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../data/modelos_ciudadano.dart';

EstadoProcesoPanel _proceso(EstadoReporteCiudadano estado) => switch (estado) {
  EstadoReporteCiudadano.recibido => EstadoProcesoPanel.recibido,
  EstadoReporteCiudadano.enAtencion => EstadoProcesoPanel.enAtencion,
  EstadoReporteCiudadano.resuelto => EstadoProcesoPanel.resuelto,
};

EstadoVisual visualReporteCiudadano(
  BuildContext context,
  EstadoReporteCiudadano estado,
) => Theme.of(context).extension<ColoresProceso>()!.para(_proceso(estado));

String etiquetaEstadoReporte(EstadoReporteCiudadano estado) => switch (estado) {
  EstadoReporteCiudadano.recibido => 'Recibido',
  EstadoReporteCiudadano.enAtencion => 'En atención',
  EstadoReporteCiudadano.resuelto => 'Resuelto',
};

String formatearFechaCorta(DateTime fecha) =>
    '${fecha.day.toString().padLeft(2, '0')}/'
    '${fecha.month.toString().padLeft(2, '0')}/${fecha.year}';

class ChipEstadoReporte extends StatelessWidget {
  const ChipEstadoReporte({super.key, required this.estado});

  final EstadoReporteCiudadano estado;

  @override
  Widget build(BuildContext context) {
    final visual = visualReporteCiudadano(context, estado);
    return Container(
      constraints: const BoxConstraints(minHeight: 36),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: visual.fondo,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(visual.icono, size: 16, color: visual.color),
          const SizedBox(width: 6),
          Text(
            etiquetaEstadoReporte(estado),
            style: TextStyle(color: visual.color, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}
