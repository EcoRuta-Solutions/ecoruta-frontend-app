import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/app_config.dart';
import '../../../core/theme/app_theme.dart';
import '../data/modelos_alertas_activas.dart';
import '../data/modelos_reportes_campo.dart';
import 'alertas_activas_providers.dart';
import 'navegacion_controller.dart';
import 'widgets/aviso_datos_ejemplo.dart';
import 'widgets/estados_panel.dart';
import 'widgets/visual_llenado.dart';

/// Alertas activas de los contenedores con sensor (GET /alertas/activas).
/// Se actualiza sola mientras está visible; tocar una alerta lleva al punto
/// en el mapa.
class PantallaAlertas extends ConsumerWidget {
  const PantallaAlertas({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final alertas = ref.watch(alertasActivasProvider);
    final ancho = MediaQuery.sizeOf(context).width;
    final margen = ancho < EcoLayout.anchoCompacto ? 16.0 : 24.0;

    Future<void> recargar() =>
        ref.read(alertasActivasProvider.notifier).refrescar();

    final contenido = alertas.when(
      skipLoadingOnRefresh: true,
      skipLoadingOnReload: true,
      loading: () => <Widget>[
        const SliverToBoxAdapter(child: EsqueletoPanel()),
      ],
      error: (_, _) => <Widget>[
        SliverToBoxAdapter(
          child: ErrorPanel(
            onRetry: () => ref.invalidate(alertasActivasProvider),
          ),
        ),
      ],
      data: (lista) => <Widget>[
        SliverToBoxAdapter(child: _Encabezado(cantidad: lista.length)),
        if (lista.isEmpty)
          const SliverToBoxAdapter(child: _SinAlertas())
        else
          SliverList.builder(
            itemCount: lista.length,
            itemBuilder: (context, indice) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: TarjetaAlertaActiva(
                alerta: lista[indice],
                onTap: () => _verEnMapa(context, ref, lista[indice]),
              ),
            ),
          ),
      ],
    );

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: EcoLayout.anchoContenido),
        child: RefreshIndicator(
          onRefresh: recargar,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverPadding(
                padding: EdgeInsets.fromLTRB(margen, 24, margen, 32),
                sliver: SliverMainAxisGroup(slivers: contenido),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _verEnMapa(BuildContext context, WidgetRef ref, AlertaActiva alerta) {
    if (alerta.puntoCodigo.isEmpty) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text('La ubicación de esta alerta está por confirmar.'),
          ),
        );
      return;
    }
    ref
        .read(navegacionMunicipalidadProvider.notifier)
        .verPuntoEnMapa(alerta.puntoCodigo);
  }
}

class _Encabezado extends StatelessWidget {
  const _Encabezado({required this.cantidad});

  final int cantidad;

  @override
  Widget build(BuildContext context) {
    final visual = Theme.of(context).extension<ColoresEstado>()!.critico;
    final textos = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Alertas',
                  style: textos.headlineMedium?.copyWith(
                    color: EcoColors.primario,
                  ),
                ),
              ),
              Container(
                constraints: const BoxConstraints(minHeight: 40),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: visual.fondo,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(visual.icono, size: 16, color: visual.color),
                    const SizedBox(width: 8),
                    Text(
                      cantidad == 1 ? '1 activa' : '$cantidad activas',
                      style: textos.labelMedium?.copyWith(
                        color: visual.color,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Contenedores con sensor que avisaron que están llenos. '
            'La lista se actualiza sola.',
            style: textos.bodyMedium?.copyWith(
              color: EcoColors.textoSecundario,
            ),
          ),
          if (AppConfig.usarDatosDeEjemplo) ...[
            const SizedBox(height: 8),
            const AvisoDatosEjemplo(),
          ],
        ],
      ),
    );
  }
}

/// Tarjeta de una alerta activa: código, dirección, % de llenado y hora.
class TarjetaAlertaActiva extends StatelessWidget {
  const TarjetaAlertaActiva({
    required this.alerta,
    required this.onTap,
    super.key,
  });

  final AlertaActiva alerta;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final visual = visualLlenado(context, NivelLlenado.lleno);
    final textos = Theme.of(context).textTheme;
    final secundario = textos.bodyMedium?.copyWith(
      color: EcoColors.textoSecundario,
    );

    return Semantics(
      button: true,
      label:
          'Alerta de ${alerta.codigoTexto}, ${alerta.direccionTexto}, '
          'llenado ${alerta.nivelTexto}, hora ${alerta.horaTexto}. '
          'Ver en el mapa',
      excludeSemantics: true,
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: visual.fondo,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(visual.icono, color: visual.color),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        alerta.codigoTexto,
                        style: textos.titleMedium?.copyWith(
                          color: EcoColors.texto,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(alerta.direccionTexto, style: secundario),
                      if (alerta.mensaje.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(alerta.mensaje, style: secundario),
                      ],
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Icon(
                            Icons.schedule_rounded,
                            size: 16,
                            color: EcoColors.textoSecundario,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Hora: ${alerta.horaTexto}',
                            style: textos.labelMedium?.copyWith(
                              color: EcoColors.textoSecundario,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      alerta.nivelTexto,
                      style:
                          (alerta.nivelPct == null
                                  ? textos.labelLarge
                                  : textos.titleLarge)
                              ?.copyWith(
                                color: visual.color,
                                fontWeight: FontWeight.w700,
                              ),
                    ),
                    const SizedBox(height: 4),
                    const Icon(
                      Icons.map_outlined,
                      size: 18,
                      color: EcoColors.textoSecundario,
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

class _SinAlertas extends StatelessWidget {
  const _SinAlertas();

  @override
  Widget build(BuildContext context) {
    final colores = Theme.of(context).extension<ColoresEstado>()!;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 72, horizontal: 24),
      child: Column(
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: colores.normal.fondo,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.notifications_none_rounded,
              color: colores.normal.color,
              size: 36,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Sin alertas activas',
            style: Theme.of(context).textTheme.titleLarge
                ?.copyWith(color: EcoColors.primario),
          ),
          const SizedBox(height: 8),
          Text(
            'Cuando un contenedor con sensor se llene, aparecerá aquí.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium
                ?.copyWith(color: EcoColors.textoSecundario),
          ),
        ],
      ),
    );
  }
}
