import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../municipalidad/data/modelos_alertas_activas.dart';
import '../../municipalidad/data/modelos_reportes_campo.dart';
import '../../municipalidad/presentation/alertas_activas_providers.dart';
import '../../municipalidad/presentation/widgets/visual_llenado.dart';
import '../data/generar_mi_ruta.dart';
import '../data/repositorio_conductor.dart';
import 'accesibilidad_conductor.dart';
import 'mis_rutas_controller.dart';
import 'navegacion_conductor_controller.dart';

/// Aviso "Contenedor lleno" del inicio del conductor. Solo aparece cuando
/// hay alertas activas; el botón "Generar mi ruta" pide al backend una ruta
/// con los contenedores llenos y abre "Mi ruta".
class BannerContenedorLleno extends ConsumerStatefulWidget {
  const BannerContenedorLleno({super.key});

  @override
  ConsumerState<BannerContenedorLleno> createState() =>
      _BannerContenedorLlenoState();
}

class _BannerContenedorLlenoState extends ConsumerState<BannerContenedorLleno> {
  bool _generando = false;
  ErrorGenerarMiRuta? _error;

  @override
  Widget build(BuildContext context) {
    final alertas = ref.watch(alertasActivasProvider).asData?.value;
    if (alertas == null || alertas.isEmpty) return const SizedBox.shrink();

    final principal = _masLlena(alertas);
    final visual = visualLlenado(context, NivelLlenado.lleno);
    final textos = Theme.of(context).textTheme;
    final restantes = alertas.length - 1;

    return Semantics(
      container: true,
      liveRegion: true,
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: visual.fondo,
          border: Border(bottom: BorderSide(color: visual.color, width: 2)),
        ),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 920),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(visual.icono, color: visual.color, size: 28),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Contenedor lleno · ${principal.nivelTexto}',
                            style: textos.titleMedium?.copyWith(
                              color: EcoColors.texto,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            principal.direccionTexto,
                            style: textos.bodyMedium?.copyWith(
                              color: EcoColors.texto,
                            ),
                          ),
                          if (restantes > 0)
                            Text(
                              restantes == 1
                                  ? 'y 1 contenedor lleno más'
                                  : 'y $restantes contenedores llenos más',
                              style: textos.bodySmall?.copyWith(
                                color: EcoColors.textoSecundario,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                semanticaBotonConductor(
                  etiqueta: _generando
                      ? 'Generando tu ruta'
                      : 'Generar mi ruta con los contenedores llenos',
                  child: FilledButton.icon(
                    style: estiloBotonConductor,
                    onPressed: _generando ? null : _generar,
                    icon: _generando
                        ? const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.alt_route_rounded),
                    label: Text(
                      _generando ? 'Generando ruta…' : 'Generar mi ruta',
                    ),
                  ),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    _error!.mensaje,
                    style: textos.bodyMedium?.copyWith(
                      color: EcoColors.critico,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (_error!.detalle != null)
                    Text(
                      'Detalle del servidor: ${_error!.detalle}',
                      style: textos.bodySmall?.copyWith(
                        color: EcoColors.textoSecundario,
                      ),
                    ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _generar() async {
    setState(() {
      _generando = true;
      _error = null;
    });
    try {
      final resultado = await ref
          .read(repositorioConductorProvider)
          .generarMiRuta();
      // Sin caché: "Mi ruta" vuelve a pedir las rutas y muestra la nueva.
      ref.invalidate(misRutasControllerProvider);
      final rutaId = resultado.rutaId;
      if (rutaId != null) ref.invalidate(detalleRutaProvider(rutaId));
      ref
          .read(navegacionConductorProvider.notifier)
          .seleccionar(DestinoConductor.miRuta);
      if (!mounted) return;
      ScaffoldMessenger.maybeOf(context)
        ?..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              resultado.nroPuntos == 1
                  ? 'Ruta generada con 1 punto.'
                  : 'Ruta generada con ${resultado.nroPuntos} puntos.',
            ),
          ),
        );
    } on ErrorGenerarMiRuta catch (error) {
      if (mounted) setState(() => _error = error);
    } catch (_) {
      if (mounted) {
        setState(
          () => _error = const ErrorGenerarMiRuta(
            'No se pudo generar tu ruta. Inténtalo de nuevo.',
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _generando = false);
    }
  }
}

/// La alerta con mayor llenado; las que no tienen % van al final.
AlertaActiva _masLlena(List<AlertaActiva> alertas) =>
    alertas.reduce((a, b) => (b.nivelPct ?? -1) > (a.nivelPct ?? -1) ? b : a);
