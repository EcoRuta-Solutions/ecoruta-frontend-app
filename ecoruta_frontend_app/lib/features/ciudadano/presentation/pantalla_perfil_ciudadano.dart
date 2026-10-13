import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../auth/presentation/auth_controller.dart';

class PantallaPerfilCiudadano extends ConsumerWidget {
  const PantallaPerfilCiudadano({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final usuario = ref.watch(authProvider).user;

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
                        usuario?.nombre ?? 'Ciudadano',
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
                          'Ciudadano',
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
        OutlinedButton.icon(
          style: const ButtonStyle(
            minimumSize: WidgetStatePropertyAll<Size>(Size.fromHeight(52)),
          ),
          onPressed: () => ref.read(authProvider.notifier).logout(),
          icon: const Icon(Icons.logout_rounded),
          label: const Text('Cerrar sesión'),
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
