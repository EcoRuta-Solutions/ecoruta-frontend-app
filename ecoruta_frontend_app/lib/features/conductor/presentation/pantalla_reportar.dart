import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/theme/app_theme.dart';
import '../data/repositorio_conductor.dart';
import 'accesibilidad_conductor.dart';

const _centroTrujillo = LatLng(-8.1116, -79.0288);

class PantallaReportar extends ConsumerStatefulWidget {
  const PantallaReportar({super.key});

  @override
  ConsumerState<PantallaReportar> createState() => _PantallaReportarState();
}

class _PantallaReportarState extends ConsumerState<PantallaReportar> {
  final _descripcionCtrl = TextEditingController();
  final _mapController = MapController();
  LatLng _punto = _centroTrujillo;
  bool _enviando = false;

  @override
  void dispose() {
    _descripcionCtrl.dispose();
    super.dispose();
  }

  Future<void> _enviar() async {
    final descripcion = _descripcionCtrl.text.trim();
    if (descripcion.isEmpty) {
      _mostrarMensaje('Describe la incidencia.');
      return;
    }
    setState(() => _enviando = true);
    try {
      await ref
          .read(repositorioConductorProvider)
          .crearReporte(
            latitud: _punto.latitude,
            longitud: _punto.longitude,
            descripcion: descripcion,
          );
      if (!mounted) return;
      _descripcionCtrl.clear();
      setState(() => _punto = _centroTrujillo);
      _mapController.move(_centroTrujillo, 13);
      _mostrarMensaje('Reporte enviado a la municipalidad.');
    } catch (_) {
      if (mounted) _mostrarMensaje('No se pudo enviar el reporte.');
    } finally {
      if (mounted) setState(() => _enviando = false);
    }
  }

  void _mostrarMensaje(String mensaje) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(mensaje)));
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          'Reportar incidencia',
          style: Theme.of(context).textTheme.titleLarge
              ?.copyWith(color: EcoColors.primario),
        ),
        const SizedBox(height: 4),
        Text(
          'Informa un problema en tu ruta para que la municipalidad lo atienda.',
          style: Theme.of(context).textTheme.bodyMedium
              ?.copyWith(color: EcoColors.textoSecundario),
        ),
        const SizedBox(height: 20),
        TextField(
          controller: _descripcionCtrl,
          maxLines: 4,
          maxLength: 1000,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(
            labelText: 'Descripción',
            hintText: 'Ej. Contenedor desbordado o residuos fuera del punto.',
            alignLabelWithHint: true,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'Ubicación (toca el mapa para ajustar)',
          style: Theme.of(context).textTheme.titleSmall
              ?.copyWith(color: EcoColors.primario),
        ),
        const SizedBox(height: 8),
        Card(
          clipBehavior: Clip.antiAlias,
          child: SizedBox(
            height: 240,
            child: FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: _centroTrujillo,
                initialZoom: 13,
                onTap: (_, punto) => setState(() => _punto = punto),
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.ecoruta.app.ecoruta_frontend_app',
                ),
                MarkerLayer(
                  markers: [
                    Marker(
                      point: _punto,
                      width: 44,
                      height: 44,
                      child: const Icon(
                        Icons.location_on_rounded,
                        color: EcoColors.critico,
                        size: 40,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Lat ${_punto.latitude.toStringAsFixed(5)}, '
          'Lon ${_punto.longitude.toStringAsFixed(5)}',
          style: Theme.of(context).textTheme.labelMedium
              ?.copyWith(color: EcoColors.textoSecundario),
        ),
        const SizedBox(height: 20),
        semanticaBotonConductor(
          etiqueta: _enviando ? 'Enviando reporte' : 'Enviar reporte',
          child: FilledButton.icon(
            style: estiloBotonConductor,
            onPressed: _enviando ? null : _enviar,
            icon: _enviando
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.send_rounded),
            label: Text(_enviando ? 'Enviando...' : 'Enviar reporte'),
          ),
        ),
      ],
    );
  }
}
