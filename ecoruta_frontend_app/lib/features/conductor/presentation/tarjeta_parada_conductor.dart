import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../municipalidad/presentation/hoja_reportar_llenado.dart';
import '../../municipalidad/presentation/widgets/visual_llenado.dart';
import '../data/modelos_conductor.dart';
import 'accesibilidad_conductor.dart';
import 'mis_rutas_controller.dart';
import 'navegacion_externa.dart';

/// Parada de la ruta del conductor: orden, código, dirección, referencia y
/// llenado del punto, con las acciones "Recolectada", "Cómo llegar" y
/// "Reportar llenado".
class TarjetaParadaConductor extends ConsumerWidget {
  const TarjetaParadaConductor({
    required this.ruta,
    required this.parada,
    this.alCambiar,
    super.key,
  });

  final RutaConductor ruta;
  final ParadaConductor parada;

  /// Se llama después de marcar la parada o de reportar el llenado.
  final VoidCallback? alCambiar;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final textos = Theme.of(context).textTheme;
    final hecho = Theme.of(context).extension<ColoresEstado>()!.normal;
    final punto = parada.puntoCritico;
    // Solo se marcan paradas de una ruta iniciada.
    final puedeMarcar = ruta.estado == EstadoRutaConductor.enProceso;

    Future<void> marcar() async {
      try {
        await ref
            .read(misRutasControllerProvider.notifier)
            .marcarParada(ruta.id, parada.id, !parada.recolectado);
        alCambiar?.call();
      } catch (_) {
        if (context.mounted) {
          _mostrarMensaje(context, 'No se pudo actualizar la parada.');
        }
      }
    }

    Future<void> comoLlegar() async {
      final abierto = await abrirNavegacionParada(parada);
      if (!abierto && context.mounted) {
        _mostrarMensaje(context, 'No se pudo abrir la navegación.');
      }
    }

    Future<void> reportar() async {
      final reporte = await mostrarHojaReportarLlenado(
        context,
        codigoPunto: punto!.codigo,
      );
      if (reporte == null) return;
      // Trae el llenado actualizado de las paradas.
      await ref.read(misRutasControllerProvider.notifier).recargar();
      alCambiar?.call();
    }

    return Card(
      key: ValueKey('parada-${parada.id}'),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: parada.recolectado
                      ? hecho.color
                      : EcoColors.primario,
                  child: parada.recolectado
                      ? const Icon(Icons.check_rounded, color: Colors.white)
                      : Text(
                          '${parada.orden}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        parada.codigo,
                        style: textos.titleMedium?.copyWith(
                          color: EcoColors.primario,
                        ),
                      ),
                      if (parada.direccion.isNotEmpty)
                        Text(parada.direccion, style: textos.bodyMedium),
                      if (punto?.referencia != null)
                        Text(
                          'Referencia: ${punto!.referencia}',
                          style: textos.bodySmall?.copyWith(
                            color: EcoColors.textoSecundario,
                          ),
                        ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          // Sin punto crítico no hay llenado: "Sin datos".
                          ChipLlenado(nivel: parada.estadoLlenado),
                          if (punto?.priorizacionObligatoria ?? false)
                            const _Etiqueta(texto: 'Prioritario'),
                          if (parada.recolectado)
                            const _Etiqueta(texto: 'Recolectada'),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (puedeMarcar)
                  semanticaBotonConductor(
                    etiqueta: parada.recolectado
                        ? 'Desmarcar parada ${parada.orden}'
                        : 'Marcar parada ${parada.orden} como recolectada',
                    child: FilledButton.tonalIcon(
                      style: estiloBotonConductor,
                      onPressed: marcar,
                      icon: Icon(
                        parada.recolectado
                            ? Icons.undo_rounded
                            : Icons.task_alt_rounded,
                      ),
                      label: Text(
                        parada.recolectado
                            ? 'Desmarcar'
                            : 'Marcar recolectada',
                      ),
                    ),
                  ),
                semanticaBotonConductor(
                  etiqueta: 'Cómo llegar a ${parada.codigo}',
                  child: OutlinedButton.icon(
                    style: estiloBotonConductor,
                    onPressed: parada.tieneUbicacion ? comoLlegar : null,
                    icon: const Icon(Icons.directions_rounded),
                    label: const Text('Cómo llegar'),
                  ),
                ),
                if (punto != null)
                  semanticaBotonConductor(
                    etiqueta: 'Reportar llenado de ${parada.codigo}',
                    child: OutlinedButton.icon(
                      style: estiloBotonConductor,
                      onPressed: reportar,
                      icon: const Icon(Icons.fact_check_outlined),
                      label: const Text('Reportar llenado'),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Etiqueta extends StatelessWidget {
  const _Etiqueta({required this.texto});

  final String texto;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
    decoration: BoxDecoration(
      color: EcoColors.borde,
      borderRadius: BorderRadius.circular(16),
    ),
    child: Text(
      texto,
      style: Theme.of(context).textTheme.labelMedium?.copyWith(
        color: EcoColors.primario,
        fontWeight: FontWeight.w700,
      ),
    ),
  );
}

void _mostrarMensaje(BuildContext context, String mensaje) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(mensaje)));
}
