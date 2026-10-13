import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../auth/presentation/auth_controller.dart';
import '../data/modelos_ciudadano.dart';
import 'estado_visual_ciudadano.dart';
import 'mis_reportes_controller.dart';
import 'navegacion_ciudadano_controller.dart';

class PantallaInicioCiudadanoTab extends ConsumerWidget {
  const PantallaInicioCiudadanoTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final usuario = ref.watch(authProvider).user;
    final reportes =
        ref.watch(misReportesControllerProvider).asData?.value ?? const [];
    final enProceso = reportes
        .where((r) => r.estado != EstadoReporteCiudadano.resuelto)
        .length;
    final resueltos = reportes
        .where((r) => r.estado == EstadoReporteCiudadano.resuelto)
        .length;
    final recientes = reportes.take(3).toList();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          'Hola, ${usuario?.nombre ?? ''}',
          style: Theme.of(context).textTheme.headlineSmall
              ?.copyWith(color: EcoColors.primario, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 4),
        Text(
          'Reporta incidencias de limpieza en tu zona.',
          style: Theme.of(context).textTheme.bodyMedium
              ?.copyWith(color: EcoColors.textoSecundario),
        ),
        const SizedBox(height: 20),
        Row(
          children: [
            _Resumen(
              valor: '${reportes.length}',
              etiqueta: 'Reportes',
              icono: Icons.receipt_long_rounded,
              color: EcoColors.primario,
            ),
            const SizedBox(width: 12),
            _Resumen(
              valor: '$enProceso',
              etiqueta: 'En proceso',
              icono: Icons.hourglass_top_rounded,
              color: EcoColors.acento,
            ),
            const SizedBox(width: 12),
            _Resumen(
              valor: '$resueltos',
              etiqueta: 'Resueltos',
              icono: Icons.task_alt_rounded,
              color: const Color(0xFF30A46C),
            ),
          ],
        ),
        const SizedBox(height: 20),
        FilledButton.icon(
          style: const ButtonStyle(
            minimumSize: WidgetStatePropertyAll<Size>(Size.fromHeight(52)),
          ),
          onPressed: () => ref
              .read(navegacionCiudadanoProvider.notifier)
              .seleccionar(DestinoCiudadano.reportar),
          icon: const Icon(Icons.add_location_alt_rounded),
          label: const Text('Reportar incidencia'),
        ),
        const SizedBox(height: 24),
        Row(
          children: [
            Expanded(
              child: Text(
                'Mis últimos reportes',
                style: Theme.of(context).textTheme.titleMedium
                    ?.copyWith(color: EcoColors.primario),
              ),
            ),
            TextButton(
              onPressed: () => ref
                  .read(navegacionCiudadanoProvider.notifier)
                  .seleccionar(DestinoCiudadano.misReportes),
              child: const Text('Ver todos'),
            ),
          ],
        ),
        const SizedBox(height: 4),
        if (recientes.isEmpty)
          const Card(
            child: Padding(
              padding: EdgeInsets.all(20),
              child: Text('Aún no has enviado reportes.'),
            ),
          )
        else
          for (final reporte in recientes)
            Card(
              margin: const EdgeInsets.only(bottom: 12),
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                leading: Icon(
                  Icons.location_on_rounded,
                  color: visualReporteCiudadano(context, reporte.estado).color,
                ),
                title: Text(
                  reporte.descripcion,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: Text(formatearFechaCorta(reporte.fecha)),
                trailing: ChipEstadoReporte(estado: reporte.estado),
              ),
            ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '¿Cómo funciona?',
                  style: Theme.of(context).textTheme.titleMedium
                      ?.copyWith(color: EcoColors.primario),
                ),
                const SizedBox(height: 12),
                const _Paso(
                  icono: Icons.add_location_alt_rounded,
                  texto: 'Elige la ubicación en el mapa y describe el problema.',
                ),
                const SizedBox(height: 12),
                const _Paso(
                  icono: Icons.send_rounded,
                  texto: 'La municipalidad recibe tu reporte al instante.',
                ),
                const SizedBox(height: 12),
                const _Paso(
                  icono: Icons.task_alt_rounded,
                  texto: 'Sigue el estado hasta que sea atendido.',
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _Resumen extends StatelessWidget {
  const _Resumen({
    required this.valor,
    required this.etiqueta,
    required this.icono,
    required this.color,
  });

  final String valor;
  final String etiqueta;
  final IconData icono;
  final Color color;

  @override
  Widget build(BuildContext context) => Expanded(
    child: Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
        child: Column(
          children: [
            Icon(icono, color: color),
            const SizedBox(height: 8),
            Text(
              valor,
              style: Theme.of(context).textTheme.titleLarge
                  ?.copyWith(color: EcoColors.texto),
            ),
            const SizedBox(height: 2),
            Text(
              etiqueta,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.labelMedium
                  ?.copyWith(color: EcoColors.textoSecundario),
            ),
          ],
        ),
      ),
    ),
  );
}

class _Paso extends StatelessWidget {
  const _Paso({required this.icono, required this.texto});

  final IconData icono;
  final String texto;

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Icon(icono, color: EcoColors.acento, size: 20),
      const SizedBox(width: 12),
      Expanded(child: Text(texto)),
    ],
  );
}
