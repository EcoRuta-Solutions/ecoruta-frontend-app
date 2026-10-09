import 'modelos_panel.dart';

class DatosPanel {
  const DatosPanel({required this.nodos, required this.resumen});

  final List<NodoEstado> nodos;
  final ResumenPanel resumen;
}

DatosPanel crearDatosPanelMock({DateTime? ahora}) {
  final momento = ahora ?? DateTime(2026, 10, 8, 12);
  final nodos = <NodoEstado>[
    _nodo(
      1,
      'TRU-001',
      'Mercado Central',
      -8.1116,
      -79.0288,
      94,
      EstadoNodo.critico,
      momento.subtract(const Duration(minutes: 2)),
      zona: 'Centro',
      bateria: 84,
    ),
    _nodo(
      2,
      'TRU-002',
      'Av. España',
      -8.1099,
      -79.0310,
      86,
      EstadoNodo.critico,
      momento.subtract(const Duration(minutes: 7)),
      volteado: true,
      zona: 'Centro',
      bateria: 65,
    ),
    _nodo(
      3,
      'TRU-003',
      'Plaza de Armas',
      -8.1110,
      -79.0279,
      77,
      EstadoNodo.alerta,
      momento.subtract(const Duration(minutes: 12)),
      zona: 'Víctor Larco',
      bateria: 92,
    ),
    _nodo(
      4,
      'TRU-004',
      'Urb. Primavera',
      -8.1048,
      -79.0322,
      70,
      EstadoNodo.alerta,
      momento.subtract(const Duration(minutes: 18)),
      zona: 'La Esperanza',
      bateria: 77,
    ),
    _nodo(
      5,
      'TRU-005',
      'Av. Larco',
      -8.1232,
      -79.0358,
      54,
      EstadoNodo.normal,
      momento.subtract(const Duration(minutes: 23)),
      zona: 'Víctor Larco',
    ),
    _nodo(
      6,
      'TRU-006',
      'Parque César Vallejo',
      -8.1162,
      -79.0209,
      39,
      EstadoNodo.normal,
      momento.subtract(const Duration(minutes: 31)),
      zona: 'El Porvenir',
    ),
    _nodo(
      7,
      'TRU-007',
      'Urb. El Recreo',
      -8.1181,
      -79.0271,
      18,
      EstadoNodo.normal,
      momento.subtract(const Duration(minutes: 46)),
      zona: 'El Porvenir',
    ),
    NodoEstado(
      id: 8,
      codigo: 'TRU-008',
      nombre: 'Av. América Oeste',
      latitud: -8.1080,
      longitud: -79.0390,
      umbralCritico: 80,
      llenado: null,
      volteado: false,
      ultimaLectura: null,
      estado: EstadoNodo.sinDatos,
      zona: 'La Esperanza',
      bateria: 58,
      senal: 2,
    ),
  ];

  return DatosPanel(
    nodos: List.unmodifiable(nodos),
    resumen: resumenDesdeNodos(nodos),
  );
}

ResumenPanel resumenDesdeNodos(List<NodoEstado> nodos) {
  final lecturas = nodos.where((nodo) => nodo.llenado != null).toList();
  final promedio = lecturas.isEmpty
      ? null
      : lecturas.fold<double>(0, (suma, nodo) => suma + nodo.llenado!) /
            lecturas.length;
  return ResumenPanel(
    totalNodos: nodos.length,
    criticos: _contar(nodos, EstadoNodo.critico),
    alertas: _contar(nodos, EstadoNodo.alerta),
    normales: _contar(nodos, EstadoNodo.normal),
    sinDatos: _contar(nodos, EstadoNodo.sinDatos),
    promedioLlenado: promedio,
  );
}

NodoEstado _nodo(
  int id,
  String codigo,
  String nombre,
  double latitud,
  double longitud,
  double llenado,
  EstadoNodo estado,
  DateTime ultimaLectura, {
  bool volteado = false,
  String zona = 'Centro',
  int bateria = 88,
}) => NodoEstado(
  id: id,
  codigo: codigo,
  nombre: nombre,
  latitud: latitud,
  longitud: longitud,
  umbralCritico: 80,
  llenado: llenado,
  volteado: volteado,
  ultimaLectura: ultimaLectura,
  estado: estado,
  zona: zona,
  capacidadLitros: 1100,
  bateria: bateria,
  senal: 4,
  firmware: '2.4.1',
  fechaInstalacion: DateTime.utc(2024, 3, id),
);

int _contar(List<NodoEstado> nodos, EstadoNodo estado) =>
    nodos.where((nodo) => nodo.estado == estado).length;
