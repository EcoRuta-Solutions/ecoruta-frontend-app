import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/config/app_config.dart';
import '../../../../core/theme/app_theme.dart';
import '../../data/modelos_flota.dart';
import '../../data/modelos_panel.dart';
import '../../data/modelos_puntos_criticos.dart';
import '../puntos_criticos_providers.dart';
import 'aviso_datos_ejemplo.dart';
import 'estados_panel.dart';
import 'tarjeta_metrica.dart';

/// Tarjetas con el resumen de GET /puntos-criticos/resumen.
class BloquePuntosCriticos extends ConsumerWidget {
  const BloquePuntosCriticos({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final resumen = ref.watch(resumenPuntosCriticosProvider);

    return _Seccion(
      titulo: 'Puntos críticos',
      child: resumen.when(
        loading: () => const _Cargando(),
        error: (error, stackTrace) => _ErrorSeccion(
          onRetry: () => ref.invalidate(resumenPuntosCriticosProvider),
        ),
        data: (datos) => datos.total == 0
            ? const _Vacio(texto: 'No hay puntos críticos registrados')
            : _TarjetasPuntos(resumen: datos),
      ),
    );
  }
}

class _TarjetasPuntos extends StatelessWidget {
  const _TarjetasPuntos({required this.resumen});

  final ResumenPuntosCriticos resumen;

  @override
  Widget build(BuildContext context) => _Rejilla(
    children: [
      TarjetaMetrica(
        etiqueta: 'Total',
        valor: resumen.total,
        estado: EstadoNodo.sinDatos,
        visual: EstadoVisual(
          color: EcoColors.primario,
          fondo: EcoColors.acento.withValues(alpha: 0.12),
          icono: Icons.place_outlined,
        ),
      ),
      TarjetaMetrica(
        etiqueta: 'Prioritarios',
        valor: resumen.prioritarios,
        estado: EstadoNodo.critico,
      ),
      TarjetaMetrica(
        etiqueta: 'Potenciales',
        valor: resumen.potenciales,
        estado: EstadoNodo.alerta,
      ),
      TarjetaMetrica(
        etiqueta: 'Recuperados',
        valor: resumen.recuperados,
        estado: EstadoNodo.normal,
      ),
    ],
  );
}

/// Bloque de flota con GET /flota/resumen.
class BloqueFlota extends ConsumerWidget {
  const BloqueFlota({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final resumen = ref.watch(resumenFlotaProvider);

    return _Seccion(
      titulo: 'Flota',
      child: resumen.when(
        loading: () => const _Cargando(),
        error: (error, stackTrace) =>
            _ErrorSeccion(onRetry: () => ref.invalidate(resumenFlotaProvider)),
        data: (datos) => datos.total == 0
            ? const _Vacio(texto: 'No hay camiones registrados')
            : _DetalleFlota(resumen: datos),
      ),
    );
  }
}

class _DetalleFlota extends StatelessWidget {
  const _DetalleFlota({required this.resumen});

  final ResumenFlota resumen;

  @override
  Widget build(BuildContext context) {
    final textos = Theme.of(context).textTheme;
    final operativo = Theme.of(context).extension<ColoresEstado>()!.normal;
    final avisos = [
      if (resumen.demo > 0)
        resumen.demo == 1
            ? 'Incluye 1 camión demo'
            : 'Incluye ${resumen.demo} camiones demo',
      if (resumen.datosProvisionales > 0)
        '${resumen.datosProvisionales} con datos provisionales',
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Camiones operativos por turno · ${resumen.total} en total, '
          '${resumen.porEstado.mantenimiento} en mantenimiento',
          style: textos.bodySmall?.copyWith(color: EcoColors.textoSecundario),
        ),
        if (avisos.isNotEmpty) ...[
          const SizedBox(height: 8),
          AvisoDatosEjemplo(texto: avisos.join(' · ')),
        ],
        const SizedBox(height: 16),
        _Rejilla(
          children: [
            for (final (turno, etiqueta) in const [
              (TurnoFlota.manana, 'Mañana'),
              (TurnoFlota.tarde, 'Tarde'),
              (TurnoFlota.noche, 'Noche'),
            ])
              TarjetaMetrica(
                etiqueta: etiqueta,
                valor: resumen.turno(turno).operativo,
                estado: EstadoNodo.normal,
                visual: EstadoVisual(
                  color: operativo.color,
                  fondo: operativo.fondo,
                  icono: Icons.local_shipping_outlined,
                ),
              ),
            TarjetaMetrica(
              etiqueta: 'En reserva',
              valor: resumen.porEstado.reserva,
              estado: EstadoNodo.sinDatos,
              visual: EstadoVisual(
                color: EcoColors.primario,
                fondo: EcoColors.borde,
                icono: Icons.garage_outlined,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _Seccion extends StatelessWidget {
  const _Seccion({required this.titulo, required this.child});

  final String titulo;
  final Widget child;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Wrap(
        spacing: 12,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Text(
            titulo,
            style: Theme.of(context).textTheme.titleLarge
                ?.copyWith(color: EcoColors.texto),
          ),
          if (AppConfig.usarDatosDeEjemplo) const AvisoDatosEjemplo(),
        ],
      ),
      const SizedBox(height: 16),
      child,
    ],
  );
}

class _Rejilla extends StatelessWidget {
  const _Rejilla({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) => GridView.count(
    crossAxisCount: 2,
    mainAxisSpacing: 16,
    crossAxisSpacing: 16,
    mainAxisExtent: 136,
    shrinkWrap: true,
    physics: const NeverScrollableScrollPhysics(),
    children: children,
  );
}

class _Cargando extends StatelessWidget {
  const _Cargando();

  @override
  Widget build(BuildContext context) => const SizedBox(
    height: 136,
    child: Center(child: CircularProgressIndicator()),
  );
}

class _ErrorSeccion extends StatelessWidget {
  const _ErrorSeccion({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) =>
      Card(child: ErrorPanel(onRetry: onRetry));
}

class _Vacio extends StatelessWidget {
  const _Vacio({required this.texto});

  final String texto;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(32),
    decoration: BoxDecoration(
      color: EcoColors.superficie,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: EcoColors.borde),
    ),
    child: Text(
      texto,
      textAlign: TextAlign.center,
      style: Theme.of(context).textTheme.bodyMedium
          ?.copyWith(color: EcoColors.textoSecundario),
    ),
  );
}
