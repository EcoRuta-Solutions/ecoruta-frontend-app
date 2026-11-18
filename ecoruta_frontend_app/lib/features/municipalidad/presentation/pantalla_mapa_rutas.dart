import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/theme/app_theme.dart';
import '../../conductor/data/modelos_conductor.dart';
import '../data/modelos_generacion_rutas.dart';
import 'pantalla_mapa.dart';

/// Parada ya ubicada para dibujarla.
typedef ParadaEnMapa = ({int orden, String codigo, double lat, double lon});

/// Ruta de un camión para el mapa: sale de una generación o de las rutas
/// del día. Las paradas van ordenadas por `orden`.
class RutaEnMapa {
  const RutaEnMapa({
    required this.id,
    required this.placa,
    required this.paradas,
  });

  final int id;
  final String placa;
  final List<ParadaEnMapa> paradas;

  factory RutaEnMapa.desdeGenerada(RutaGenerada ruta) => RutaEnMapa(
    id: ruta.rutaId,
    placa: ruta.placa,
    paradas: [
      for (final p in ruta.paradas)
        (orden: p.orden, codigo: p.codigo, lat: p.lat, lon: p.lon),
    ],
  );

  /// Usa la ubicación del punto crítico; las paradas sin ubicación no se
  /// dibujan.
  factory RutaEnMapa.desdeRuta(RutaConductor ruta) => RutaEnMapa(
    id: ruta.id,
    placa: ruta.camion?.placa ?? 'Ruta #${ruta.id}',
    paradas: [
      for (final p in ruta.paradas)
        if (p.tieneUbicacion)
          (orden: p.orden, codigo: p.codigo, lat: p.latitud!, lon: p.longitud!),
    ],
  );
}

/// Un color por camión, distinto de los colores de llenado del mapa de
/// puntos críticos. Si hay más camiones que colores, se repiten.
const coloresCamiones = [
  Color(0xFF1F77B4),
  Color(0xFF9467BD),
  Color(0xFF0E9AA7),
  Color(0xFF8C564B),
  Color(0xFFD6338C),
  Color(0xFF3F51B5),
  Color(0xFF6D8B00),
  Color(0xFF5D6D7E),
];

Color colorDeRuta(int indice) => coloresCamiones[indice % coloresCamiones.length];

/// Mapa con la polilínea y las paradas numeradas de cada ruta, un color por
/// camión, y chips para ver todas o una sola.
class PantallaMapaRutas extends StatefulWidget {
  const PantallaMapaRutas({
    required this.rutas,
    this.rutaInicial,
    this.titulo = 'Mapa de rutas',
    super.key,
  });

  final List<RutaEnMapa> rutas;

  /// Id de la ruta a mostrar sola al abrir; null muestra todas.
  final int? rutaInicial;
  final String titulo;

  @override
  State<PantallaMapaRutas> createState() => _PantallaMapaRutasState();
}

class _PantallaMapaRutasState extends State<PantallaMapaRutas> {
  final _mapa = MapController();
  late int? _seleccion = widget.rutaInicial;

  List<(int, RutaEnMapa)> get _visibles => [
    for (var i = 0; i < widget.rutas.length; i++)
      if (_seleccion == null || widget.rutas[i].id == _seleccion)
        (i, widget.rutas[i]),
  ];

  CameraFit? _encuadre() {
    final puntos = [
      for (final (_, ruta) in _visibles)
        for (final p in ruta.paradas) LatLng(p.lat, p.lon),
    ];
    if (puntos.isEmpty) return null;
    return CameraFit.coordinates(
      coordinates: puntos,
      padding: const EdgeInsets.fromLTRB(40, 120, 40, 60),
      maxZoom: 16,
    );
  }

  void _elegir(int? id) {
    setState(() => _seleccion = id);
    final encuadre = _encuadre();
    if (encuadre != null) _mapa.fitCamera(encuadre);
  }

  @override
  Widget build(BuildContext context) {
    final visibles = _visibles;
    return Scaffold(
      appBar: AppBar(
        backgroundColor: EcoColors.fondo,
        title: Text(widget.titulo),
      ),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapa,
            options: MapOptions(
              initialCenter: PantallaMapa.centro,
              initialZoom: 13,
              initialCameraFit: _encuadre(),
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: PantallaMapa.idPaquete,
              ),
              PolylineLayer(
                polylines: [
                  for (final (i, ruta) in visibles)
                    if (ruta.paradas.length > 1)
                      Polyline(
                        points: [
                          for (final p in ruta.paradas) LatLng(p.lat, p.lon),
                        ],
                        strokeWidth: 4,
                        color: colorDeRuta(i),
                      ),
                ],
              ),
              MarkerLayer(
                markers: [
                  for (final (i, ruta) in visibles)
                    for (final p in ruta.paradas)
                      Marker(
                        point: LatLng(p.lat, p.lon),
                        width: 32,
                        height: 32,
                        child: MarcadorParadaRuta(
                          orden: p.orden,
                          color: colorDeRuta(i),
                          etiqueta: '${ruta.placa}, parada ${p.orden}: '
                              '${p.codigo}',
                        ),
                      ),
                ],
              ),
            ],
          ),
          SafeArea(
            child: Align(
              alignment: Alignment.topCenter,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Card(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    child: Row(
                      children: [
                        ChoiceChip(
                          label: const Text('Todas'),
                          selected: _seleccion == null,
                          onSelected: (_) => _elegir(null),
                        ),
                        for (var i = 0; i < widget.rutas.length; i++) ...[
                          const SizedBox(width: 8),
                          ChoiceChip(
                            avatar: CircleAvatar(
                              backgroundColor: colorDeRuta(i),
                              radius: 6,
                            ),
                            label: Text(widget.rutas[i].placa),
                            selected: _seleccion == widget.rutas[i].id,
                            onSelected: (_) => _elegir(widget.rutas[i].id),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          SafeArea(
            child: Align(
              alignment: Alignment.bottomRight,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    child: Text(
                      '© OpenStreetMap',
                      style: Theme.of(context).textTheme.labelSmall
                          ?.copyWith(color: EcoColors.textoSecundario),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Círculo con el número de orden de la parada, del color del camión.
class MarcadorParadaRuta extends StatelessWidget {
  const MarcadorParadaRuta({
    required this.orden,
    required this.color,
    required this.etiqueta,
    super.key,
  });

  final int orden;
  final Color color;
  final String etiqueta;

  @override
  Widget build(BuildContext context) => Semantics(
    label: etiqueta,
    excludeSemantics: true,
    child: Tooltip(
      message: etiqueta,
      child: Container(
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(color: EcoColors.superficie, width: 2),
        ),
        child: Text(
          '$orden',
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w700,
            fontSize: 13,
          ),
        ),
      ),
    ),
  );
}
