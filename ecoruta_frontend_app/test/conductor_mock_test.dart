import 'package:dio/dio.dart';
import 'package:ecoruta_frontend_app/features/conductor/data/generar_mi_ruta.dart';
import 'package:ecoruta_frontend_app/core/config/app_config.dart';
import 'package:ecoruta_frontend_app/core/theme/app_theme.dart';
import 'package:ecoruta_frontend_app/features/auth/data/auth_repository.dart';
import 'package:ecoruta_frontend_app/features/auth/presentation/auth_controller.dart';
import 'package:ecoruta_frontend_app/features/conductor/data/modelos_conductor.dart';
import 'package:ecoruta_frontend_app/features/conductor/data/repositorio_conductor.dart';
import 'package:ecoruta_frontend_app/features/conductor/presentation/error_conductor.dart';
import 'package:ecoruta_frontend_app/features/conductor/presentation/mis_rutas_controller.dart';
import 'package:ecoruta_frontend_app/features/conductor/presentation/pantalla_detalle_ruta.dart';
import 'package:ecoruta_frontend_app/features/conductor/presentation/pantalla_mapa_conductor.dart';
import 'package:ecoruta_frontend_app/features/conductor/presentation/pantalla_mi_ruta.dart';
import 'package:ecoruta_frontend_app/features/conductor/pantalla_inicio_conductor.dart';
import 'package:ecoruta_frontend_app/features/conductor/presentation/tarjeta_parada_conductor.dart';
import 'package:ecoruta_frontend_app/features/municipalidad/data/modelos_reportes_campo.dart';
import 'package:ecoruta_frontend_app/features/municipalidad/presentation/hoja_reportar_llenado.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('RepositorioConductorMock', () {
    late RepositorioConductorMock repositorio;

    setUp(() {
      repositorio = RepositorioConductorMock();
    });

    test('usa puntos críticos de ejemplo, sin nodos ni horas inventadas', () async {
      final rutas = await repositorio.misRutas();

      expect(rutas, hasLength(2));
      final paradas = rutas.expand((ruta) => ruta.paradas).toList();
      expect(paradas, isNotEmpty);
      expect(paradas.every((p) => p.nodo == null && p.nodoId == null), isTrue);
      expect(
        paradas.every(
          (p) => p.puntoCritico?.codigo.startsWith('EJEMPLO-') ?? false,
        ),
        isTrue,
      );
      expect(paradas.every((p) => p.tieneUbicacion), isTrue);
      expect(rutas.first.esDelDia(DateTime.now()), isTrue);
    });

    test('persiste en memoria los cambios de estado y recolección', () async {
      await repositorio.cambiarEstado(101, EstadoRutaConductor.enProceso);
      final parada = (await repositorio.detalle(101)).paradas.first;
      await repositorio.marcarParada(101, parada.id, true);

      final rutaActualizada = await repositorio.detalle(101);
      expect(rutaActualizada.estado, EstadoRutaConductor.enProceso);
      expect(rutaActualizada.paradas.first.recolectado, isTrue);
      expect(rutaActualizada.paradasHechas, 1);

      await repositorio.marcarParada(101, parada.id, false);
      expect(
        (await repositorio.detalle(101)).paradas.first.recolectado,
        isFalse,
      );
    });
  });

  test('el provider selecciona mock o API según AppConfig', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final repositorio = container.read(repositorioConductorProvider);
    if (AppConfig.usarDatosDeEjemplo) {
      expect(repositorio, isA<RepositorioConductorMock>());
    } else {
      expect(repositorio, isA<RepositorioConductorApi>());
    }
  });

  group('modelo de rutas nuevas (punto crítico, nodo null)', () {
    test('parada con punto_critico y nodo_id/nodo en null', () {
      final parada = ParadaConductor.fromJson(_paradaJson(
        id: 10,
        orden: 1,
        codigo: '130101-4',
        llenado: 'desbordado',
      ));

      expect(parada.nodoId, isNull);
      expect(parada.nodo, isNull);
      expect(parada.puntoCriticoId, 404);
      expect(parada.codigo, '130101-4');
      expect(parada.direccion, 'Dirección 130101-4');
      expect(parada.puntoCritico?.referencia, 'Frente al mercado');
      expect(parada.puntoCritico?.priorizacionObligatoria, isTrue);
      expect(parada.estadoLlenado, NivelLlenado.desbordado);
      expect(parada.latitud, -8.11);
      expect(parada.longitud, -79.02);
    });

    test('estado_llenado sin_datos o ausente es "Sin datos"', () {
      final sinDatos = ParadaConductor.fromJson(_paradaJson(llenado: 'sin_datos'));
      expect(sinDatos.estadoLlenado, NivelLlenado.sinDatos);

      final json = _paradaJson()
        ..['punto_critico'] = (Map<String, dynamic>.from(
          _paradaJson()['punto_critico'] as Map,
        )..remove('estado_llenado'));
      expect(ParadaConductor.fromJson(json).estadoLlenado, NivelLlenado.sinDatos);
    });

    test('ruta antigua: parada solo con nodo sigue leyéndose', () {
      final parada = ParadaConductor.fromJson({
        'id': 10,
        'ruta_id': 1,
        'nodo_id': 2,
        'punto_critico_id': null,
        'orden': 1,
        'recolectado': false,
        'nodo': {
          'id': 2,
          'codigo': 'N-2',
          'nombre': 'Contenedor 2',
          'latitud': -8.1099,
          'longitud': -79.0310,
          'umbral_critico': 80,
        },
        'punto_critico': null,
      });
      expect(parada.codigo, 'N-2');
      expect(parada.tieneUbicacion, isTrue);
      expect(parada.estadoLlenado, NivelLlenado.sinDatos);
    });

    test('RutaOut: paradas ordenadas por orden y camión con campos nulos', () {
      final ruta = RutaConductor.fromJson(_rutaJson(fecha: '2026-11-17'));

      expect(ruta.paradas.map((p) => p.orden), [1, 2, 3]);
      expect(ruta.paradas.map((p) => p.codigo), [
        '130101-1',
        '130101-2',
        '130101-3',
      ]);
      expect(ruta.turno, 'manana');
      expect(ruta.turnoTexto, 'Mañana');
      expect(ruta.distanciaKm, 12.5);
      expect(ruta.tiempoEstimadoMin, 95);
      expect(ruta.metodoDistancia, metodoDistanciaAproximada);
      expect(ruta.camion?.capacidad, isNull);
      expect(ruta.camion?.turno, isNull);
    });

    test('rutaDeHoy solo toma rutas de ese día', () {
      final rutas = [RutaConductor.fromJson(_rutaJson(fecha: '2026-11-16'))];
      expect(rutaDeHoy(rutas, DateTime(2026, 11, 17, 8)), isNull);
      expect(rutaDeHoy(rutas, DateTime(2026, 11, 16, 8))?.id, 77);
    });
  });

  group('mensajes de carga del conductor', () {
    test('distingue sesión vencida, permisos, red y formato inesperado', () {
      final opciones = RequestOptions(path: '/rutas/mias');

      expect(
        mensajeErrorCargaConductor(
          DioException(
            requestOptions: opciones,
            response: Response(requestOptions: opciones, statusCode: 401),
          ),
        ),
        'Tu sesión venció. Inicia sesión nuevamente.',
      );
      expect(
        mensajeErrorCargaConductor(
          DioException(
            requestOptions: opciones,
            response: Response(requestOptions: opciones, statusCode: 403),
          ),
        ),
        'No tienes permiso para consultar estas rutas.',
      );
      expect(
        mensajeErrorCargaConductor(
          DioException(
            requestOptions: opciones,
            type: DioExceptionType.connectionError,
          ),
        ),
        'No se pudo conectar. Revisa tu conexión e inténtalo de nuevo.',
      );
      expect(
        mensajeErrorCargaConductor(FormatException('fecha inválida')),
        'El servidor devolvió datos inesperados. '
        'Inténtalo de nuevo más tarde.',
      );
    });
  });

  testWidgets('Mi ruta permite reintentar una carga fallida', (tester) async {
    await _mostrarPantalla(
      tester,
      const PantallaMiRuta(),
      _RepositorioFallaPrimeraCarga(),
      incluirSesion: true,
    );

    expect(
      find.text(
        'No se pudo conectar. Revisa tu conexión e inténtalo de nuevo.',
      ),
      findsOneWidget,
    );
    await tester.tap(find.text('Reintentar'));
    await tester.pumpAndSettle();

    expect(find.text('Mi ruta de hoy'), findsOneWidget);
  });

  testWidgets('Mapa de ruta permite reintentar una carga fallida', (
    tester,
  ) async {
    await _mostrarPantalla(
      tester,
      const PantallaMapaConductor(),
      _RepositorioFallaPrimeraCarga(),
    );

    expect(
      find.text(
        'No se pudo conectar. Revisa tu conexión e inténtalo de nuevo.',
      ),
      findsOneWidget,
    );
    await tester.tap(find.text('Reintentar'));
    await tester.pumpAndSettle();

    expect(find.text('Cómo llegar'), findsOneWidget);
  });

  testWidgets('el mapa anuncia y permite seleccionar marcadores accesibles', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await _mostrarPantalla(
      tester,
      const PantallaMapaConductor(),
      RepositorioConductorMock(),
    );

    expect(
      find.bySemanticsLabel(RegExp(r'^Parada 2: EJEMPLO-01 · Dirección de ejemplo 1, Trujillo')),
      findsOneWidget,
    );
    final marcador = tester.getSemantics(
      find.bySemanticsLabel(RegExp(r'^Parada 2: EJEMPLO-01 · Dirección de ejemplo 1, Trujillo')),
    );
    expect(marcador.rect.width, greaterThanOrEqualTo(48));
    expect(marcador.rect.height, greaterThanOrEqualTo(48));

    await tester.tap(
      find.bySemanticsLabel(RegExp(r'^Parada 2: EJEMPLO-01 · Dirección de ejemplo 1, Trujillo')),
    );
    await tester.pump();
    expect(
      find.text('Parada 2: EJEMPLO-01 · Dirección de ejemplo 1, Trujillo'),
      findsOneWidget,
    );
    expect(
      tester.getSize(find.widgetWithText(FilledButton, 'Cómo llegar')).height,
      greaterThanOrEqualTo(48),
    );
    semantics.dispose();
  });

  testWidgets('cancelar ruta requiere confirmación y cambia el estado', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(900, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await _mostrarPantalla(
      tester,
      const PantallaDetalleRuta(idRuta: 101),
      RepositorioConductorMock(),
    );

    await tester.tap(find.widgetWithText(OutlinedButton, 'Cancelar ruta'));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsOneWidget);

    await tester.tap(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.byType(FilledButton),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Cancelado'), findsOneWidget);
  });

  group('Mi ruta', () {
    final hoy = DateTime(2026, 11, 17, 8);

    for (final (caso, rutas) in [
      ('sin rutas', <RutaConductor>[]),
      (
        'solo una ruta de ayer',
        [RutaConductor.fromJson(_rutaJson(fecha: '2026-11-16'))],
      ),
    ]) {
      testWidgets('sin ruta asignada para hoy lo indica ($caso)', (
        tester,
      ) async {
        await _mostrarPantalla(
          tester,
          const PantallaMiRuta(),
          _RepositorioFijo(rutas),
          incluirSesion: true,
          hoy: hoy,
        );
        expect(
          find.text('Aún no tienes una ruta asignada para hoy'),
          findsOneWidget,
        );
        expect(find.byType(TarjetaParadaConductor), findsNothing);
      });
    }

    testWidgets('paradas en orden con código, dirección, referencia y llenado', (
      tester,
    ) async {
      await _mostrarPantalla(
        tester,
        const PantallaMiRuta(),
        _RepositorioFijo([RutaConductor.fromJson(_rutaJson(fecha: '2026-11-17'))]),
        incluirSesion: true,
        hoy: hoy,
      );

      final tarjetas = find.byType(TarjetaParadaConductor);
      expect(tarjetas, findsNWidgets(3));
      final codigos = [
        for (final codigo in ['130101-1', '130101-2', '130101-3'])
          tester.getTopLeft(find.text(codigo)).dy,
      ];
      expect(codigos, orderedEquals([...codigos]..sort()),
          reason: 'se muestran por orden, no como llegan');

      Finder enParada(int id, Finder buscado) =>
          find.descendant(of: find.byKey(ValueKey('parada-$id')), matching: buscado);
      expect(enParada(1, find.text('Dirección 130101-1')), findsOneWidget);
      expect(enParada(1, find.text('Referencia: Frente al mercado')), findsOneWidget);
      expect(enParada(1, find.text('Lleno')), findsOneWidget);
      expect(enParada(2, find.text('Sin datos')), findsOneWidget);
      expect(enParada(2, find.text('Lleno')), findsNothing);
      expect(enParada(3, find.text('Desbordado')), findsOneWidget);
      expect(enParada(1, find.text('Prioritario')), findsOneWidget);
      // Cada parada tiene navegación externa y reporte de llenado.
      expect(find.widgetWithText(OutlinedButton, 'Cómo llegar'), findsNWidgets(3));
      expect(find.widgetWithText(OutlinedButton, 'Reportar llenado'),
          findsNWidgets(3));
    });

    testWidgets('iniciar, marcar parada recolectada y finalizar', (
      tester,
    ) async {
      final repositorio = RepositorioConductorMock(hoy: hoy);
      await _mostrarPantalla(
        tester,
        const PantallaMiRuta(),
        repositorio,
        incluirSesion: true,
        hoy: hoy,
      );

      // Pendiente: aún no se marcan paradas.
      expect(find.text('Marcar recolectada'), findsNothing);
      await tester.tap(find.widgetWithText(FilledButton, 'Iniciar ruta'));
      await tester.pumpAndSettle();

      expect(find.text('Marcar recolectada'), findsNWidgets(4));
      await tester.tap(find.text('Marcar recolectada').first);
      await tester.pumpAndSettle();
      expect(find.text('Recolectada'), findsOneWidget);
      expect(find.text('1/4 paradas recolectadas'), findsOneWidget);
      expect((await repositorio.detalle(101)).paradas.first.recolectado, isTrue);

      await tester.tap(find.widgetWithText(FilledButton, 'Finalizar ruta'));
      await tester.pumpAndSettle();
      expect(
        (await repositorio.detalle(101)).estado,
        EstadoRutaConductor.completado,
      );
    });

    testWidgets('"Reportar llenado" en una parada abre la hoja del punto', (
      tester,
    ) async {
      await _mostrarPantalla(
        tester,
        const PantallaMiRuta(),
        _RepositorioFijo([RutaConductor.fromJson(_rutaJson(fecha: '2026-11-17'))]),
        incluirSesion: true,
        hoy: hoy,
      );

      await tester.tap(
        find.descendant(
          of: find.byKey(const ValueKey('parada-2')),
          matching: find.widgetWithText(OutlinedButton, 'Reportar llenado'),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(HojaReportarLlenado), findsOneWidget);
      expect(find.text('Punto crítico 130101-2'), findsOneWidget);
    });
  });

  testWidgets('muestra el aviso discreto cuando usa datos de ejemplo', (
    tester,
  ) async {
    if (!AppConfig.usarDatosDeEjemplo) return;
    await _mostrarPantalla(
      tester,
      const PantallaInicioConductor(),
      RepositorioConductorMock(),
      incluirSesion: true,
    );

    expect(find.text('Datos de ejemplo'), findsOneWidget);
  });
}

Future<void> _mostrarPantalla(
  WidgetTester tester,
  Widget pantalla,
  RepositorioConductor repositorio, {
  bool incluirSesion = false,
  DateTime? hoy,
}) async {
  if (hoy != null) {
    tester.view.physicalSize = const Size(900, 3000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
  }
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        repositorioConductorProvider.overrideWithValue(repositorio),
        if (incluirSesion) authProvider.overrideWith(_AuthControllerFalso.new),
        if (hoy != null) relojConductorProvider.overrideWithValue(() => hoy),
      ],
      child: MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(body: pantalla),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

class _RepositorioFallaPrimeraCarga implements RepositorioConductor {
  @override
  Future<ResultadoGenerarMiRuta> generarMiRuta() =>
      throw UnimplementedError();

  final RepositorioConductorMock _repositorio = RepositorioConductorMock();
  bool _fallar = true;

  @override
  Future<List<RutaConductor>> misRutas() async {
    if (_fallar) {
      _fallar = false;
      throw DioException(
        requestOptions: RequestOptions(path: '/rutas/mias'),
        type: DioExceptionType.connectionError,
      );
    }
    return _repositorio.misRutas();
  }

  @override
  Future<RutaConductor> detalle(int id) => _repositorio.detalle(id);

  @override
  Future<RutaConductor> cambiarEstado(int id, EstadoRutaConductor estado) =>
      _repositorio.cambiarEstado(id, estado);

  @override
  Future<ParadaConductor> marcarParada(
    int rutaId,
    int paradaId,
    bool recolectado,
  ) => _repositorio.marcarParada(rutaId, paradaId, recolectado);
}

class _AuthControllerFalso extends AuthController {
  @override
  AuthState build() => const AuthState(
    status: AuthStatus.loggedIn,
    user: Usuario(
      email: 'conductor@ecoruta.test',
      nombre: 'Conductor Demo',
      rol: 'conductor',
    ),
  );
}

/// Parada con la forma de `ParadaOut` de las rutas nuevas (datos de prueba).
Map<String, dynamic> _paradaJson({
  int id = 1,
  int orden = 1,
  String codigo = '130101-1',
  String llenado = 'lleno',
  bool prioritario = true,
}) => {
  'id': id,
  'ruta_id': 77,
  'orden': orden,
  'recolectado': false,
  'nodo_id': null,
  'nodo': null,
  'punto_critico_id': 400 + int.parse(codigo.split('-').last),
  'punto_critico': {
    'id': 400 + int.parse(codigo.split('-').last),
    'codigo': codigo,
    'direccion': 'Dirección $codigo',
    'referencia': 'Frente al mercado',
    'lat': -8.11,
    'lon': -79.02,
    'priorizacion_obligatoria': prioritario,
    'estado_llenado': llenado,
  },
};

/// `RutaOut` con las paradas desordenadas a propósito.
Map<String, dynamic> _rutaJson({required String fecha}) => {
  'id': 77,
  'fecha_inicio': fecha,
  'fecha_fin': fecha,
  'hora_inicio': '${fecha}T05:00:00',
  'hora_fin': '${fecha}T09:00:00',
  'camion_id': 3,
  'conductor_id': 9,
  'estado': 'Pendiente',
  'turno': 'manana',
  'distancia_km': 12.5,
  'tiempo_estimado_min': 95,
  'metodo_distancia': 'haversine_aprox',
  'camion': {
    'id': 3,
    'placa': 'T1A-333',
    'capacidad': null,
    'turno': null,
    'estado': 'operativo',
  },
  'paradas': [
    _paradaJson(id: 3, orden: 3, codigo: '130101-3', llenado: 'desbordado',
        prioritario: false),
    _paradaJson(id: 1, orden: 1, codigo: '130101-1', llenado: 'lleno'),
    _paradaJson(id: 2, orden: 2, codigo: '130101-2', llenado: 'sin_datos',
        prioritario: false),
  ],
};

/// Devuelve siempre las mismas rutas.
class _RepositorioFijo implements RepositorioConductor {
  @override
  Future<ResultadoGenerarMiRuta> generarMiRuta() =>
      throw UnimplementedError();

  _RepositorioFijo(this.rutas);

  final List<RutaConductor> rutas;

  @override
  Future<List<RutaConductor>> misRutas() async => rutas;

  @override
  Future<RutaConductor> detalle(int id) async =>
      rutas.firstWhere((ruta) => ruta.id == id);

  @override
  Future<RutaConductor> cambiarEstado(int id, EstadoRutaConductor estado) async =>
      (await detalle(id)).copiar(estado: estado);

  @override
  Future<ParadaConductor> marcarParada(
    int rutaId,
    int paradaId,
    bool recolectado,
  ) async => (await detalle(
    rutaId,
  )).paradas.firstWhere((p) => p.id == paradaId).copiar(recolectado: recolectado);
}
