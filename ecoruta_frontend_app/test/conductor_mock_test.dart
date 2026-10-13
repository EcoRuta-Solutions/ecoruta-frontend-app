import 'package:dio/dio.dart';
import 'package:ecoruta_frontend_app/core/config/app_config.dart';
import 'package:ecoruta_frontend_app/core/theme/app_theme.dart';
import 'package:ecoruta_frontend_app/features/auth/data/auth_repository.dart';
import 'package:ecoruta_frontend_app/features/auth/presentation/auth_controller.dart';
import 'package:ecoruta_frontend_app/features/conductor/data/modelos_conductor.dart';
import 'package:ecoruta_frontend_app/features/conductor/data/repositorio_conductor.dart';
import 'package:ecoruta_frontend_app/features/conductor/presentation/error_conductor.dart';
import 'package:ecoruta_frontend_app/features/conductor/presentation/pantalla_detalle_ruta.dart';
import 'package:ecoruta_frontend_app/features/conductor/presentation/pantalla_mapa_conductor.dart';
import 'package:ecoruta_frontend_app/features/conductor/presentation/pantalla_mi_ruta.dart';
import 'package:ecoruta_frontend_app/features/conductor/pantalla_inicio_conductor.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('RepositorioConductorMock', () {
    late RepositorioConductorMock repositorio;

    setUp(() {
      repositorio = RepositorioConductorMock();
    });

    test(
      'expone tres rutas realistas y paradas con datos de ejemplo',
      () async {
        final rutas = await repositorio.misRutas();

        expect(rutas, hasLength(3));
        expect(
          rutas.map((ruta) => ruta.estado),
          containsAll([
            EstadoRutaConductor.pendiente,
            EstadoRutaConductor.enProceso,
            EstadoRutaConductor.completado,
          ]),
        );
        expect(rutas.every((ruta) => ruta.camion?.placa == 'TCA-241'), isTrue);
        expect(
          rutas.every(
            (ruta) => ruta.paradas.length >= 4 && ruta.paradas.length <= 6,
          ),
          isTrue,
        );
        expect(
          rutas
              .expand((ruta) => ruta.paradas)
              .every(
                (parada) =>
                    parada.horaEstimada != null &&
                    parada.nodo?.codigo.startsWith('TRU-') == true,
              ),
          isTrue,
        );
        expect(
          rutas
              .expand((ruta) => ruta.paradas)
              .any((parada) => parada.nodo?.llenado != null),
          isTrue,
        );
        expect(
          rutas
              .expand((ruta) => ruta.paradas)
              .map((parada) => parada.nodo!.codigo)
              .toSet(),
          {
            'TRU-001',
            'TRU-002',
            'TRU-003',
            'TRU-004',
            'TRU-005',
            'TRU-006',
            'TRU-007',
            'TRU-008',
          },
        );
      },
    );

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

    test('añade los reportes enviados a la lista en memoria', () async {
      await repositorio.crearReporte(
        latitud: -8.1116,
        longitud: -79.0288,
        descripcion: 'Contenedor desbordado',
      );

      expect(repositorio.reportes, hasLength(1));
      expect(repositorio.reportes.single.descripcion, 'Contenedor desbordado');
      expect(repositorio.reportes.single.latitud, -8.1116);
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

  test('los campos nuevos de la respuesta son opcionales', () {
    final parada = ParadaConductor.fromJson({
      'id': 10,
      'ruta_id': 1,
      'nodo_id': 2,
      'orden': 1,
      'recolectado': false,
      'nodo': {
        'id': 2,
        'codigo': 'TRU-002',
        'nombre': 'Av. España',
        'latitud': -8.1099,
        'longitud': -79.0310,
        'umbral_critico': 80,
      },
    });

    expect(parada.horaEstimada, isNull);
    expect(parada.nodo?.llenado, isNull);
    expect(parada.nodo?.prioridad, isNull);
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
      find.bySemanticsLabel(RegExp(r'^Parada 2: Urb\. Primavera \(TRU-004\)')),
      findsOneWidget,
    );
    final marcador = tester.getSemantics(
      find.bySemanticsLabel(RegExp(r'^Parada 2: Urb\. Primavera \(TRU-004\)')),
    );
    expect(marcador.rect.width, greaterThanOrEqualTo(48));
    expect(marcador.rect.height, greaterThanOrEqualTo(48));

    await tester.tap(
      find.bySemanticsLabel(RegExp(r'^Parada 2: Urb\. Primavera \(TRU-004\)')),
    );
    await tester.pump();
    expect(find.text('Parada 2: Urb. Primavera (TRU-004)'), findsOneWidget);
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
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        repositorioConductorProvider.overrideWithValue(repositorio),
        if (incluirSesion) authProvider.overrideWith(_AuthControllerFalso.new),
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

  @override
  Future<void> crearReporte({
    required double latitud,
    required double longitud,
    required String descripcion,
  }) => _repositorio.crearReporte(
    latitud: latitud,
    longitud: longitud,
    descripcion: descripcion,
  );
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
