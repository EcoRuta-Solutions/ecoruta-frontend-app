import 'package:flutter/material.dart';

/// Etiqueta corta para marcar información simulada o de demostración.
/// Usa los mismos colores que el aviso "Datos de ejemplo" del conductor.
class AvisoDatosEjemplo extends StatelessWidget {
  const AvisoDatosEjemplo({this.texto = 'Datos de ejemplo', super.key});

  final String texto;

  static const _fondo = Color(0xFFFFF5E3);
  static const _color = Color(0xFF8A5A00);

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    decoration: BoxDecoration(
      color: _fondo,
      borderRadius: BorderRadius.circular(16),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.science_outlined, size: 14, color: _color),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            texto,
            style: Theme.of(context).textTheme.labelSmall
                ?.copyWith(color: _color, fontWeight: FontWeight.w600),
          ),
        ),
      ],
    ),
  );
}
