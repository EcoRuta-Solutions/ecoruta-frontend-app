import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';

class EsqueletoPanel extends StatefulWidget {
  const EsqueletoPanel({super.key});

  @override
  State<EsqueletoPanel> createState() => _EsqueletoPanelState();
}

class _EsqueletoPanelState extends State<EsqueletoPanel>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animacion = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  )..repeat();

  @override
  void dispose() {
    _animacion.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animacion,
      child: const _BloquesPanel(),
      builder: (context, child) {
        final avance = _animacion.value * 2;
        return ShaderMask(
          blendMode: BlendMode.srcATop,
          shaderCallback: (bounds) => LinearGradient(
            begin: Alignment(-1.5 + avance, 0),
            end: Alignment(-0.5 + avance, 0),
            colors: const [
              EcoColors.borde,
              EcoColors.superficie,
              EcoColors.borde,
            ],
          ).createShader(bounds),
          child: child,
        );
      },
    );
  }
}

class _BloquesPanel extends StatelessWidget {
  const _BloquesPanel();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [_bloque(120, 32), const Spacer(), _bloque(88, 32)]),
        const SizedBox(height: 24),
        _bloque(double.infinity, 136),
        const SizedBox(height: 16),
        GridView.count(
          crossAxisCount: 2,
          mainAxisSpacing: 16,
          crossAxisSpacing: 16,
          mainAxisExtent: 136,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          children: [
            for (var index = 0; index < 4; index++)
              _bloque(double.infinity, 112),
          ],
        ),
        const SizedBox(height: 24),
        _bloque(224, 40),
        const SizedBox(height: 16),
        for (var index = 0; index < 3; index++) ...[
          _bloque(double.infinity, 128),
          const SizedBox(height: 16),
        ],
      ],
    );
  }

  Widget _bloque(double width, double height) => Container(
    width: width.isFinite ? width : null,
    height: height,
    decoration: BoxDecoration(
      color: EcoColors.borde.withValues(alpha: 0.7),
      borderRadius: BorderRadius.circular(16),
    ),
  );
}

class ErrorPanel extends StatelessWidget {
  const ErrorPanel({required this.onRetry, super.key});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.cloud_off_outlined,
              size: 40,
              color: EcoColors.textoSecundario,
            ),
            const SizedBox(height: 16),
            Text(
              'No se pudo cargar la información',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Reintentar'),
            ),
          ],
        ),
      ),
    );
  }
}

class ContenidoCentradoPanel extends StatelessWidget {
  const ContenidoCentradoPanel({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: EcoLayout.anchoContenido),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: child,
        ),
      ),
    );
  }
}
