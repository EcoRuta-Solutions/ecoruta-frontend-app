import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../auth/presentation/auth_controller.dart';
import '../data/modelos_conductor.dart';
import 'accesibilidad_conductor.dart';
import 'mis_rutas_controller.dart';

class PantallaMasConductor extends ConsumerWidget {
  const PantallaMasConductor({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final usuario = ref.watch(authProvider).user;
    final rutas =
        ref.watch(misRutasControllerProvider).asData?.value ?? const [];

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor: EcoColors.acento.withValues(alpha: 0.15),
                  child: Text(
                    _iniciales(usuario?.nombre ?? 'C'),
                    style: const TextStyle(
                      color: EcoColors.primario,
                      fontWeight: FontWeight.w700,
                      fontSize: 20,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        usuario?.nombre ?? 'Conductor',
                        style: Theme.of(context).textTheme.titleLarge
                            ?.copyWith(color: EcoColors.primario),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        usuario?.email ?? '',
                        style: Theme.of(context).textTheme.bodyMedium
                            ?.copyWith(color: EcoColors.textoSecundario),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: EcoColors.acento.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          'Conductor',
                          style: Theme.of(context).textTheme.labelMedium
                              ?.copyWith(color: EcoColors.acento),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),
        Text(
          'Historial de rutas',
          style: Theme.of(context).textTheme.titleMedium
              ?.copyWith(color: EcoColors.primario),
        ),
        const SizedBox(height: 12),
        if (rutas.isEmpty)
          const Card(
            child: Padding(
              padding: EdgeInsets.all(20),
              child: Text('Aún no tienes rutas registradas.'),
            ),
          )
        else
          Card(
            child: Column(
              children: [
                for (final ruta in rutas)
                  ListTile(
                    leading: const Icon(
                      Icons.route_rounded,
                      color: EcoColors.primario,
                    ),
                    title: Text(
                      'Ruta #${ruta.id} · ${ruta.camion?.placa ?? 'Sin camión'}',
                    ),
                    subtitle: Text(
                      '${_fecha(ruta.fechaInicio)} · '
                      '${etiquetaEstadoRuta(ruta.estado)} · '
                      '${ruta.paradasHechas}/${ruta.paradasTotal} paradas',
                    ),
                  ),
              ],
            ),
          ),
        const SizedBox(height: 24),
        semanticaBotonConductor(
          etiqueta: 'Cerrar sesión',
          child: OutlinedButton.icon(
            style: estiloBotonConductor,
            onPressed: () => ref.read(authProvider.notifier).logout(),
            icon: const Icon(Icons.logout_rounded),
            label: const Text('Cerrar sesión'),
          ),
        ),
      ],
    );
  }
}

String _iniciales(String nombre) {
  final partes = nombre.trim().split(RegExp(r'\s+'));
  if (partes.isEmpty || partes.first.isEmpty) return 'C';
  if (partes.length == 1) return partes.first[0].toUpperCase();
  return '${partes.first[0]}${partes.last[0]}'.toUpperCase();
}

String _fecha(DateTime fecha) =>
    '${fecha.day.toString().padLeft(2, '0')}/'
    '${fecha.month.toString().padLeft(2, '0')}/${fecha.year}';
