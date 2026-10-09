import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../data/modelos_panel.dart';
import 'barra_llenado.dart';
import 'chip_estado.dart';

class TarjetaContenedor extends StatelessWidget {
  const TarjetaContenedor({required this.nodo, required this.onTap, super.key});

  final NodoEstado nodo;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final coloresEstado = Theme.of(context).extension<ColoresEstado>()!;
    final visual = Theme.of(context)
        .extension<ColoresEstado>()!
        .para(nodo.estado);
    final ultimaLectura = nodo.ultimaLectura;
    final hace = ultimaLectura == null
        ? 'Sin lectura'
        : _textoHace(DateTime.now().difference(ultimaLectura).inMinutes);

    return Semantics(
      button: true,
      label:
          '${nodo.nombre}, ${nodo.codigo}, '
          '${nodo.llenado?.round() ?? 'sin dato'} por ciento, '
          '${nodo.estado.name}',
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
                    if (nodo.volteado == true) ...[
                      Tooltip(
                        message: 'Contenedor volteado',
                        child: Icon(
                          coloresEstado.alerta.icono,
                          color: coloresEstado.alerta.color,
                          size: 18,
                        ),
                      ),
                      const SizedBox(width: 8),
                    ],
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
                BarraLlenado(llenado: nodo.llenado, estado: nodo.estado),
                const SizedBox(height: 16),
                Row(
                  children: [
                    ChipEstado(estado: nodo.estado),
                    const Spacer(),
                    Icon(
                      Icons.schedule_rounded,
                      size: 15,
                      color: EcoColors.textoSecundario,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      hace,
                      style: Theme.of(context).textTheme.labelSmall
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

  String _textoHace(int minutos) {
    if (minutos <= 0) return 'hace <1 min';
    return 'hace $minutos min';
  }
}
