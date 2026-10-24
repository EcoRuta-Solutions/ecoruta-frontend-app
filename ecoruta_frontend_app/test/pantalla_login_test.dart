import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:ecoruta_frontend_app/core/network/api_client.dart';
import 'package:ecoruta_frontend_app/core/router/app_router.dart';
import 'package:ecoruta_frontend_app/core/storage/token_storage.dart';
import 'package:ecoruta_frontend_app/core/theme/app_theme.dart';
import 'package:ecoruta_frontend_app/features/auth/presentation/auth_controller.dart';
import 'package:ecoruta_frontend_app/features/auth/presentation/logo_ecoruta.dart';
import 'package:ecoruta_frontend_app/features/auth/presentation/pantalla_login.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Guarda el token en memoria en lugar del almacenamiento seguro.
class _TokenEnMemoria extends TokenStorage {
  String? token;
  _TokenEnMemoria([this.token]);

  @override
  Future<String?> read() async => token;

  @override
  Future<void> write(String token) async => this.token = token;

  @override
  Future<void> clear() async => token = null;
}

/// Backend simulado: responde /auth/login y /auth/me sin red.
class _BackendFalso implements HttpClientAdapter {
  /// Rol que devuelve GET /auth/me.
  String rol;

  /// Código de error de POST /auth/login (null = login correcto).
  int? errorLogin;

  /// Simula que el servidor está apagado.
  bool sinConexion = false;

  /// Si existe, POST /auth/login espera a que se complete.
  Completer<void>? esperaLogin;

  final rutasPedidas = <String>[];

  _BackendFalso({this.rol = 'municipalidad'});

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    rutasPedidas.add(options.path);
    if (sinConexion) {
      throw DioException.connectionError(
        requestOptions: options,
        reason: 'sin conexión',
      );
    }
    if (options.path == '/auth/login') {
      await esperaLogin?.future;
      if (errorLogin != null) return _json({'detail': 'error'}, errorLogin!);
      return _json({'access_token': 'token-de-prueba'}, 200);
    }
    if (options.path == '/auth/me') {
      return _json({
        'id': 1,
        'email': 'prueba@ecoruta.pe',
        'nombre': 'Prueba',
        'rol': rol,
      }, 200);
    }
    return _json({'detail': 'no encontrado'}, 404);
  }

  ResponseBody _json(Object cuerpo, int codigo) => ResponseBody.fromString(
    jsonEncode(cuerpo),
    codigo,
    headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType],
    },
  );

  @override
  void close({bool force = false}) {}
}

class _Entorno {
  final ProviderContainer container;
  final _BackendFalso backend;
  final _TokenEnMemoria token;

  _Entorno(this.container, this.backend, this.token);

  String get ruta => container
      .read(routerProvider)
      .routerDelegate
      .currentConfiguration
      .uri
      .path;
}

Future<_Entorno> _abrirApp(
  WidgetTester tester, {
  String rol = 'municipalidad',
  String? tokenGuardado,
}) async {
  final backend = _BackendFalso(rol: rol);
  final token = _TokenEnMemoria(tokenGuardado);
  final container = ProviderContainer(
    overrides: [
      tokenStorageProvider.overrideWithValue(token),
      dioProvider.overrideWith((ref) {
        final dio = Dio(BaseOptions(baseUrl: 'http://backend.test'));
        dio.httpClientAdapter = backend;
        return dio;
      }),
    ],
  );
  addTearDown(container.dispose);

  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: Consumer(
        builder: (_, ref, _) => MaterialApp.router(
          theme: AppTheme.light,
          routerConfig: ref.watch(routerProvider),
        ),
      ),
    ),
  );
  await _esperarBackend(tester);
  return _Entorno(container, backend, token);
}

Future<void> _escribirCredenciales(
  WidgetTester tester, {
  String correo = 'prueba@ecoruta.pe',
  String clave = 'secreta',
}) async {
  await tester.enterText(find.byKey(const Key('login-correo')), correo);
  await tester.enterText(find.byKey(const Key('login-clave')), clave);
}

Future<void> _ingresar(WidgetTester tester) async {
  await tester.tap(find.widgetWithText(FilledButton, 'Ingresar'));
  await _esperarBackend(tester);
}

/// Deja correr las peticiones al backend simulado (Dio usa timers internos).
Future<void> _esperarBackend(WidgetTester tester) async {
  for (var i = 0; i < 4; i++) {
    await tester.pump(const Duration(milliseconds: 1));
  }
}

/// Deja terminar la carga simulada de la pantalla del rol (datos de ejemplo).
Future<void> _dejarCargarInicio(WidgetTester tester) =>
    tester.pump(const Duration(seconds: 1));

Finder _campo(String key) =>
    find.descendant(of: find.byKey(Key(key)), matching: find.byType(TextField));

Color _colorBorde(WidgetTester tester, String key) {
  final campo = tester.widget<TextField>(_campo(key));
  final borde = campo.decoration!.enabledBorder! as OutlineInputBorder;
  return borde.borderSide.color;
}

const _rojo = Color(0xFFB3261E);

LogoEcoRuta _logo(WidgetTester tester) =>
    tester.widget<LogoEcoRuta>(find.byType(LogoEcoRuta));

/// El camión está quieto en su sitio: sin salir, sin temblor ni inclinación.
void _esperarCamionEnReposo(WidgetTester tester) {
  final logo = _logo(tester);
  expect(logo.salidaCamion, 0);
  expect(logo.desplazamientoCamion.dx, closeTo(0, 1e-9));
  expect(logo.desplazamientoCamion.dy, closeTo(0, 1e-9));
  expect(logo.inclinacionCamion, closeTo(0, 1e-9));
}

/// A mitad del temblor: ruedas girando y oscilación lateral de pocos píxeles,
/// pero el camión no avanza.
Future<void> _esperarTemblor(WidgetTester tester) async {
  await tester.pump(const Duration(milliseconds: 150));
  final antes = _logo(tester);
  expect(antes.salidaCamion, 0);
  expect(antes.desplazamientoCamion.dx.abs(), inInclusiveRange(1, 4));
  expect(antes.inclinacionCamion, isNot(0));

  await tester.pump(const Duration(milliseconds: 50));
  expect(_logo(tester).giroRuedas, isNot(antes.giroRuedas));

  // Pasados unos 0,6 s se detiene en su lugar.
  await tester.pump(duracionTemblorError);
  _esperarCamionEnReposo(tester);
  final giroFinal = _logo(tester).giroRuedas;
  await tester.pump(const Duration(milliseconds: 100));
  expect(_logo(tester).giroRuedas, giroFinal);
}

void main() {
  testWidgets('estado normal: campos vacíos, botón Ingresar y sin pie demo', (
    tester,
  ) async {
    final app = await _abrirApp(tester);

    expect(app.ruta, '/login');
    expect(find.text('Correo'), findsOneWidget);
    expect(find.text('Contraseña'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Ingresar'), findsOneWidget);
    expect(find.byType(LogoEcoRuta), findsOneWidget);
    expect(find.textContaining('Demo'), findsNothing);
    expect(find.textContaining('SEGAT'), findsNothing);
    expect(find.byIcon(Icons.mail_outline), findsNothing);
    expect(find.byIcon(Icons.lock_outline), findsNothing);
    expect(find.byIcon(Icons.visibility_outlined), findsOneWidget);
    expect(_colorBorde(tester, 'login-correo'), isNot(_rojo));

    final correo = tester.widget<TextField>(_campo('login-correo'));
    expect(correo.keyboardType, TextInputType.emailAddress);
  });

  testWidgets('faltan datos: muestra el error y no llama al backend', (
    tester,
  ) async {
    final app = await _abrirApp(tester);

    await _escribirCredenciales(tester, correo: 'sin-arroba', clave: '');
    await _ingresar(tester);

    expect(find.text(mensajeRevisaDatos), findsOneWidget);
    expect(_colorBorde(tester, 'login-correo'), _rojo);
    expect(_colorBorde(tester, 'login-clave'), _rojo);
    expect(app.backend.rutasPedidas, isEmpty);
  });

  testWidgets(
    'credenciales incorrectas (401): "Revisa tu usuario y contraseña"',
    (tester) async {
      final app = await _abrirApp(tester);
      app.backend.errorLogin = 401;

      await _escribirCredenciales(tester);
      await _ingresar(tester);

      expect(find.text(mensajeRevisaDatos), findsOneWidget);
      expect(_colorBorde(tester, 'login-correo'), _rojo);
      expect(_colorBorde(tester, 'login-clave'), _rojo);
      expect(app.ruta, '/login');
      expect(app.container.read(celebrandoLoginProvider), isFalse);
    },
  );

  testWidgets('rol no permitido: "Tu cuenta no tiene acceso a esta app"', (
    tester,
  ) async {
    final app = await _abrirApp(tester, rol: 'ciudadano');

    await _escribirCredenciales(tester);
    await _ingresar(tester);

    expect(find.text(mensajeSinAcceso), findsOneWidget);
    expect(_colorBorde(tester, 'login-clave'), _rojo);
    expect(app.token.token, isNull);
    expect(app.ruta, '/login');
  });

  testWidgets('sin conexión: conserva el mensaje y no marca los campos', (
    tester,
  ) async {
    final app = await _abrirApp(tester);
    app.backend.sinConexion = true;

    await _escribirCredenciales(tester);
    await _ingresar(tester);

    expect(
      find.text(
        'No se pudo conectar con el servidor. ¿Está encendido el backend?',
      ),
      findsOneWidget,
    );
    expect(_colorBorde(tester, 'login-correo'), isNot(_rojo));
  });

  testWidgets('cargando: el botón se deshabilita y dice "Verificando…"', (
    tester,
  ) async {
    final app = await _abrirApp(tester);
    app.backend.esperaLogin = Completer<void>();

    await _escribirCredenciales(tester);
    await _ingresar(tester);

    final boton = tester.widget<FilledButton>(find.byType(FilledButton));
    expect(find.text('Verificando…'), findsOneWidget);
    expect(boton.onPressed, isNull);

    app.backend.esperaLogin!.complete();
    await tester.pumpAndSettle();
  });

  for (final (rol, nombre, ruta) in [
    ('municipalidad', 'Municipalidad', '/municipalidad'),
    ('conductor', 'Conductor', '/conductor'),
  ]) {
    testWidgets('éxito como $nombre: anima y luego navega a $ruta', (
      tester,
    ) async {
      final app = await _abrirApp(tester, rol: rol);

      await _escribirCredenciales(tester);
      await _ingresar(tester);

      // Se queda en /login mientras se muestra el éxito.
      expect(app.ruta, '/login');
      expect(find.text('Sesión iniciada'), findsOneWidget);
      expect(find.text('Entrando como $nombre'), findsOneWidget);
      expect(find.text('Repetir animación'), findsNothing);
      expect(app.backend.rutasPedidas, ['/auth/login', '/auth/me']);

      // A mitad de la animación el camión ya va saliendo.
      await tester.pump(duracionExitoLogin ~/ 2);
      final logo = tester.widget<LogoEcoRuta>(find.byType(LogoEcoRuta));
      expect(logo.salidaCamion, inExclusiveRange(0, 1));
      expect(app.ruta, '/login');

      await tester.pump(duracionExitoLogin);
      await tester.pump();
      expect(app.container.read(celebrandoLoginProvider), isFalse);
      expect(app.ruta, ruta);
      await _dejarCargarInicio(tester);
    });
  }

  testWidgets('reducir animaciones: sin movimiento y navega tras una pausa', (
    tester,
  ) async {
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    final app = await _abrirApp(tester, rol: 'conductor');

    await _escribirCredenciales(tester);
    await _ingresar(tester);

    expect(find.text('Entrando como Conductor'), findsOneWidget);
    // El camión ya está fuera, sin animación intermedia.
    final logo = tester.widget<LogoEcoRuta>(find.byType(LogoEcoRuta));
    expect(logo.salidaCamion, 1);
    expect(app.ruta, '/login');

    await tester.pump(pausaExitoSinAnimacion);
    await tester.pump();
    expect(app.ruta, '/conductor');
    await _dejarCargarInicio(tester);
  });

  for (final (rol, ruta) in [
    ('municipalidad', '/municipalidad'),
    ('conductor', '/conductor'),
  ]) {
    testWidgets('sesión guardada ($rol): navega de inmediato, sin animación', (
      tester,
    ) async {
      final app = await _abrirApp(
        tester,
        rol: rol,
        tokenGuardado: 'token-guardado',
      );

      expect(app.ruta, ruta);
      expect(app.container.read(celebrandoLoginProvider), isFalse);
      expect(find.byType(PantallaLogin), findsNothing);
      expect(find.text('Sesión iniciada'), findsNothing);
      expect(app.backend.rutasPedidas, ['/auth/me']);
      await _dejarCargarInicio(tester);
    });
  }

  group('animaciones del camión', () {
    testWidgets(
      'verificando: las ruedas giran y vibra sin moverse de su sitio',
      (tester) async {
        final app = await _abrirApp(tester);
        app.backend
          ..esperaLogin = Completer<void>()
          ..errorLogin = 401;

        await _escribirCredenciales(tester);
        await _ingresar(tester);
        expect(find.text('Verificando…'), findsOneWidget);

        // Gira continuamente durante toda la verificación.
        final giros = <double>[];
        for (var i = 0; i < 6; i++) {
          await tester.pump(const Duration(milliseconds: 230));
          final logo = _logo(tester);
          giros.add(logo.giroRuedas);
          expect(logo.salidaCamion, 0);
          expect(logo.desplazamientoCamion.dx, 0);
          expect(logo.desplazamientoCamion.dy.abs(), lessThanOrEqualTo(1));
          expect(logo.inclinacionCamion, 0);
        }
        expect(giros.toSet(), hasLength(giros.length));

        app.backend.esperaLogin!.complete();
        await _esperarBackend(tester);
        await tester.pumpAndSettle();
        expect(find.text(mensajeRevisaDatos), findsOneWidget);
        _esperarCamionEnReposo(tester);
      },
    );

    testWidgets('credenciales incorrectas: tiembla 0,6 s y se detiene', (
      tester,
    ) async {
      final app = await _abrirApp(tester);
      app.backend.errorLogin = 401;

      await _escribirCredenciales(tester);
      await _ingresar(tester);

      expect(find.text(mensajeRevisaDatos), findsOneWidget);
      await _esperarTemblor(tester);

      // Con el error ya en pantalla, otro intento vuelve a hacerlo temblar.
      await _ingresar(tester);
      expect(find.text(mensajeRevisaDatos), findsOneWidget);
      await _esperarTemblor(tester);
      expect(
        app.backend.rutasPedidas.where((r) => r == '/auth/login'),
        hasLength(2),
      );
    });

    testWidgets('campos vacíos: error y temblor en cada intento, sin backend', (
      tester,
    ) async {
      final app = await _abrirApp(tester);

      await _ingresar(tester);
      expect(find.text(mensajeRevisaDatos), findsOneWidget);
      expect(_colorBorde(tester, 'login-correo'), _rojo);
      expect(_colorBorde(tester, 'login-clave'), _rojo);
      await _esperarTemblor(tester);

      await _ingresar(tester);
      await _esperarTemblor(tester);
      expect(app.backend.rutasPedidas, isEmpty);
    });

    testWidgets('rol no permitido: también tiembla', (tester) async {
      await _abrirApp(tester, rol: 'ciudadano');

      await _escribirCredenciales(tester);
      await _ingresar(tester);

      expect(find.text(mensajeSinAcceso), findsOneWidget);
      await _esperarTemblor(tester);
    });

    testWidgets('reducir animaciones: sin giro ni temblor, solo el error', (
      tester,
    ) async {
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(disableAnimations: true);
      addTearDown(
        tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
      );
      final app = await _abrirApp(tester);

      // Verificando: las ruedas no giran.
      app.backend
        ..esperaLogin = Completer<void>()
        ..errorLogin = 401;
      await _escribirCredenciales(tester);
      await _ingresar(tester);
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Verificando…'), findsOneWidget);
      expect(_logo(tester).giroRuedas, 0);
      _esperarCamionEnReposo(tester);

      // Error: borde rojo y texto, sin temblor.
      app.backend.esperaLogin!.complete();
      await _esperarBackend(tester);
      for (var i = 0; i < 4; i++) {
        await tester.pump(const Duration(milliseconds: 100));
        expect(_logo(tester).giroRuedas, 0);
        _esperarCamionEnReposo(tester);
      }
      expect(find.text(mensajeRevisaDatos), findsOneWidget);
      expect(_colorBorde(tester, 'login-clave'), _rojo);

      // Campos vacíos: igual, sin temblor.
      await tester.enterText(find.byKey(const Key('login-correo')), '');
      await tester.enterText(find.byKey(const Key('login-clave')), '');
      await _ingresar(tester);
      await tester.pump(const Duration(milliseconds: 150));
      expect(find.text(mensajeRevisaDatos), findsOneWidget);
      expect(_logo(tester).giroRuedas, 0);
      _esperarCamionEnReposo(tester);
    });
  });
}
