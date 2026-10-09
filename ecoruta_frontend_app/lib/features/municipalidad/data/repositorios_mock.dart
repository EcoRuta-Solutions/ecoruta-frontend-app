import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'modelos_alerta.dart';
import 'modelos_flota.dart';
import 'modelos_informe.dart';
import 'modelos_lectura_nodo.dart';
import 'modelos_panel.dart';
import 'modelos_reporte_ciudadano.dart';
import 'modelos_ruta.dart';
import 'panel_mock.dart';

abstract interface class RepositorioPanel {
  Future<DatosPanel> cargar();
}

class RepositorioPanelMock implements RepositorioPanel {
  RepositorioPanelMock(this._contenedores);

  final RepositorioContenedores _contenedores;

  @override
  Future<DatosPanel> cargar() async {
    await Future<void>.delayed(const Duration(milliseconds: 600));
    final nodos = await _contenedores.listar();
    return DatosPanel(nodos: nodos, resumen: resumenDesdeNodos(nodos));
  }
}

final repositorioPanelProvider = Provider<RepositorioPanel>(
  (ref) => RepositorioPanelMock(ref.watch(repositorioContenedoresProvider)),
);

abstract interface class RepositorioContenedores {
  Future<List<NodoEstado>> listar();
  Future<NodoEstado?> obtener(int id);
  Future<DetalleNodo?> obtenerDetalle(int id, {required int dias});
  Future<void> guardar(NodoEstado nodo);
  Future<void> eliminar(int id);
}

class RepositorioContenedoresMock implements RepositorioContenedores {
  RepositorioContenedoresMock() : _nodos = crearDatosPanelMock().nodos.toList();

  final List<NodoEstado> _nodos;

  @override
  Future<List<NodoEstado>> listar() async => List.unmodifiable(_nodos);

  @override
  Future<NodoEstado?> obtener(int id) async {
    for (final nodo in _nodos) {
      if (nodo.id == id) return nodo;
    }
    return null;
  }

  @override
  Future<DetalleNodo?> obtenerDetalle(int id, {required int dias}) async {
    final nodo = await obtener(id);
    if (nodo == null) return null;

    final ahora = _fechaDemo;
    final cantidad = dias == 1 ? 9 : 7;
    final intervalo = dias == 1
        ? const Duration(hours: 3)
        : const Duration(days: 1);
    final lecturas = nodo.llenado == null
        ? <LecturaLlenado>[]
        : [
            for (var indice = 0; indice < cantidad; indice++)
              LecturaLlenado(
                fecha: ahora.subtract(intervalo * (cantidad - indice - 1)),
                porcentaje: _porcentajeHistorico(nodo, indice),
              ),
          ];
    final eventos = <EventoNodo>[
      if (nodo.volteado == true)
        EventoNodo(
          tipo: TipoEventoNodo.volteado,
          fecha: ahora.subtract(const Duration(minutes: 7)),
          descripcion: 'Se detectó una inclinación fuera de rango.',
        ),
      if ((nodo.bateria ?? 100) < 70)
        EventoNodo(
          tipo: TipoEventoNodo.bateriaBaja,
          fecha: ahora.subtract(const Duration(hours: 3)),
          descripcion: 'La batería requiere revisión.',
        ),
      if (nodo.estadoOperativo == EstadoOperativo.mantenimiento)
        EventoNodo(
          tipo: TipoEventoNodo.mantenimiento,
          fecha: ahora.subtract(const Duration(days: 1)),
          descripcion: 'Inicio de mantenimiento preventivo.',
        ),
    ]..sort((a, b) => b.fecha.compareTo(a.fecha));

    return DetalleNodo(
      nodo: nodo,
      lecturas: List.unmodifiable(lecturas),
      eventos: List.unmodifiable(eventos),
      prediccion: nodo.llenado == null
          ? null
          : PrediccionLlenado(
              horaEstimadaDesborde: ahora.add(
                Duration(hours: nodo.llenado! >= 80 ? 3 : 8),
              ),
              confianza: nodo.llenado! >= 80 ? 0.91 : 0.78,
            ),
    );
  }

  @override
  Future<void> guardar(NodoEstado nodo) async {
    final index = _nodos.indexWhere((actual) => actual.id == nodo.id);
    if (index == -1) {
      _nodos.add(nodo);
    } else {
      _nodos[index] = nodo;
    }
  }

  @override
  Future<void> eliminar(int id) async {
    _nodos.removeWhere((nodo) => nodo.id == id);
  }
}

double _porcentajeHistorico(NodoEstado nodo, int indice) {
  final actual = nodo.llenado ?? 0;
  final variacion = ((nodo.id * 13 + indice * 7) % 11) - 5;
  return (actual - (8 - indice) * 1.6 + variacion).clamp(0, 100).toDouble();
}

abstract interface class RepositorioAlertas {
  Future<List<AlertaPanel>> listar();
  Future<void> asegurarNodos(List<NodoEstado> nodos);
  Future<void> reconocer(String id, {required String quien});
  Future<void> asignar(
    String id, {
    required Conductor conductor,
    required Vehiculo vehiculo,
    required String quien,
  });
  Future<void> atender(String id, {required String quien, String? nota});
}

class RepositorioAlertasMock implements RepositorioAlertas {
  RepositorioAlertasMock() : _alertas = _crearAlertasDemo();

  final List<AlertaPanel> _alertas;

  @override
  Future<void> asegurarNodos(List<NodoEstado> nodos) async {
    final porNodoTipo = {
      for (final alerta in _alertas) '${alerta.nodoId}:${alerta.tipo}': alerta,
    };
    for (final nodo in nodos) {
      final motivos = <TipoAlerta>[
        if (nodo.estado == EstadoNodo.critico) TipoAlerta.critico,
        if (nodo.estado == EstadoNodo.alerta) TipoAlerta.enAlerta,
        if (nodo.volteado == true) TipoAlerta.volteado,
        if (nodo.bateria != null && nodo.bateria! < 25) TipoAlerta.bateriaBaja,
        if (nodo.estado == EstadoNodo.sinDatos) TipoAlerta.sinDatos,
      ];
      for (final tipo in motivos) {
        porNodoTipo.putIfAbsent(
          '${nodo.id}:$tipo',
          () => _alerta('ALT-${nodo.codigo}-${tipo.name}', nodo.id, tipo),
        );
      }
    }
    _alertas
      ..clear()
      ..addAll(porNodoTipo.values);
  }

  @override
  Future<List<AlertaPanel>> listar() async => List.unmodifiable(_alertas);

  @override
  Future<void> reconocer(String id, {required String quien}) async {
    final alerta = _porId(id);
    if (alerta.estado != EstadoAlerta.nueva) {
      throw StateError('Solo se puede reconocer una alerta nueva.');
    }
    _actualizar(
      alerta.copyWith(
        estado: EstadoAlerta.reconocida,
        historial: [
          ...alerta.historial,
          AccionAlerta(
            que: 'Alerta reconocida',
            quien: quien,
            cuando: _fechaDemo,
          ),
        ],
      ),
    );
  }

  @override
  Future<void> asignar(
    String id, {
    required Conductor conductor,
    required Vehiculo vehiculo,
    required String quien,
  }) async {
    if (conductor.estado != EstadoConductor.disponible) {
      throw StateError('El conductor no está disponible.');
    }
    if (vehiculo.estado != EstadoVehiculo.operativo) {
      throw StateError('El vehículo no está operativo.');
    }
    final alerta = _porId(id);
    if (alerta.estado != EstadoAlerta.reconocida) {
      throw StateError('Primero se debe reconocer la alerta.');
    }
    _actualizar(
      alerta.copyWith(
        estado: EstadoAlerta.asignada,
        asignadoA: conductor.nombre,
        historial: [
          ...alerta.historial,
          AccionAlerta(
            que: 'Asignada a ${conductor.nombre} · ${vehiculo.placa}',
            quien: quien,
            cuando: _fechaDemo,
          ),
        ],
      ),
    );
  }

  @override
  Future<void> atender(String id, {required String quien, String? nota}) async {
    final alerta = _porId(id);
    if (alerta.estado != EstadoAlerta.asignada) {
      throw StateError('Solo se puede atender una alerta asignada.');
    }
    _actualizar(
      alerta.copyWith(
        estado: EstadoAlerta.atendida,
        historial: [
          ...alerta.historial,
          AccionAlerta(
            que: 'Alerta atendida',
            quien: quien,
            cuando: _fechaDemo,
            nota: nota,
          ),
        ],
      ),
    );
  }

  AlertaPanel _porId(String id) => _alertas.firstWhere(
    (alerta) => alerta.id == id,
    orElse: () => throw StateError('No existe la alerta solicitada.'),
  );

  void _actualizar(AlertaPanel alerta) {
    final index = _alertas.indexWhere((actual) => actual.id == alerta.id);
    _alertas[index] = alerta;
  }
}

abstract interface class RepositorioRutas {
  Future<List<RutaMunicipal>> listar();
  Future<void> guardar(RutaMunicipal ruta);
  Future<void> aprobar(String id, {required String quien});
  Future<void> reasignar(
    String id, {
    required Conductor conductor,
    required Vehiculo vehiculo,
    required String quien,
  });
}

class RepositorioRutasMock implements RepositorioRutas {
  final List<RutaMunicipal> _rutas = _rutasDemo.toList();

  @override
  Future<List<RutaMunicipal>> listar() async => List.unmodifiable(_rutas);

  @override
  Future<void> guardar(RutaMunicipal ruta) async {
    final index = _rutas.indexWhere((actual) => actual.id == ruta.id);
    if (index == -1) {
      _rutas.add(ruta);
    } else {
      _rutas[index] = ruta;
    }
  }

  @override
  Future<void> aprobar(String id, {required String quien}) async {
    final ruta = _porId(id);
    if (ruta.estado != EstadoRuta.propuesta) {
      throw StateError('Solo se pueden aprobar rutas propuestas.');
    }
    _actualizar(
      ruta.copiar(
        estado: EstadoRuta.aprobada,
        historial: [
          ...ruta.historial,
          AccionRuta(que: 'Ruta aprobada', quien: quien, cuando: _fechaDemo),
        ],
      ),
    );
  }

  @override
  Future<void> reasignar(
    String id, {
    required Conductor conductor,
    required Vehiculo vehiculo,
    required String quien,
  }) async {
    if (conductor.estado != EstadoConductor.disponible) {
      throw StateError('El conductor no está disponible.');
    }
    if (vehiculo.estado != EstadoVehiculo.operativo) {
      throw StateError('El vehículo no está operativo.');
    }
    if (conductor.vehiculoAsignado != null &&
        conductor.vehiculoAsignado != vehiculo.id) {
      throw StateError('El vehículo no está asignado a este conductor.');
    }
    final ruta = _porId(id);
    if (ruta.estado == EstadoRuta.completada) {
      throw StateError('No se puede reasignar una ruta completada.');
    }
    _actualizar(
      ruta.copiar(
        conductorId: conductor.id,
        vehiculoId: vehiculo.id,
        historial: [
          ...ruta.historial,
          AccionRuta(
            que: 'Asignada a ${conductor.nombre} · ${vehiculo.placa}',
            quien: quien,
            cuando: _fechaDemo,
          ),
        ],
      ),
    );
  }

  RutaMunicipal _porId(String id) => _rutas.firstWhere(
    (ruta) => ruta.id == id,
    orElse: () => throw StateError('No existe la ruta solicitada.'),
  );

  void _actualizar(RutaMunicipal ruta) {
    final index = _rutas.indexWhere((actual) => actual.id == ruta.id);
    _rutas[index] = ruta;
  }
}

abstract interface class RepositorioFlota {
  Future<List<Conductor>> conductores();
  Future<List<Vehiculo>> vehiculos();
  Future<List<UsuarioPanel>> usuarios();
  Future<void> guardarConductor(Conductor conductor);
  Future<void> guardarVehiculo(Vehiculo vehiculo);
  Future<void> guardarUsuario(UsuarioPanel usuario);
}

class RepositorioFlotaMock implements RepositorioFlota {
  final List<Conductor> _conductores = _conductoresDemo.toList();
  final List<Vehiculo> _vehiculos = _vehiculosDemo.toList();
  final List<UsuarioPanel> _usuarios = _usuariosDemo.toList();

  @override
  Future<List<Conductor>> conductores() async =>
      List.unmodifiable(_conductores);

  @override
  Future<List<Vehiculo>> vehiculos() async => List.unmodifiable(_vehiculos);

  @override
  Future<List<UsuarioPanel>> usuarios() async => List.unmodifiable(_usuarios);

  @override
  Future<void> guardarConductor(Conductor conductor) async {
    if (!conductor.activo && conductor.estado == EstadoConductor.enRuta) {
      throw StateError(
        'No se puede desactivar a un conductor con una ruta en curso.',
      );
    }
    final indice = _conductores.indexWhere(
      (actual) => actual.id == conductor.id,
    );
    if (indice < 0) {
      _conductores.add(conductor);
    } else {
      _conductores[indice] = conductor;
    }
  }

  @override
  Future<void> guardarVehiculo(Vehiculo vehiculo) async {
    final indice = _vehiculos.indexWhere((actual) => actual.id == vehiculo.id);
    if (indice < 0) {
      _vehiculos.add(vehiculo);
    } else {
      _vehiculos[indice] = vehiculo;
    }
  }

  @override
  Future<void> guardarUsuario(UsuarioPanel usuario) async {
    final indice = _usuarios.indexWhere((actual) => actual.id == usuario.id);
    if (indice < 0) {
      _usuarios.add(usuario);
    } else {
      _usuarios[indice] = usuario;
    }
  }
}

abstract interface class RepositorioReportesCiudadanos {
  Future<List<ReporteCiudadano>> listar();
  Future<void> iniciarAtencion(
    String id, {
    required String asignadoA,
    required String quien,
  });
  Future<void> resolver(String id, {required String quien, String? nota});
}

class RepositorioReportesCiudadanosMock
    implements RepositorioReportesCiudadanos {
  final List<ReporteCiudadano> _reportes = _reportesDemo.toList();

  @override
  Future<List<ReporteCiudadano>> listar() async => List.unmodifiable(_reportes);

  @override
  Future<void> iniciarAtencion(
    String id, {
    required String asignadoA,
    required String quien,
  }) async {
    final reporte = _porId(id);
    if (reporte.estado != EstadoReporte.recibido) {
      throw StateError('Solo se pueden asignar reportes recibidos.');
    }
    _actualizar(
      reporte.copiar(
        estado: EstadoReporte.enAtencion,
        asignadoA: asignadoA,
        historial: [
          ...reporte.historial,
          AccionReporte(
            que: 'Reporte asignado a $asignadoA',
            quien: quien,
            cuando: _fechaDemo,
          ),
        ],
      ),
    );
  }

  @override
  Future<void> resolver(
    String id, {
    required String quien,
    String? nota,
  }) async {
    final reporte = _porId(id);
    if (reporte.estado != EstadoReporte.enAtencion) {
      throw StateError('Primero se debe asignar el reporte.');
    }
    _actualizar(
      reporte.copiar(
        estado: EstadoReporte.resuelto,
        historial: [
          ...reporte.historial,
          AccionReporte(
            que: 'Reporte resuelto',
            quien: quien,
            cuando: _fechaDemo,
            nota: nota,
          ),
        ],
      ),
    );
  }

  ReporteCiudadano _porId(String id) => _reportes.firstWhere(
    (reporte) => reporte.id == id,
    orElse: () => throw StateError('No existe el reporte solicitado.'),
  );

  void _actualizar(ReporteCiudadano reporte) {
    final index = _reportes.indexWhere((actual) => actual.id == reporte.id);
    _reportes[index] = reporte;
  }
}

abstract interface class RepositorioInformes {
  Future<DatosInforme> cargar(DateTime inicio, DateTime fin);
}

class RepositorioInformesMock implements RepositorioInformes {
  @override
  Future<DatosInforme> cargar(DateTime inicio, DateTime fin) async =>
      _informeDemo(inicio, fin);
}

final repositorioContenedoresProvider = Provider<RepositorioContenedores>(
  (ref) => RepositorioContenedoresMock(),
);
final repositorioAlertasProvider = Provider<RepositorioAlertas>(
  (ref) => RepositorioAlertasMock(),
);
final repositorioRutasProvider = Provider<RepositorioRutas>(
  (ref) => RepositorioRutasMock(),
);
final repositorioFlotaProvider = Provider<RepositorioFlota>(
  (ref) => RepositorioFlotaMock(),
);
final repositorioReportesCiudadanosProvider =
    Provider<RepositorioReportesCiudadanos>(
      (ref) => RepositorioReportesCiudadanosMock(),
    );
final repositorioInformesProvider = Provider<RepositorioInformes>(
  (ref) => RepositorioInformesMock(),
);

final _fechaDemo = DateTime(2026, 10, 8, 12);

List<AlertaPanel> _crearAlertasDemo() {
  final nodos = crearDatosPanelMock(ahora: _fechaDemo).nodos;
  final alertas = <AlertaPanel>[];
  for (final nodo in nodos) {
    if (nodo.estado == EstadoNodo.critico) {
      alertas.add(_alerta('ALT-${nodo.codigo}-C', nodo.id, TipoAlerta.critico));
    } else if (nodo.estado == EstadoNodo.alerta) {
      alertas.add(
        _alerta('ALT-${nodo.codigo}-A', nodo.id, TipoAlerta.enAlerta),
      );
    }
    if (nodo.volteado == true) {
      alertas.add(
        _alerta('ALT-${nodo.codigo}-V', nodo.id, TipoAlerta.volteado),
      );
    }
  }
  return alertas;
}

AlertaPanel _alerta(String id, int nodoId, TipoAlerta tipo) => AlertaPanel(
  id: id,
  nodoId: nodoId,
  tipo: tipo,
  estado: EstadoAlerta.nueva,
  creada: _fechaDemo.subtract(Duration(minutes: nodoId * 7)),
  historial: const [],
);

final _conductoresDemo = <Conductor>[
  const Conductor(
    id: 1,
    nombre: 'Luis Rodríguez',
    telefono: '944 123 456',
    categoriaLicencia: 'A-IIb',
    estado: EstadoConductor.disponible,
    vehiculoAsignado: 1,
  ),
  const Conductor(
    id: 2,
    nombre: 'María Flores',
    telefono: '955 234 567',
    categoriaLicencia: 'A-IIIa',
    estado: EstadoConductor.enRuta,
    vehiculoAsignado: 2,
  ),
  const Conductor(
    id: 3,
    nombre: 'José Castillo',
    telefono: '966 345 678',
    categoriaLicencia: 'A-IIb',
    estado: EstadoConductor.descanso,
    vehiculoAsignado: 3,
  ),
];

final _vehiculosDemo = <Vehiculo>[
  const Vehiculo(
    id: 1,
    placa: 'TCA-241',
    tipo: 'Compactador',
    capacidadToneladas: 8,
    estado: EstadoVehiculo.operativo,
  ),
  const Vehiculo(
    id: 2,
    placa: 'TCA-508',
    tipo: 'Volquete',
    capacidadToneladas: 6,
    estado: EstadoVehiculo.operativo,
  ),
  const Vehiculo(
    id: 3,
    placa: 'TCA-316',
    tipo: 'Compactador',
    capacidadToneladas: 8,
    estado: EstadoVehiculo.mantenimiento,
  ),
];

final _usuariosDemo = <UsuarioPanel>[
  const UsuarioPanel(
    id: 1,
    nombre: 'Ana Sánchez',
    correo: 'ana.sanchez@ecoruta.pe',
    rol: RolPanel.administrador,
    activo: true,
  ),
  const UsuarioPanel(
    id: 2,
    nombre: 'Pedro Vega',
    correo: 'pedro.vega@ecoruta.pe',
    rol: RolPanel.operador,
    activo: true,
  ),
  const UsuarioPanel(
    id: 3,
    nombre: 'Rosa Mendoza',
    correo: 'rosa.mendoza@ecoruta.pe',
    rol: RolPanel.supervisor,
    activo: true,
  ),
];

final _rutasDemo = <RutaMunicipal>[
  RutaMunicipal(
    id: 'RUT-001',
    nombre: 'Centro mañana',
    zona: 'Centro',
    estado: EstadoRuta.propuesta,
    paradas: [
      ParadaRuta(nodoId: 1, orden: 1, horaEstimada: DateTime(2026, 10, 8, 8)),
      ParadaRuta(
        nodoId: 2,
        orden: 2,
        horaEstimada: DateTime(2026, 10, 8, 8, 20),
      ),
    ],
    distanciaKm: 18.4,
    duracionMin: 76,
    distanciaFijaKm: 22,
    duracionFijaMin: 94,
    paradasFijas: 8,
    conductorId: 1,
    vehiculoId: 1,
  ),
  RutaMunicipal(
    id: 'RUT-002',
    nombre: 'Víctor Larco tarde',
    zona: 'Víctor Larco',
    estado: EstadoRuta.enCurso,
    paradas: [
      ParadaRuta(nodoId: 3, orden: 1, horaEstimada: DateTime(2026, 10, 8, 15)),
      ParadaRuta(
        nodoId: 5,
        orden: 2,
        horaEstimada: DateTime(2026, 10, 8, 15, 30),
      ),
    ],
    distanciaKm: 24.6,
    duracionMin: 92,
    distanciaFijaKm: 29,
    duracionFijaMin: 115,
    paradasFijas: 9,
    conductorId: 2,
    vehiculoId: 2,
  ),
];

final _reportesDemo = <ReporteCiudadano>[
  ReporteCiudadano(
    id: 'REP-001',
    categoria: CategoriaReporte.contenedorLleno,
    descripcion: 'El contenedor está lleno desde esta mañana.',
    latitud: -8.1116,
    longitud: -79.0288,
    fecha: DateTime(2026, 10, 8, 9, 30),
    estado: EstadoReporte.recibido,
    nodoRelacionado: 1,
    historial: const [],
  ),
  ReporteCiudadano(
    id: 'REP-002',
    categoria: CategoriaReporte.basuraAcumulada,
    descripcion: 'Se acumularon bolsas alrededor del punto de recojo.',
    latitud: -8.1232,
    longitud: -79.0358,
    fecha: DateTime(2026, 10, 7, 17, 15),
    estado: EstadoReporte.enAtencion,
    asignadoA: 'Luis Rodríguez',
    historial: const [],
  ),
];

DatosInforme _informeDemo(DateTime inicio, DateTime fin) => DatosInforme(
  inicio: inicio,
  fin: fin,
  kpis: const [
    KpiInforme(
      clave: 'ahorro_km',
      nombre: 'Reducción de km',
      valor: 16.4,
      meta: MetasKpiInforme.reduccionKm,
      unidad: '%',
      mayorEsMejor: true,
    ),
    KpiInforme(
      clave: 'reduccion_desbordes',
      nombre: 'Reducción de desbordes',
      valor: 42,
      meta: MetasKpiInforme.reduccionDesbordes,
      unidad: '%',
      mayorEsMejor: true,
    ),
    KpiInforme(
      clave: 'mae',
      nombre: 'Error de predicción MAE',
      valor: 3.2,
      meta: MetasKpiInforme.errorPrediccionHoras,
      unidad: 'h',
      mayorEsMejor: false,
    ),
    KpiInforme(
      clave: 'disponibilidad',
      nombre: 'Disponibilidad de nodos',
      valor: 94,
      meta: MetasKpiInforme.disponibilidadNodos,
      unidad: '%',
      mayorEsMejor: true,
    ),
    KpiInforme(
      clave: 'rutas_ejecutadas',
      nombre: 'Rutas ejecutadas',
      valor: 76,
      meta: MetasKpiInforme.rutasEjecutadas,
      unidad: '%',
      mayorEsMejor: true,
    ),
  ],
  llenadoPromedio: [
    PuntoSerieInforme(fecha: inicio, valor: 48),
    PuntoSerieInforme(fecha: inicio.add(const Duration(days: 1)), valor: 52),
    PuntoSerieInforme(fecha: fin, valor: 46),
  ],
  desbordesPorZona: const {
    'Centro': 2,
    'Víctor Larco': 1,
    'La Esperanza': 3,
    'El Porvenir': 2,
  },
  kilometrosOptimizados: [
    PuntoSerieInforme(fecha: inicio, valor: 82),
    PuntoSerieInforme(fecha: fin, valor: 74),
  ],
  kilometrosFijos: [
    PuntoSerieInforme(fecha: inicio, valor: 100),
    PuntoSerieInforme(fecha: fin, valor: 100),
  ],
);
