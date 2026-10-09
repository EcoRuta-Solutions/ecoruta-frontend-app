import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../data/modelos_alerta.dart';
import '../../data/modelos_panel.dart';
import '../panel_utils.dart';

class TarjetaAlerta extends StatelessWidget {
  const TarjetaAlerta({
    required this.alerta,
    required this.nodo,
    required this.onTap,
    super.key,
  });

  final AlertaPanel alerta;
  final NodoEstado nodo;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colores = Theme.of(context).extension<ColoresEstado>()!;
    final visual = colores.para(nodo.estado);
    final motivo = _motivo(context, alerta.tipo);
    final proceso = Theme.of(context).extension<ColoresProceso>()!;
    final estadoAlerta = switch (alerta.estado) {
      EstadoAlerta.nueva => EstadoProcesoPanel.nueva,
      EstadoAlerta.reconocida => EstadoProcesoPanel.reconocida,
      EstadoAlerta.asignada => EstadoProcesoPanel.asignada,
      EstadoAlerta.atendida => EstadoProcesoPanel.atendida,
    };
    final estadoVisual = proceso.para(estadoAlerta);

    return Semantics(
      button: true,
      label:
          'Alerta ${_nombreTipo(alerta.tipo)}: ${nodo.nombre}, ${nodo.codigo}, '
          '${nodo.llenado?.round() ?? 'sin dato'} por ciento',
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            nodo.nombre,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(color: EcoColors.texto),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            nodo.codigo,
                            style: Theme.of(context).textTheme.labelMedium
                                ?.copyWith(color: EcoColors.textoSecundario),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Icon(visual.icono, color: visual.color, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      nodo.llenado == null ? '—' : '${nodo.llenado!.round()}%',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: visual.color,
                        fontWeight: FontWeight.w700,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _MotivoAlerta(
                      texto: _nombreTipo(alerta.tipo),
                      color: motivo.color,
                      fondo: motivo.fondo,
                      icono: motivo.icono,
                    ),
                    _MotivoAlerta(
                      texto: _nombreEstado(alerta.estado),
                      color: estadoVisual.color,
                      fondo: estadoVisual.fondo,
                      icono: estadoVisual.icono,
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Icon(
                      Icons.schedule_rounded,
                      size: 16,
                      color: EcoColors.textoSecundario,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      tiempoDesdeLectura(nodo.ultimaLectura),
                      style: Theme.of(context).textTheme.labelMedium
                          ?.copyWith(color: EcoColors.textoSecundario),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

EstadoVisual _motivo(BuildContext context, TipoAlerta tipo) {
  final extension = Theme.of(context).extension<ColoresEstado>()!;
  return switch (tipo) {
    TipoAlerta.critico => extension.critico,
    TipoAlerta.enAlerta ||
    TipoAlerta.volteado ||
    TipoAlerta.bateriaBaja => extension.alerta,
    TipoAlerta.sinDatos => extension.sinDatos,
  };
}

String _nombreTipo(TipoAlerta tipo) => switch (tipo) {
  TipoAlerta.critico => 'Crítico',
  TipoAlerta.enAlerta => 'En alerta',
  TipoAlerta.volteado => 'Contenedor volteado',
  TipoAlerta.bateriaBaja => 'Batería baja',
  TipoAlerta.sinDatos => 'Sin datos',
};

String _nombreEstado(EstadoAlerta estado) => switch (estado) {
  EstadoAlerta.nueva => 'Nueva',
  EstadoAlerta.reconocida => 'Reconocida',
  EstadoAlerta.asignada => 'Asignada',
  EstadoAlerta.atendida => 'Atendida',
};

class _MotivoAlerta extends StatelessWidget {
  const _MotivoAlerta({
    required this.texto,
    required this.color,
    required this.fondo,
    required this.icono,
  });

  final String texto;
  final Color color;
  final Color fondo;
  final IconData icono;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 40),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: fondo,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icono, size: 16, color: color),
          const SizedBox(width: 8),
          Text(
            texto,
            style: Theme.of(context).textTheme.labelMedium
                ?.copyWith(color: color, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}
