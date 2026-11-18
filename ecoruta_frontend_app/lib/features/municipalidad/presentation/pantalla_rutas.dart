import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/app_config.dart';
import '../../../core/theme/app_theme.dart';
import '../../conductor/data/modelos_conductor.dart';
import '../data/modelos_generacion_rutas.dart';
import '../data/modelos_zonas_ruta.dart';
import 'pantalla_mapa_rutas.dart';
import 'pantalla_zonas_ruta.dart';
import 'rutas_turno_providers.dart';
import 'widgets/aviso_datos_ejemplo.dart';
import 'widgets/estados_panel.dart';

const _maximoAnchoRutas = 920.0;

/// Rutas de la municipalidad: generar las rutas de un turno (POST
/// /rutas/generar) y ver las del día (GET /rutas/hoy).
class PantallaRutas extends ConsumerWidget {
  const PantallaRutas({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final generacion = ref.watch(generacionRutasProvider);
    final rutasHoy = ref.watch(rutasHoyProvider);
    final ancho = MediaQuery.sizeOf(context).width;
    final margen = ancho < EcoLayout.anchoCompacto ? 16.0 : 24.0;
    final textos = Theme.of(context).textTheme;

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: _maximoAnchoRutas),
        child: RefreshIndicator(
          onRefresh: () => ref.refresh(rutasHoyProvider.future),
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.fromLTRB(margen, 24, margen, 32),
            children: [
              Wrap(
                spacing: 12,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(
                    'Rutas de recolección',
                    style: textos.headlineMedium?.copyWith(
                      color: EcoColors.primario,
                    ),
                  ),
                  if (AppConfig.usarDatosDeEjemplo) const AvisoDatosEjemplo(),
                ],
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  FilledButton.icon(
                    onPressed: generacion?.isLoading ?? false
                        ? null
                        : () => _generar(context, ref),
                    icon: const Icon(Icons.auto_awesome_rounded),
                    label: const Text('Generar rutas'),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const PantallaZonasRuta(),
                      ),
                    ),
                    icon: const Icon(Icons.map_outlined),
                    label: const Text('Rutas por zona'),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              ...switch (generacion) {
                null => const <Widget>[],
                AsyncLoading() => const [
                  _Cargando(texto: 'Generando las rutas del turno…'),
                  SizedBox(height: 24),
                ],
                AsyncError(:final error) => [
                  _ErrorGeneracion(error: error),
                  const SizedBox(height: 24),
                ],
                AsyncData(:final value) => [
                  ResumenGeneracionRutas(resultado: value),
                  const SizedBox(height: 32),
                ],
              },
              Text(
                'Rutas de hoy',
                style: textos.titleLarge?.copyWith(color: EcoColors.texto),
              ),
              const SizedBox(height: 12),
              ...rutasHoy.when(
                loading: () => const [_Cargando(texto: 'Cargando rutas…')],
                error: (_, _) => [
                  Card(
                    child: ErrorPanel(
                      onRetry: () => ref.invalidate(rutasHoyProvider),
                    ),
                  ),
                ],
                data: (rutas) => rutas.isEmpty
                    ? const [
                        _Vacio(
                          texto:
                              'Aún no hay rutas para hoy. Usa "Generar rutas" '
                              'para crear las de un turno.',
                        ),
                      ]
                    : [
                        Align(
                          alignment: Alignment.centerLeft,
                          child: TextButton.icon(
                            onPressed: () => _abrirMapa(
                              context,
                              [for (final r in rutas) RutaEnMapa.desdeRuta(r)],
                              titulo: 'Rutas de hoy',
                            ),
                            icon: const Icon(Icons.map_rounded),
                            label: const Text('Ver todas en el mapa'),
                          ),
                        ),
                        for (var i = 0; i < rutas.length; i++)
                          _TarjetaRutaHoy(
                            ruta: rutas[i],
                            color: colorDeRuta(i),
                            onTap: () => _abrirMapa(
                              context,
                              [for (final r in rutas) RutaEnMapa.desdeRuta(r)],
                              titulo: 'Rutas de hoy',
                              rutaInicial: rutas[i].id,
                            ),
                          ),
                      ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _generar(BuildContext context, WidgetRef ref) async {
    final solicitud = await showDialog<SolicitudGenerarRutas>(
      context: context,
      builder: (_) => DialogoGenerarRutas(turnoInicial: TurnoZona.deHora(DateTime.now())),
    );
    if (solicitud == null) return;
    await ref.read(generacionRutasProvider.notifier).generar(solicitud);
  }
}

void _abrirMapa(
  BuildContext context,
  List<RutaEnMapa> rutas, {
  required String titulo,
  int? rutaInicial,
}) => Navigator.of(context).push(
  MaterialPageRoute<void>(
    builder: (_) => PantallaMapaRutas(
      rutas: rutas,
      titulo: titulo,
      rutaInicial: rutaInicial,
    ),
  ),
);

/// Turno, filtros y confirmación antes de generar.
class DialogoGenerarRutas extends StatefulWidget {
  const DialogoGenerarRutas({required this.turnoInicial, super.key});

  final TurnoZona turnoInicial;

  @override
  State<DialogoGenerarRutas> createState() => _DialogoGenerarRutasState();
}

class _DialogoGenerarRutasState extends State<DialogoGenerarRutas> {
  late TurnoZona _turno = widget.turnoInicial;
  bool _soloPrioritarios = false;
  bool _incluirReserva = false;

  @override
  Widget build(BuildContext context) {
    final textos = Theme.of(context).textTheme;
    return AlertDialog(
      title: const Text('Generar rutas'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Turno', style: textos.labelLarge),
            const SizedBox(height: 8),
            SegmentedButton<TurnoZona>(
              segments: [
                for (final turno in TurnoZona.values)
                  ButtonSegment(value: turno, label: Text(turno.etiqueta)),
              ],
              selected: {_turno},
              onSelectionChanged: (seleccion) =>
                  setState(() => _turno = seleccion.single),
            ),
            const SizedBox(height: 8),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Solo puntos prioritarios'),
              value: _soloPrioritarios,
              onChanged: (valor) => setState(() => _soloPrioritarios = valor),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Incluir camiones de reserva'),
              value: _incluirReserva,
              onChanged: (valor) => setState(() => _incluirReserva = valor),
            ),
            const SizedBox(height: 8),
            Text(
              'Se generan las rutas de hoy del turno ${_turno.etiqueta} con '
              'los puntos críticos y los camiones operativos. Las rutas '
              'pendientes de ese turno se reemplazan; las que están en curso '
              'o completadas no se tocan.',
              style: textos.bodySmall?.copyWith(
                color: EcoColors.textoSecundario,
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(
            SolicitudGenerarRutas(
              turno: _turno,
              soloPrioritarios: _soloPrioritarios,
              incluirReserva: _incluirReserva,
            ),
          ),
          child: const Text('Generar'),
        ),
      ],
    );
  }
}

/// Resumen de la última generación: totales, rutas por camión y
/// parámetros provisionales.
class ResumenGeneracionRutas extends StatelessWidget {
  const ResumenGeneracionRutas({required this.resultado, super.key});

  final ResultadoGeneracionRutas resultado;

  @override
  Widget build(BuildContext context) {
    final textos = Theme.of(context).textTheme;
    final secundario = textos.bodySmall?.copyWith(
      color: EcoColors.textoSecundario,
    );
    final rutas = [
      for (final r in resultado.rutas) RutaEnMapa.desdeGenerada(r),
    ];
    final fecha =
        '${resultado.fecha.day.toString().padLeft(2, '0')}/'
        '${resultado.fecha.month.toString().padLeft(2, '0')}/'
        '${resultado.fecha.year}';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Rutas generadas · Turno ${resultado.turno.etiqueta} · $fecha',
              style: textos.titleMedium?.copyWith(color: EcoColors.primario),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 24,
              runSpacing: 12,
              children: [
                _Metrica(
                  valor: '${resultado.nroCamiones}',
                  etiqueta: 'Camiones',
                ),
                _Metrica(valor: '${resultado.nroPuntos}', etiqueta: 'Puntos'),
                _Metrica(
                  valor:
                      '${resultado.distanciaTotalKm.toStringAsFixed(1)} km',
                  etiqueta: 'Distancia total',
                ),
                _Metrica(
                  valor: duracionTexto(resultado.tiempoTotalMin),
                  etiqueta: 'Tiempo total',
                ),
              ],
            ),
            if (resultado.distanciasAproximadas) ...[
              const SizedBox(height: 12),
              Text(
                'Distancias aproximadas (en línea recta, no por calles).',
                style: secundario,
              ),
            ],
            if (resultado.rutasReemplazadas > 0) ...[
              const SizedBox(height: 4),
              Text(
                resultado.rutasReemplazadas == 1
                    ? 'Se reemplazó 1 ruta pendiente de este turno.'
                    : 'Se reemplazaron ${resultado.rutasReemplazadas} rutas '
                          'pendientes de este turno.',
                style: secundario,
              ),
            ],
            if (resultado.camionesConRutaEnCurso.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                'Sin cambios por tener una ruta en curso: '
                '${resultado.camionesConRutaEnCurso.join(', ')}.',
                style: secundario,
              ),
            ],
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: Text('Rutas por camión', style: textos.titleSmall),
                ),
                if (rutas.isNotEmpty)
                  TextButton.icon(
                    onPressed: () => _abrirMapa(
                      context,
                      rutas,
                      titulo: 'Rutas del turno ${resultado.turno.etiqueta}',
                    ),
                    icon: const Icon(Icons.map_rounded),
                    label: const Text('Ver en el mapa'),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            for (var i = 0; i < resultado.rutas.length; i++)
              TarjetaRutaGenerada(
                ruta: resultado.rutas[i],
                color: colorDeRuta(i),
                onTap: () => _abrirMapa(
                  context,
                  rutas,
                  titulo: 'Rutas del turno ${resultado.turno.etiqueta}',
                  rutaInicial: resultado.rutas[i].rutaId,
                ),
              ),
            const Divider(height: 24),
            _ParametrosProvisionales(parametros: resultado.parametros),
          ],
        ),
      ),
    );
  }
}

class TarjetaRutaGenerada extends StatelessWidget {
  const TarjetaRutaGenerada({
    required this.ruta,
    required this.color,
    required this.onTap,
    super.key,
  });

  final RutaGenerada ruta;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final textos = Theme.of(context).textTheme;
    final alerta = Theme.of(context).extension<ColoresEstado>()!.alerta;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: EcoColors.fondo,
        borderRadius: BorderRadius.circular(12),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                CircleAvatar(radius: 8, backgroundColor: color),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(ruta.placa, style: textos.titleSmall),
                      Text(
                        '${ruta.paradas.length} paradas · '
                        '${ruta.distanciaKm.toStringAsFixed(1)} km · '
                        '${horaTexto(ruta.horaInicio)} – '
                        '${horaTexto(ruta.horaFin)}',
                        style: textos.bodySmall?.copyWith(
                          color: EcoColors.textoSecundario,
                        ),
                      ),
                      if (ruta.excedeTurno) ...[
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: alerta.fondo,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.schedule_rounded,
                                size: 14,
                                color: alerta.color,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'Excede el turno',
                                style: textos.labelSmall?.copyWith(
                                  color: alerta.color,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right_rounded),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Supuestos del cálculo en texto pequeño, para no confundirlos con datos.
class _ParametrosProvisionales extends StatelessWidget {
  const _ParametrosProvisionales({required this.parametros});

  final ParametrosGeneracion parametros;

  static const _nombres = {
    'velocidad_media_kmh': 'velocidad media',
    'minutos_por_parada': 'minutos por parada',
    'factor_circuito': 'factor de circuito',
    'capacidad_camion_usada': 'capacidad del camión',
  };

  @override
  Widget build(BuildContext context) {
    final pequeno = Theme.of(context).textTheme.bodySmall?.copyWith(
      color: EcoColors.textoSecundario,
      fontSize: 12,
    );
    final factor = parametros.factorCircuito;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Parámetros provisionales',
          style: pequeno?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 4),
        Text(
          [
            'Velocidad media ${_numero(parametros.velocidadMediaKmh)} km/h',
            '${_numero(parametros.minutosPorParada)} min por parada',
            if (factor != null) 'factor de circuito ${_numero(factor)}',
            parametros.capacidadCamionUsada
                ? 'con capacidad del camión'
                : 'sin capacidad del camión',
          ].join(' · '),
          style: pequeno,
        ),
        if (parametros.provisionales.isNotEmpty)
          Text(
            'Por confirmar: ${[for (final p in parametros.provisionales) _nombres[p] ?? p].join(', ')}.',
            style: pequeno,
          ),
        for (final nota in parametros.notas) Text(nota, style: pequeno),
      ],
    );
  }

  static String _numero(double valor) => valor == valor.roundToDouble()
      ? valor.toInt().toString()
      : valor.toStringAsFixed(2).replaceAll('.', ',');
}

class _TarjetaRutaHoy extends StatelessWidget {
  const _TarjetaRutaHoy({
    required this.ruta,
    required this.color,
    required this.onTap,
  });

  final RutaConductor ruta;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final textos = Theme.of(context).textTheme;
    final km = ruta.distanciaKm;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                CircleAvatar(radius: 8, backgroundColor: color),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        ruta.camion?.placa ?? 'Ruta #${ruta.id}',
                        style: textos.titleMedium?.copyWith(
                          color: EcoColors.primario,
                        ),
                      ),
                      Text(
                        [
                          'Turno ${ruta.turnoTexto}',
                          etiquetaEstadoRuta(ruta.estado),
                          '${ruta.paradasHechas}/${ruta.paradasTotal} paradas',
                          if (km != null) '${km.toStringAsFixed(1)} km',
                          '${horaTexto(ruta.horaInicio)} – '
                              '${horaTexto(ruta.horaFin)}',
                        ].join(' · '),
                        style: textos.bodySmall?.copyWith(
                          color: EcoColors.textoSecundario,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right_rounded),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ErrorGeneracion extends StatelessWidget {
  const _ErrorGeneracion({required this.error});

  final Object error;

  @override
  Widget build(BuildContext context) {
    final critico = Theme.of(context).extension<ColoresEstado>()!.critico;
    final textos = Theme.of(context).textTheme;
    final (mensaje, detalle) = switch (error) {
      ErrorGeneracionRutas(:final mensaje, :final detalle) => (
        mensaje,
        detalle,
      ),
      _ => ('No se pudieron generar las rutas.', null),
    };
    return Card(
      color: critico.fondo,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.error_outline_rounded, color: critico.color),
            const SizedBox(width: 12),
            Expanded(
              child: Semantics(
                liveRegion: true,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(mensaje, style: textos.bodyMedium),
                    if (detalle != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        detalle,
                        style: textos.bodySmall?.copyWith(
                          color: EcoColors.textoSecundario,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Metrica extends StatelessWidget {
  const _Metrica({required this.valor, required this.etiqueta});

  final String valor;
  final String etiqueta;

  @override
  Widget build(BuildContext context) {
    final textos = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          valor,
          style: textos.titleLarge?.copyWith(color: EcoColors.primario),
        ),
        Text(
          etiqueta,
          style: textos.labelMedium?.copyWith(
            color: EcoColors.textoSecundario,
          ),
        ),
      ],
    );
  }
}

class _Cargando extends StatelessWidget {
  const _Cargando({required this.texto});

  final String texto;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Row(
        children: [
          const SizedBox.square(
            dimension: 24,
            child: CircularProgressIndicator(strokeWidth: 3),
          ),
          const SizedBox(width: 16),
          Expanded(child: Text(texto)),
        ],
      ),
    ),
  );
}

class _Vacio extends StatelessWidget {
  const _Vacio({required this.texto});

  final String texto;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Text(
        texto,
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.bodyMedium
            ?.copyWith(color: EcoColors.textoSecundario),
      ),
    ),
  );
}
