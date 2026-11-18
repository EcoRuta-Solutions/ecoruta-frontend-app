import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/app_config.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/ubicacion/servicio_ubicacion.dart';
import '../data/modelos_reportes_campo.dart';
import '../data/repositorio_reportes_campo.dart';
import 'reportes_campo_providers.dart';
import 'widgets/aviso_datos_ejemplo.dart';
import 'widgets/visual_llenado.dart';

const mensajeLejosDelPunto =
    'Estás a más de 150 m del punto; el reporte se guardó igual';

/// Abre la hoja "Reportar llenado" de un punto crítico. Devuelve el reporte
/// guardado, o null si se cerró sin enviar.
Future<ReporteCampo?> mostrarHojaReportarLlenado(
  BuildContext context, {
  required String codigoPunto,
}) => showModalBottomSheet<ReporteCampo>(
  context: context,
  showDragHandle: true,
  isScrollControlled: true,
  backgroundColor: EcoColors.superficie,
  shape: const RoundedRectangleBorder(
    borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
  ),
  builder: (_) => HojaReportarLlenado(codigoPunto: codigoPunto),
);

enum _Fase { formulario, ubicando, enviando, error, enviado }

class HojaReportarLlenado extends ConsumerStatefulWidget {
  const HojaReportarLlenado({required this.codigoPunto, super.key});

  final String codigoPunto;

  @override
  ConsumerState<HojaReportarLlenado> createState() =>
      _HojaReportarLlenadoState();
}

class _HojaReportarLlenadoState extends ConsumerState<HojaReportarLlenado> {
  final _observacion = TextEditingController();
  NivelLlenado? _nivel;
  _Fase _fase = _Fase.formulario;
  String? _error;
  ReporteCampo? _reporte;

  /// Se pide una sola vez: al reintentar se reutiliza.
  Coordenadas? _ubicacion;
  bool _ubicacionPedida = false;

  @override
  void dispose() {
    _observacion.dispose();
    super.dispose();
  }

  Future<void> _enviar() async {
    final nivel = _nivel;
    if (nivel == null) return;

    if (!_ubicacionPedida) {
      setState(() => _fase = _Fase.ubicando);
      _ubicacion = await ref
          .read(servicioUbicacionProvider)
          .ubicacionActual();
      _ubicacionPedida = true;
      if (!mounted) return;
    }

    setState(() => _fase = _Fase.enviando);
    try {
      final reporte = await ref
          .read(repositorioReportesCampoProvider)
          .crear(
            NuevoReporteCampo(
              codigoPunto: widget.codigoPunto,
              estado: nivel,
              observacion: _observacion.text,
              lat: _ubicacion?.lat,
              lon: _ubicacion?.lon,
            ),
          );
      if (!mounted) return;
      refrescarTrasReporte(ref, widget.codigoPunto);
      setState(() {
        _reporte = reporte;
        _fase = _Fase.enviado;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = mensajeErrorReporte(error);
        _fase = _Fase.error;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final ancho = MediaQuery.sizeOf(context).width;
    final margen = ancho < EcoLayout.anchoCompacto ? 24.0 : 32.0;
    return SafeArea(
      child: Padding(
        // Deja ver la observación por encima del teclado.
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(margen, 8, margen, 32),
              child: AnimatedSize(
                duration: const Duration(milliseconds: 200),
                alignment: Alignment.topCenter,
                child: switch (_fase) {
                  _Fase.formulario => _formulario(context),
                  _Fase.ubicando => const _Progreso(
                    texto: 'Obteniendo tu ubicación…',
                  ),
                  _Fase.enviando => const _Progreso(
                    texto: 'Enviando reporte…',
                  ),
                  _Fase.error => _ErrorEnvio(
                    mensaje: _error ?? 'No se pudo enviar el reporte.',
                    onReintentar: _enviar,
                    onEditar: () =>
                        setState(() => _fase = _Fase.formulario),
                  ),
                  _Fase.enviado => _Confirmacion(
                    reporte: _reporte!,
                    sinUbicacion: _ubicacion == null,
                    onListo: () => Navigator.of(context).pop(_reporte),
                  ),
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _formulario(BuildContext context) {
    final textos = Theme.of(context).textTheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Reportar llenado',
          style: textos.titleLarge?.copyWith(color: EcoColors.primario),
        ),
        const SizedBox(height: 4),
        Text(
          'Punto crítico ${widget.codigoPunto}',
          style: textos.bodyMedium?.copyWith(color: EcoColors.textoSecundario),
        ),
        if (AppConfig.usarDatosDeEjemplo) ...[
          const SizedBox(height: 12),
          const Align(
            alignment: Alignment.centerLeft,
            child: AvisoDatosEjemplo(),
          ),
        ],
        const SizedBox(height: 20),
        Text('¿Cómo está el punto ahora?', style: textos.titleSmall),
        const SizedBox(height: 12),
        for (final fila in const [
          [NivelLlenado.vacio, NivelLlenado.medio],
          [NivelLlenado.lleno, NivelLlenado.desbordado],
        ]) ...[
          Row(
            children: [
              for (final nivel in fila) ...[
                if (nivel != fila.first) const SizedBox(width: 12),
                Expanded(
                  child: _OpcionLlenado(
                    nivel: nivel,
                    seleccionada: _nivel == nivel,
                    onTap: () => setState(() => _nivel = nivel),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 12),
        ],
        const SizedBox(height: 8),
        TextField(
          key: const Key('reporte-observacion'),
          controller: _observacion,
          maxLength: NuevoReporteCampo.maximoObservacion,
          minLines: 2,
          maxLines: 4,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(
            labelText: 'Observación (opcional)',
            hintText: 'Ej.: bolsas fuera del contenedor',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: 52,
          child: FilledButton.icon(
            onPressed: _nivel == null ? null : _enviar,
            icon: const Icon(Icons.send_rounded),
            label: const Text('Enviar'),
          ),
        ),
        if (_nivel == null) ...[
          const SizedBox(height: 8),
          Text(
            'Elige el nivel que ves en el punto.',
            textAlign: TextAlign.center,
            style: textos.bodySmall?.copyWith(
              color: EcoColors.textoSecundario,
            ),
          ),
        ],
      ],
    );
  }
}

/// Opción grande (Vacío / Medio / Lleno / Desbordado).
class _OpcionLlenado extends StatelessWidget {
  const _OpcionLlenado({
    required this.nivel,
    required this.seleccionada,
    required this.onTap,
  });

  final NivelLlenado nivel;
  final bool seleccionada;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final visual = visualLlenado(context, nivel);
    return Semantics(
      button: true,
      selected: seleccionada,
      label: nivel.etiqueta,
      excludeSemantics: true,
      child: Material(
        key: Key('opcion-llenado-${nivel.valorApi}'),
        color: seleccionada ? visual.fondo : EcoColors.superficie,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: seleccionada ? visual.color : EcoColors.borde,
            width: seleccionada ? 2 : 1,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 96),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(visual.icono, size: 32, color: visual.color),
                  const SizedBox(height: 8),
                  Text(
                    nivel.etiqueta,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: seleccionada ? visual.color : EcoColors.texto,
                      fontWeight: FontWeight.w700,
                    ),
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

class _Progreso extends StatelessWidget {
  const _Progreso({required this.texto});

  final String texto;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 48),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const CircularProgressIndicator(),
        const SizedBox(height: 16),
        Text(texto, textAlign: TextAlign.center),
      ],
    ),
  );
}

class _ErrorEnvio extends StatelessWidget {
  const _ErrorEnvio({
    required this.mensaje,
    required this.onReintentar,
    required this.onEditar,
  });

  final String mensaje;
  final VoidCallback onReintentar;
  final VoidCallback onEditar;

  @override
  Widget build(BuildContext context) {
    final critico = Theme.of(context).extension<ColoresEstado>()!.critico;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Icon(Icons.cloud_off_outlined, size: 40, color: critico.color),
          const SizedBox(height: 16),
          Text(
            'No se pudo enviar el reporte',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Text(
            mensaje,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium
                ?.copyWith(color: EcoColors.textoSecundario),
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: onReintentar,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Reintentar'),
          ),
          const SizedBox(height: 8),
          TextButton(onPressed: onEditar, child: const Text('Editar reporte')),
        ],
      ),
    );
  }
}

class _Confirmacion extends StatelessWidget {
  const _Confirmacion({
    required this.reporte,
    required this.sinUbicacion,
    required this.onListo,
  });

  final ReporteCampo reporte;
  final bool sinUbicacion;
  final VoidCallback onListo;

  @override
  Widget build(BuildContext context) {
    final colores = Theme.of(context).extension<ColoresEstado>()!;
    final textos = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Icon(
            Icons.check_circle_rounded,
            size: 48,
            color: colores.normal.color,
          ),
          const SizedBox(height: 12),
          Semantics(
            liveRegion: true,
            child: Text(
              'Reporte enviado',
              textAlign: TextAlign.center,
              style: textos.titleLarge?.copyWith(color: EcoColors.primario),
            ),
          ),
          const SizedBox(height: 12),
          Center(child: ChipLlenado(nivel: reporte.estado)),
          const SizedBox(height: 8),
          Text(
            'Punto ${reporte.codigoPunto} · ${fechaHoraReporte(reporte.creadoEn)}',
            textAlign: TextAlign.center,
            style: textos.bodyMedium?.copyWith(
              color: EcoColors.textoSecundario,
            ),
          ),
          if (reporte.lejosDelPunto) ...[
            const SizedBox(height: 16),
            _Aviso(
              icono: Icons.wrong_location_outlined,
              texto: mensajeLejosDelPunto,
              visual: colores.alerta,
            ),
          ],
          if (sinUbicacion) ...[
            const SizedBox(height: 16),
            _Aviso(
              icono: Icons.location_disabled_outlined,
              texto: 'Se envió sin ubicación (GPS apagado o sin permiso).',
              visual: colores.sinDatos,
            ),
          ],
          if (reporte.esDemo) ...[
            const SizedBox(height: 16),
            _Aviso(
              icono: Icons.science_outlined,
              texto:
                  'Reporte de una cuenta demo: no cambia el estado del punto.',
              visual: colores.sinDatos,
            ),
          ],
          const SizedBox(height: 24),
          FilledButton(onPressed: onListo, child: const Text('Listo')),
        ],
      ),
    );
  }
}

class _Aviso extends StatelessWidget {
  const _Aviso({required this.icono, required this.texto, required this.visual});

  final IconData icono;
  final String texto;
  final EstadoVisual visual;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: visual.fondo,
      borderRadius: BorderRadius.circular(12),
    ),
    child: Row(
      children: [
        Icon(icono, size: 20, color: visual.color),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            texto,
            style: Theme.of(context).textTheme.bodyMedium
                ?.copyWith(color: EcoColors.texto),
          ),
        ),
      ],
    ),
  );
}

/// Mensaje para el usuario según la respuesta del backend.
String mensajeErrorReporte(Object error) {
  if (error is! DioException) return 'Ocurrió un error inesperado.';
  final codigo = error.response?.statusCode;
  return switch (codigo) {
    null => 'No se pudo conectar con el servidor. Revisa tu conexión.',
    401 || 403 => 'Tu sesión no tiene permiso para reportar.',
    404 => 'El punto crítico no existe en el sistema.',
    422 => 'El reporte no es válido. Revisa el estado y la observación.',
    _ => 'El servidor respondió con un error ($codigo).',
  };
}
