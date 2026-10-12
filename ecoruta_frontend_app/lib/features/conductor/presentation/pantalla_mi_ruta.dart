import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../auth/presentation/auth_controller.dart';
import '../data/modelos_conductor.dart';
import 'mis_rutas_controller.dart';

const _maximoAnchoConductor = 920.0;

class PantallaMiRuta extends ConsumerWidget {
  const PantallaMiRuta({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rutas = ref.watch(misRutasControllerProvider);
    final ancho = MediaQuery.sizeOf(context).width;
    final margen = ancho < EcoLayout.anchoCompacto ? 16.0 : 24.0;

    return RefreshIndicator(
      onRefresh: () => ref.read(misRutasControllerProvider.notifier).recargar(),
      child: rutas.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => _Mensaje(
          icono: Icons.cloud_off_rounded,
          titulo: 'No se pudieron cargar tus rutas',
          accion: FilledButton.icon(
            onPressed: () =>
                ref.read(misRutasControllerProvider.notifier).recargar(),
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Reintentar'),
          ),
        ),
        data: (lista) {
          if (lista.isEmpty) {
            return const _Mensaje(
              icono: Icons.local_shipping_outlined,
              titulo: 'No tienes rutas asignadas',
            );
          }
          final activa = rutaActivaDe(lista);
          return ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.symmetric(horizontal: margen, vertical: 24),
            children: [
              _Saludo(
                nombre: ref.watch(authProvider).user?.nombre ?? 'Conductor',
              ),
              const SizedBox(height: 24),
              _Encabezado(texto: 'Mi ruta de hoy'),
              const SizedBox(height: 12),
              if (activa != null) _TarjetaActiva(ruta: activa),
              const SizedBox(height: 28),
              _Encabezado(texto: 'Todas mis rutas'),
              const SizedBox(height: 12),
              for (final ruta in lista)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: _TarjetaRuta(ruta: ruta),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _Saludo extends StatelessWidget {
  const _Saludo({required this.nombre});

  final String nombre;

  @override
  Widget build(BuildContext context) => Center(
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: _maximoAnchoConductor),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: EcoColors.acento.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Text(
              _iniciales(nombre),
              style: const TextStyle(
                color: EcoColors.primario,
                fontWeight: FontWeight.w700,
                fontSize: 18,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Hola, $nombre',
                  style: Theme.of(context).textTheme.titleLarge
                      ?.copyWith(color: EcoColors.primario),
                ),
                const SizedBox(height: 2),
                Text(
                  '${_saludoHora()} · ${_fechaLarga(DateTime.now())}',
                  style: Theme.of(context).textTheme.bodyMedium
                      ?.copyWith(color: EcoColors.textoSecundario),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

class _Encabezado extends StatelessWidget {
  const _Encabezado({required this.texto});

  final String texto;

  @override
  Widget build(BuildContext context) => Center(
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: _maximoAnchoConductor),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          texto,
          style: Theme.of(context).textTheme.titleMedium
              ?.copyWith(color: EcoColors.primario, fontWeight: FontWeight.w700),
        ),
      ),
    ),
  );
}

class _TarjetaActiva extends ConsumerWidget {
  const _TarjetaActiva({required this.ruta});

  final RutaConductor ruta;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final visual = Theme.of(
      context,
    ).extension<ColoresProceso>()!.para(_estadoProcesoConductor(ruta.estado));
    final siguiente = ruta.paradas.where((p) => !p.recolectado).firstOrNull;

    Future<void> cambiar(EstadoRutaConductor estado, String mensaje) async {
      try {
        await ref
            .read(misRutasControllerProvider.notifier)
            .cambiarEstado(ruta.id, estado);
        if (context.mounted) _mostrarMensaje(context, mensaje);
      } catch (_) {
        if (context.mounted) {
          _mostrarMensaje(context, 'No se pudo actualizar la ruta.');
        }
      }
    }

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: _maximoAnchoConductor),
        child: Card(
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () => context.push('/conductor/ruta/${ruta.id}'),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _AnilloProgreso(ruta: ruta, visual: visual),
                      const SizedBox(width: 20),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    'Ruta #${ruta.id} · '
                                    '${ruta.camion?.placa ?? 'Sin camión'}',
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleLarge
                                        ?.copyWith(color: EcoColors.primario),
                                  ),
                                ),
                                _ChipEstado(estado: ruta.estado),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Turno ${ruta.camion?.turno ?? '—'} · '
                              '${_hora(ruta.horaInicio)} a ${_hora(ruta.horaFin)}',
                              style: Theme.of(context).textTheme.bodyMedium
                                  ?.copyWith(color: EcoColors.textoSecundario),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              '${ruta.paradasHechas}/${ruta.paradasTotal} paradas recolectadas',
                              style: Theme.of(context).textTheme.labelMedium
                                  ?.copyWith(color: visual.color),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: EcoColors.fondo,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          siguiente == null
                              ? Icons.emoji_events_rounded
                              : Icons.flag_rounded,
                          size: 20,
                          color: EcoColors.acento,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            siguiente == null
                                ? 'Todas las paradas completadas'
                                : 'Siguiente: ${siguiente.titulo}',
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      if (ruta.estado == EstadoRutaConductor.pendiente)
                        Expanded(
                          child: FilledButton.icon(
                            onPressed: () => cambiar(
                              EstadoRutaConductor.enProceso,
                              'Ruta iniciada.',
                            ),
                            icon: const Icon(Icons.play_arrow_rounded),
                            label: const Text('Iniciar ruta'),
                          ),
                        ),
                      if (ruta.estado == EstadoRutaConductor.enProceso)
                        Expanded(
                          child: FilledButton.icon(
                            onPressed: () => cambiar(
                              EstadoRutaConductor.completado,
                              'Ruta completada.',
                            ),
                            icon: const Icon(Icons.check_rounded),
                            label: const Text('Completar ruta'),
                          ),
                        ),
                      if (ruta.estado == EstadoRutaConductor.completado ||
                          ruta.estado == EstadoRutaConductor.cancelado)
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () =>
                                context.push('/conductor/ruta/${ruta.id}'),
                            icon: const Icon(Icons.visibility_rounded),
                            label: const Text('Ver detalle'),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AnilloProgreso extends StatelessWidget {
  const _AnilloProgreso({required this.ruta, required this.visual});

  final RutaConductor ruta;
  final EstadoVisual visual;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 72,
    height: 72,
    child: Stack(
      alignment: Alignment.center,
      children: [
        SizedBox(
          width: 72,
          height: 72,
          child: CircularProgressIndicator(
            value: ruta.progreso,
            strokeWidth: 7,
            backgroundColor: visual.fondo,
            color: visual.color,
          ),
        ),
        Text(
          '${(ruta.progreso * 100).round()}%',
          style: Theme.of(context).textTheme.titleMedium
              ?.copyWith(color: EcoColors.primario, fontWeight: FontWeight.w700),
        ),
      ],
    ),
  );
}

class _TarjetaRuta extends StatelessWidget {
  const _TarjetaRuta({required this.ruta});

  final RutaConductor ruta;

  @override
  Widget build(BuildContext context) {
    final visual = Theme.of(
      context,
    ).extension<ColoresProceso>()!.para(_estadoProcesoConductor(ruta.estado));

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: _maximoAnchoConductor),
        child: Card(
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () => context.push('/conductor/ruta/${ruta.id}'),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Ruta #${ruta.id}',
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(color: EcoColors.primario),
                        ),
                      ),
                      _ChipEstado(estado: ruta.estado),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    ruta.camion == null
                        ? 'Sin camión asignado'
                        : '${ruta.camion!.placa} · Turno ${ruta.camion!.turno}',
                    style: Theme.of(context).textTheme.bodyMedium
                        ?.copyWith(color: EcoColors.textoSecundario),
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 20,
                    runSpacing: 12,
                    children: [
                      _Dato(
                        icono: Icons.schedule_outlined,
                        texto:
                            '${_hora(ruta.horaInicio)} - ${_hora(ruta.horaFin)}',
                      ),
                      _Dato(
                        icono: Icons.location_on_outlined,
                        texto: '${ruta.paradasTotal} paradas',
                      ),
                      _Dato(
                        icono: Icons.task_alt_rounded,
                        texto: '${ruta.paradasHechas} recolectadas',
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: LinearProgressIndicator(
                      value: ruta.progreso,
                      minHeight: 8,
                      color: visual.color,
                      backgroundColor: visual.fondo,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(visual.icono, size: 18, color: visual.color),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '${etiquetaEstadoRuta(ruta.estado)} · '
                          '${ruta.paradasHechas}/${ruta.paradasTotal}',
                          style: Theme.of(context).textTheme.labelMedium
                              ?.copyWith(color: visual.color),
                        ),
                      ),
                      const Icon(Icons.chevron_right_rounded),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ChipEstado extends StatelessWidget {
  const _ChipEstado({required this.estado});

  final EstadoRutaConductor estado;

  @override
  Widget build(BuildContext context) {
    final visual = Theme.of(
      context,
    ).extension<ColoresProceso>()!.para(_estadoProcesoConductor(estado));

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: visual.fondo,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(visual.icono, size: 16, color: visual.color),
          const SizedBox(width: 8),
          Text(
            etiquetaEstadoRuta(estado),
            style: TextStyle(color: visual.color),
          ),
        ],
      ),
    );
  }
}

class _Dato extends StatelessWidget {
  const _Dato({required this.icono, required this.texto});

  final IconData icono;
  final String texto;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(icono, size: 18, color: EcoColors.textoSecundario),
      const SizedBox(width: 8),
      Text(
        texto,
        style: Theme.of(context).textTheme.labelMedium
            ?.copyWith(color: EcoColors.textoSecundario),
      ),
    ],
  );
}

class _Mensaje extends StatelessWidget {
  const _Mensaje({required this.icono, required this.titulo, this.accion});

  final IconData icono;
  final String titulo;
  final Widget? accion;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icono, size: 48, color: EcoColors.textoSecundario),
          const SizedBox(height: 16),
          Text(titulo, textAlign: TextAlign.center),
          if (accion != null) ...[const SizedBox(height: 16), accion!],
        ],
      ),
    ),
  );
}

EstadoProcesoPanel _estadoProcesoConductor(EstadoRutaConductor estado) =>
    switch (estado) {
      EstadoRutaConductor.pendiente => EstadoProcesoPanel.asignada,
      EstadoRutaConductor.enProceso => EstadoProcesoPanel.enCurso,
      EstadoRutaConductor.completado => EstadoProcesoPanel.completada,
      EstadoRutaConductor.cancelado => EstadoProcesoPanel.inactivo,
    };

String _hora(DateTime fecha) =>
    '${fecha.hour.toString().padLeft(2, '0')}:'
    '${fecha.minute.toString().padLeft(2, '0')}';

const _meses = [
  'enero',
  'febrero',
  'marzo',
  'abril',
  'mayo',
  'junio',
  'julio',
  'agosto',
  'septiembre',
  'octubre',
  'noviembre',
  'diciembre',
];

String _fechaLarga(DateTime fecha) =>
    '${_diasSemana[fecha.weekday - 1]} ${fecha.day} de '
    '${_meses[fecha.month - 1]}';

const _diasSemana = [
  'lunes',
  'martes',
  'miércoles',
  'jueves',
  'viernes',
  'sábado',
  'domingo',
];

String _saludoHora() {
  final hora = DateTime.now().hour;
  if (hora < 12) return 'Buenos días';
  if (hora < 19) return 'Buenas tardes';
  return 'Buenas noches';
}

String _iniciales(String nombre) {
  final partes = nombre.trim().split(RegExp(r'\s+'));
  if (partes.isEmpty || partes.first.isEmpty) return 'C';
  if (partes.length == 1) return partes.first[0].toUpperCase();
  return '${partes.first[0]}${partes.last[0]}'.toUpperCase();
}

void _mostrarMensaje(BuildContext context, String mensaje) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(mensaje)));
}
