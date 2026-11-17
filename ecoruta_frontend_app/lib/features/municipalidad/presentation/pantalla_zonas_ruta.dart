import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/app_config.dart';
import '../../../core/theme/app_theme.dart';
import '../data/modelos_zonas_ruta.dart';
import 'widgets/aviso_datos_ejemplo.dart';
import 'widgets/estados_panel.dart';
import 'zonas_ruta_providers.dart';

const mensajeSinZonasRuta =
    'Aún no hay rutas cargadas. Se importan desde el listado oficial de SEGAT.';

const mensajePorVerificar =
    'Dato transcrito de la hoja de la municipalidad, pendiente de confirmación';

/// Cada cuánto se vuelve a calcular la zona activa.
const _intervaloReloj = Duration(minutes: 1);

/// Rutas por zona de SEGAT (GET /zonas-ruta), en pestañas por turno.
/// Abre en el turno de la hora actual.
class PantallaZonasRuta extends ConsumerStatefulWidget {
  const PantallaZonasRuta({super.key});

  @override
  ConsumerState<PantallaZonasRuta> createState() => _PantallaZonasRutaState();
}

class _PantallaZonasRutaState extends ConsumerState<PantallaZonasRuta> {
  Timer? _reloj;

  @override
  void initState() {
    super.initState();
    // Refresca la zona resaltada a medida que pasan las horas.
    _reloj = Timer.periodic(_intervaloReloj, (_) => setState(() {}));
  }

  @override
  void dispose() {
    _reloj?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ahora = ref.watch(relojZonasRutaProvider)();
    final resaltar = ref.watch(resaltarZonaActivaProvider);

    return DefaultTabController(
      length: TurnoZona.values.length,
      initialIndex: TurnoZona.deHora(ahora).index,
      child: Scaffold(
        backgroundColor: EcoColors.fondo,
        appBar: AppBar(
          backgroundColor: EcoColors.fondo,
          title: const Text('Rutas por zona'),
          bottom: TabBar(
            tabs: [
              for (final turno in TurnoZona.values) Tab(text: turno.etiqueta),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            for (final turno in TurnoZona.values)
              _ListaZonas(
                turno: turno,
                ahora: ahora,
                resaltarActiva: resaltar,
              ),
          ],
        ),
      ),
    );
  }
}

class _ListaZonas extends ConsumerWidget {
  const _ListaZonas({
    required this.turno,
    required this.ahora,
    required this.resaltarActiva,
  });

  final TurnoZona turno;
  final DateTime ahora;
  final bool resaltarActiva;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final zonas = ref.watch(zonasRutaPorTurnoProvider(turno));
    return zonas.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, _) => ErrorPanel(
        onRetry: () => ref.invalidate(zonasRutaPorTurnoProvider(turno)),
      ),
      data: (datos) => Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            maxWidth: EcoLayout.anchoContenido,
          ),
          child: RefreshIndicator(
            onRefresh: () => ref.refresh(zonasRutaPorTurnoProvider(turno).future),
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: EdgeInsets.fromLTRB(
                _margen(context),
                24,
                _margen(context),
                32,
              ),
              children: [
                if (AppConfig.usarDatosDeEjemplo) ...[
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: AvisoDatosEjemplo(),
                  ),
                  const SizedBox(height: 16),
                ],
                if (datos.isEmpty)
                  const Card(
                    child: Padding(
                      padding: EdgeInsets.all(32),
                      child: Text(
                        mensajeSinZonasRuta,
                        textAlign: TextAlign.center,
                      ),
                    ),
                  )
                else
                  for (final zona in datos)
                    TarjetaZonaRuta(
                      key: ValueKey(zona.codigo),
                      zona: zona,
                      activa: resaltarActiva && zona.recogiendoA(ahora),
                    ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static double _margen(BuildContext context) =>
      MediaQuery.sizeOf(context).width < EcoLayout.anchoCompacto ? 16 : 24;
}

/// Tarjeta de una zona: código, tramo, sectores, ventana de recojo y
/// horario para sacar la basura.
class TarjetaZonaRuta extends StatelessWidget {
  const TarjetaZonaRuta({required this.zona, required this.activa, super.key});

  final ZonaRuta zona;

  /// La ventana de recojo incluye la hora actual.
  final bool activa;

  @override
  Widget build(BuildContext context) {
    final texto = Theme.of(context).textTheme;
    final tramo = zona.tramo;
    final sectores = zona.sectores;
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Card(
        shape: activa
            ? RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: const BorderSide(color: EcoColors.acento, width: 2),
              )
            : null,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(
                    zona.codigo,
                    style: texto.titleLarge?.copyWith(
                      color: EcoColors.primario,
                    ),
                  ),
                  if (activa) const _ChipRecogiendoAhora(),
                  if (zona.revisar) const DistintivoPorVerificar(),
                ],
              ),
              if (tramo != null && tramo.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  tramo,
                  style: texto.bodyMedium?.copyWith(
                    color: EcoColors.textoSecundario,
                  ),
                ),
              ],
              const SizedBox(height: 16),
              if (sectores != null && sectores.isNotEmpty) ...[
                _FilaDato(
                  icono: Icons.place_outlined,
                  etiqueta: 'Sectores',
                  valor: sectores,
                ),
                const SizedBox(height: 12),
              ],
              _FilaDato(
                icono: Icons.local_shipping_outlined,
                etiqueta: 'Recojo',
                valor: zona.ventanaRecojo,
                extra: zona.ventanaCruzaMedianoche
                    ? const _ChipCruzaMedianoche()
                    : null,
              ),
              const SizedBox(height: 12),
              _FilaDato(
                icono: Icons.delete_outline_rounded,
                etiqueta: 'Sacar la basura',
                valor: zona.ventanaSacarBasura ?? 'Sin horario registrado',
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FilaDato extends StatelessWidget {
  const _FilaDato({
    required this.icono,
    required this.etiqueta,
    required this.valor,
    this.extra,
  });

  final IconData icono;
  final String etiqueta;
  final String valor;
  final Widget? extra;

  @override
  Widget build(BuildContext context) {
    final texto = Theme.of(context).textTheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icono, size: 18, color: EcoColors.textoSecundario),
        const SizedBox(width: 8),
        Expanded(
          child: Wrap(
            spacing: 8,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                '$etiqueta: ',
                style: texto.labelMedium?.copyWith(
                  color: EcoColors.textoSecundario,
                ),
              ),
              Text(valor, style: texto.bodyMedium),
              ?extra,
            ],
          ),
        ),
      ],
    );
  }
}

/// Etiqueta pequeña con icono, del mismo estilo que los chips de estado.
class _Etiqueta extends StatelessWidget {
  const _Etiqueta({
    required this.icono,
    required this.texto,
    required this.color,
    required this.fondo,
  });

  final IconData icono;
  final String texto;
  final Color color;
  final Color fondo;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    decoration: BoxDecoration(
      color: fondo,
      borderRadius: BorderRadius.circular(16),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icono, size: 14, color: color),
        const SizedBox(width: 6),
        Text(
          texto,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: color,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    ),
  );
}

/// "Por verificar": el dato viene de la hoja de la municipalidad y aún no
/// está confirmado (`revisar = true`).
class DistintivoPorVerificar extends StatelessWidget {
  const DistintivoPorVerificar({super.key});

  @override
  Widget build(BuildContext context) {
    final alerta = Theme.of(context).extension<ColoresEstado>()!.alerta;
    return Tooltip(
      message: mensajePorVerificar,
      triggerMode: TooltipTriggerMode.tap,
      child: _Etiqueta(
        icono: Icons.fact_check_outlined,
        texto: 'Por verificar',
        color: alerta.color,
        fondo: alerta.fondo,
      ),
    );
  }
}

class _ChipCruzaMedianoche extends StatelessWidget {
  const _ChipCruzaMedianoche();

  @override
  Widget build(BuildContext context) => _Etiqueta(
    icono: Icons.bedtime_outlined,
    texto: 'Cruza medianoche',
    color: EcoColors.primario,
    fondo: EcoColors.borde,
  );
}

class _ChipRecogiendoAhora extends StatelessWidget {
  const _ChipRecogiendoAhora();

  @override
  Widget build(BuildContext context) => _Etiqueta(
    icono: Icons.schedule_rounded,
    texto: 'Recojo en curso',
    color: EcoColors.primario,
    fondo: EcoColors.acento.withValues(alpha: 0.18),
  );
}
