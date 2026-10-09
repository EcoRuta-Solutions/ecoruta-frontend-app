import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/auth/presentation/auth_controller.dart';
import '../theme/app_theme.dart';

/// Pantalla provisional para cada rol. Se reemplaza por las pantallas reales.
class PantallaTemporal extends ConsumerWidget {
  final String titulo;
  final IconData icono;

  const PantallaTemporal({
    super.key,
    required this.titulo,
    required this.icono,
  });

  String _nombreRol(String rol) {
    switch (rol) {
      case 'municipalidad':
        return 'Municipalidad';
      case 'conductor':
        return 'Conductor';
      case 'ciudadano':
        return 'Ciudadano';
      default:
        return rol;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final usuario = ref.watch(authProvider).user;

    return Scaffold(
      appBar: AppBar(
        title: Text(titulo),
        actions: [
          IconButton(
            tooltip: 'Cerrar sesión',
            icon: const Icon(Icons.logout),
            onPressed: () => ref.read(authProvider.notifier).logout(),
          ),
        ],
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: EcoColors.verde.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(icono, size: 56, color: EcoColors.verde),
              ),
              const SizedBox(height: 24),
              Text(
                'Hola, ${usuario?.nombre ?? ''}',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: EcoColors.texto,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: EcoColors.verde,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  _nombreRol(usuario?.rol ?? ''),
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Esta pantalla es temporal.',
                style: TextStyle(color: Colors.grey.shade600),
              ),
            ],
          ),
        ),
      ),
    );
  }
}