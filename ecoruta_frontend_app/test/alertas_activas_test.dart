import 'package:dio/dio.dart';
import 'package:ecoruta_frontend_app/core/theme/app_theme.dart';
import 'package:ecoruta_frontend_app/features/conductor/data/generar_mi_ruta.dart';
import 'package:ecoruta_frontend_app/features/conductor/data/modelos_conductor.dart';
import 'package:ecoruta_frontend_app/features/conductor/data/repositorio_conductor.dart';
import 'package:ecoruta_frontend_app/features/conductor/presentation/banner_contenedor_lleno.dart';
import 'package:ecoruta_frontend_app/features/conductor/presentation/mis_rutas_controller.dart';
import 'package:ecoruta_frontend_app/features/conductor/presentation/navegacion_conductor_controller.dart';
import 'package:ecoruta_frontend_app/features/municipalidad/data/modelos_alertas_activas.dart';
import 'package:ecoruta_frontend_app/features/municipalidad/data/modelos_puntos_criticos.dart';
import 'package:ecoruta_frontend_app/features/municipalidad/data/modelos_reportes_campo.dart';
import 'package:ecoruta_frontend_app/features/municipalidad/data/repositorio_alertas_activas.dart';
import 'package:ecoruta_frontend_app/features/municipalidad/data/repositorio_puntos_criticos.dart';
import 'package:ecoruta_frontend_app/features/municipalidad/data/repositorio_reportes_campo.dart';
import 'package:ecoruta_frontend_app/features/municipalidad/presentation/alertas_activas_providers.dart';
import 'package:ecoruta_frontend_app/features/municipalidad/presentation/navegacion_controller.dart';
import 'package:ecoruta_frontend_app/features/municipalidad/presentation/pantalla_alertas.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

final _creada = DateTime(2026, 11, 18, 14, 5);

AlertaActiva _alerta({
  int id = 1,
  String codigo = 'PC-PROTO',
  String direccion = 'Av. Prueba 123',
  double? nivel = 92,
}) => AlertaActiva(
  id: id,
  tipo: 'lleno',
  mensaje: '',
  nivelPct: nivel,
  puntoCriticoId: 9,
  puntoCodigo: codigo,
  direccion: direccion,
  creadaEn: _creada,
);

/// Devuelve las alertas que se le indiquen y cuenta las consultas.
class _RepositorioAlertasFalso implements RepositorioAlertasActivas {
  _RepositorioAlertasFalso(this.alertas);

  List<AlertaActiva> alertas;
  int consultas = 0;

  @override
  Future<List<AlertaActiva>> listarActivas() async {
    consultas++;
    return alertas;
  }
}

/// Conductor cuyo POST /rutas/generar-mia responde lo que se configure.
class _RepositorioConductorFalso implements RepositorioConductor {
  _RepositorioConductorFalso({this.error});

  final ErrorGenerarMiRuta? error;
  int generadas = 0;
  int consultasRutas = 0;

  @override
  Future<ResultadoGenerarMiRuta> generarMiRuta() async {
    if (error != null) throw error!;
    generadas++;
    return const ResultadoGenerarMiRuta(
      nroPuntos: 3,
      metodoDistancia: 'osrm',
      rutasReemplazadas: 1,
      rutaId: 77,
    );
  }

  @override
  Future<List<RutaConductor>> misRutas() async {
    consultasRutas++;
    return const [];
  }

  @override
  Future<RutaConductor> detalle(int id) => throw UnimplementedError();

  @override
  Future<RutaConductor> cambiarEstado(int id, EstadoRutaConductor estado) =>
      throw UnimplementedError();

  @override
  Future<ParadaConductor> marcarParada(
    int rutaId,
    int paradaId,
    bool recolectado,
  ) => throw UnimplementedError();
}

DioException _errorHttp(int codigo, {Object? datos}) {
  final pedido = RequestOptions(path: '/rutas/generar-mia');
  return DioException(
    requestOptions: pedido,
    response: Response(requestOptions: pedido, statusCode: codigo, data: datos),
  );
}

void main() {
  group('AlertaActiva.fromJson', () {
    test('lee todos los campos de GET /alertas/activas', () {
      final alerta = AlertaActiva.fromJson({
        'id': 5,
        'tipo': 'lleno',
        'mensaje': 'Contenedor lleno',
        'nivel_pct': 91.6,
        'punto_critico_id': 12,
        'punto_codigo': 'PC-012',
        'direccion': 'Av. España 123',
        'lat': -8.11,
        'lon': -79.03,
        'creada_en': '2026-11-18T19:05:00Z',
      });

      expect(alerta.id, 5);
      expect(alerta.tipo, 'lleno');
      expect(alerta.mensaje, 'Contenedor lleno');
      expect(alerta.nivelPct, 91.6);
      expect(alerta.nivelTexto, '92%');
      expect(alerta.puntoCriticoId, 12);
      expect(alerta.puntoCodigo, 'PC-012');
      expect(alerta.direccion, 'Av. España 123');
      expect(alerta.lat, -8.11);
      expect(alerta.lon, -79.03);
      expect(alerta.creadaEn?.toUtc(), DateTime.utc(2026, 11, 18, 19, 5));
      expect(alerta.creadaEn?.isUtc, isFalse, reason: 'en hora local');
    });

    test('lo que falta queda "por confirmar", sin inventar valores', () {
      final alerta = AlertaActiva.fromJson({
        'id': 1,
        'nivel_pct': null,
        'punto_critico_id': null,
        'lat': null,
        'creada_en': null,
      });

      expect(alerta.nivelPct, isNull);
      expect(alerta.nivelTexto, 'por confirmar');
      expect(alerta.codigoTexto, 'por confirmar');
      expect(alerta.direccionTexto, 'por confirmar');
      expect(alerta.horaTexto, 'por confirmar');
      expect(alerta.lat, isNull);
    });

    test('la lista ignora elementos que no son objetos', () {
      final lista = alertasActivasDesdeJson([
        {'id': 1, 'punto_codigo': 'A'},
        'basura',
        null,
        {'id': 2, 'punto_codigo': 'B'},
      ]);
      expect(lista.map((a) => a.puntoCodigo), ['A', 'B']);
      expect(alertasActivasDesdeJson(null), isEmpty);
    });

    test('el mock incluye una alerta del contenedor prototipo', () async {
      final alertas = await RepositorioAlertasActivasMock().listarActivas();
      expect(alertas, hasLength(1));
      expect(
        alertas.single.puntoCodigo,
        RepositorioPuntosCriticosMock.prototipo.codigo,
      );
      expect(RepositorioPuntosCriticosMock.prototipo.esPrototipo, isTrue);
    });
  });

  group('contratos del sensor', () {
    test('es_prototipo en GET /puntos-criticos', () {
      expect(
        PuntoCritico.fromJson({'codigo': 'P', 'es_prototipo': true})
            .esPrototipo,
        isTrue,
      );
      expect(PuntoCritico.fromJson({'codigo': 'P'}).esPrototipo, isFalse);
    });

    test('reporte del sensor: origen, nivel_pct y usuario en null', () {
      final reporte = ReporteCampo.fromJson({
        'id': 1,
        'punto_critico_id': 9,
        'codigo_punto': 'PC-PROTO',
        'usuario_id': null,
        'usuario_nombre': null,
        'estado': 'lleno',
        'origen': 'sensor',
        'nivel_pct': 88.0,
        'creado_en': '2026-11-18T10:00:00Z',
      });
      expect(reporte.origen, OrigenReporte.sensor);
      expect(reporte.nivelPct, 88.0);
      expect(reporte.usuarioId, isNull);
      expect(reporte.usuarioNombre, isEmpty);

      final breve = UltimoReporteBreve.fromJson({
        'estado': 'lleno',
        'creado_en': '2026-11-18T10:00:00Z',
        'origen': 'campo',
        'nivel_pct': null,
      });
      expect(breve.origen, OrigenReporte.campo);
      expect(breve.nivelPct, isNull);
    });

    test('el mock pinta el prototipo lleno por una lectura del sensor', () {
      final punto = ReportesCampoEjemplo.conLlenado(
        RepositorioPuntosCriticosMock.prototipo,
      );
      expect(punto.estadoLlenado, NivelLlenado.lleno);
      expect(punto.ultimoReporte?.origen, OrigenReporte.sensor);
    });
  });

  group('POST /rutas/generar-mia', () {
    test('lee la respuesta 201', () {
      final resultado = ResultadoGenerarMiRuta.fromJson({
        'nro_puntos': 4,
        'metodo_distancia': 'osrm',
        'rutas_reemplazadas': 1,
        'parametros': <String, dynamic>{},
        'ruta': {'id': 31},
      });
      expect(resultado.nroPuntos, 4);
      expect(resultado.metodoDistancia, 'osrm');
      expect(resultado.rutasReemplazadas, 1);
      expect(resultado.rutaId, 31);
    });

    test('409: ya tiene una ruta en proceso o no tiene camión', () {
      final error = errorGenerarMiRutaDesde(
        _errorHttp(409, datos: {'detail': 'Ya tienes una ruta en proceso'}),
      );
      expect(error.codigo, 409);
      expect(error.mensaje, mensajeYaTieneRuta);
      expect(error.mensaje, contains('ruta en proceso'));
      expect(error.mensaje, contains('camión asignado'));
      expect(error.detalle, 'Ya tienes una ruta en proceso');
    });

    test('422: no hay puntos llenos', () {
      final error = errorGenerarMiRutaDesde(
        _errorHttp(422, datos: {'detail': []}),
      );
      expect(error.codigo, 422);
      expect(error.mensaje, mensajeSinPuntosLlenos);
      expect(error.detalle, isNull, reason: 'una lista no se muestra');
    });

    test('el mock responde 409 si hoy ya hay una ruta en proceso', () async {
      final repositorio = RepositorioConductorMock();
      await repositorio.cambiarEstado(101, EstadoRutaConductor.enProceso);
      expect(
        repositorio.generarMiRuta(),
        throwsA(
          isA<ErrorGenerarMiRuta>().having((e) => e.codigo, 'codigo', 409),
        ),
      );
    });

    test('el mock reemplaza la ruta pendiente de hoy por una nueva', () async {
      final repositorio = RepositorioConductorMock();
      final resultado = await repositorio.generarMiRuta();

      expect(resultado.rutasReemplazadas, 1);
      final rutas = await repositorio.misRutas();
      final hoy = rutaDeHoy(rutas, DateTime.now());
      expect(hoy?.id, resultado.rutaId);
      expect(
        hoy?.paradas.map((p) => p.codigo),
        contains(RepositorioPuntosCriticosMock.prototipo.codigo),
      );
      expect(hoy?.paradasTotal, resultado.nroPuntos);
    });
  });

  group('alertasActivasProvider', () {
    test('sin WebSocket vuelve a consultar cada 5 s', () async {
      final repositorio = _RepositorioAlertasFalso([_alerta()]);
      final contenedor = ProviderContainer(
        overrides: [
          repositorioAlertasActivasProvider.overrideWithValue(repositorio),
          abrirCanalPanelProvider.overrideWithValue(() async => null),
        ],
      );
      addTearDown(contenedor.dispose);
      final escucha = contenedor.listen(alertasActivasProvider, (_, _) {});
      addTearDown(escucha.close);

      expect(
        await contenedor.read(alertasActivasProvider.future),
        hasLength(1),
      );
      repositorio.alertas = [];
      await Future<void>.delayed(
        AlertasActivasController.intervaloSondeo +
            const Duration(milliseconds: 200),
      );
      expect(contenedor.read(alertasActivasProvider).value, isEmpty);
      expect(repositorio.consultas, greaterThanOrEqualTo(2));
    });
  });

  group('banner "Contenedor lleno" del conductor', () {
    Future<(ProviderContainer, _RepositorioConductorFalso)> mostrar(
      WidgetTester tester, {
      required List<AlertaActiva> alertas,
      ErrorGenerarMiRuta? error,
    }) async {
      final conductor = _RepositorioConductorFalso(error: error);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            repositorioAlertasActivasProvider.overrideWithValue(
              _RepositorioAlertasFalso(alertas),
            ),
            abrirCanalPanelProvider.overrideWithValue(() async => null),
            repositorioConductorProvider.overrideWithValue(conductor),
          ],
          child: MaterialApp(
            theme: AppTheme.light,
            home: Scaffold(
              body: Column(
                children: [
                  const BannerContenedorLleno(),
                  Expanded(
                    child: Consumer(
                      builder: (context, ref, _) => Text(
                        'Destino: ${ref.watch(navegacionConductorProvider).destino.name}',
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final contenedor = ProviderScope.containerOf(
        tester.element(find.byType(BannerContenedorLleno)),
      );
      return (contenedor, conductor);
    }

    testWidgets('sin alertas no se muestra', (tester) async {
      await mostrar(tester, alertas: const []);
      expect(find.textContaining('Contenedor lleno'), findsNothing);
      expect(find.text('Generar mi ruta'), findsNothing);
    });

    testWidgets('con alertas muestra el % y la dirección de la más llena', (
      tester,
    ) async {
      await mostrar(
        tester,
        alertas: [
          _alerta(id: 1, direccion: 'Calle Uno', nivel: 81),
          _alerta(id: 2, direccion: 'Calle Dos', nivel: 95),
        ],
      );
      expect(find.text('Contenedor lleno · 95%'), findsOneWidget);
      expect(find.text('Calle Dos'), findsOneWidget);
      expect(find.text('y 1 contenedor lleno más'), findsOneWidget);
      expect(find.text('Generar mi ruta'), findsOneWidget);
    });

    testWidgets('genera la ruta, recarga "Mi ruta" sin caché y la abre', (
      tester,
    ) async {
      final (contenedor, conductor) = await mostrar(
        tester,
        alertas: [_alerta()],
      );
      contenedor
          .read(navegacionConductorProvider.notifier)
          .seleccionar(DestinoConductor.mapa);
      contenedor.listen(misRutasControllerProvider, (_, _) {});
      await contenedor.read(misRutasControllerProvider.future);
      final consultasAntes = conductor.consultasRutas;
      await tester.pump();

      await tester.tap(find.text('Generar mi ruta'));
      await tester.pumpAndSettle();

      expect(conductor.generadas, 1);
      expect(find.text('Destino: miRuta'), findsOneWidget);
      expect(find.text('Ruta generada con 3 puntos.'), findsOneWidget);
      await contenedor.read(misRutasControllerProvider.future);
      expect(conductor.consultasRutas, greaterThan(consultasAntes));
    });

    testWidgets('muestra el mensaje del 409', (tester) async {
      await mostrar(
        tester,
        alertas: [_alerta()],
        error: const ErrorGenerarMiRuta(mensajeYaTieneRuta, codigo: 409),
      );
      await tester.tap(find.text('Generar mi ruta'));
      await tester.pumpAndSettle();

      expect(find.text(mensajeYaTieneRuta), findsOneWidget);
      expect(
        find.text('Destino: miRuta'),
        findsOneWidget,
        reason: 'no cambia de pantalla (ya estaba en Mi ruta)',
      );
      expect(find.text('Generar mi ruta'), findsOneWidget);
    });

    testWidgets('muestra el mensaje del 422', (tester) async {
      await mostrar(
        tester,
        alertas: [_alerta()],
        error: const ErrorGenerarMiRuta(mensajeSinPuntosLlenos, codigo: 422),
      );
      await tester.tap(find.text('Generar mi ruta'));
      await tester.pumpAndSettle();

      expect(find.text(mensajeSinPuntosLlenos), findsOneWidget);
    });
  });

  group('pantalla Alertas de la municipalidad', () {
    Future<ProviderContainer> mostrar(
      WidgetTester tester,
      List<AlertaActiva> alertas,
    ) async {
      tester.view.physicalSize = const Size(900, 1400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            repositorioAlertasActivasProvider.overrideWithValue(
              _RepositorioAlertasFalso(alertas),
            ),
            abrirCanalPanelProvider.overrideWithValue(() async => null),
          ],
          child: MaterialApp(
            theme: AppTheme.light,
            home: const Scaffold(body: PantallaAlertas()),
          ),
        ),
      );
      await tester.pumpAndSettle();
      return ProviderScope.containerOf(
        tester.element(find.byType(PantallaAlertas)),
      );
    }

    testWidgets('muestra código, dirección, % de llenado y hora', (
      tester,
    ) async {
      await mostrar(tester, [
        _alerta(),
        _alerta(id: 2, codigo: 'PC-2', nivel: null),
      ]);

      expect(find.byType(TarjetaAlertaActiva), findsNWidgets(2));
      expect(find.text('2 activas'), findsOneWidget);
      expect(find.text('PC-PROTO'), findsOneWidget);
      expect(find.text('Av. Prueba 123'), findsNWidgets(2));
      expect(find.text('92%'), findsOneWidget);
      expect(find.text('Hora: 14:05'), findsNWidgets(2));
      expect(find.text('por confirmar'), findsOneWidget, reason: '% sin dato');
    });

    testWidgets('tocar una alerta lleva al punto en el mapa', (tester) async {
      final contenedor = await mostrar(tester, [_alerta()]);

      await tester.tap(find.byType(TarjetaAlertaActiva));
      await tester.pump();

      final navegacion = contenedor.read(navegacionMunicipalidadProvider);
      expect(navegacion.destino, DestinoMunicipalidad.mapa);
      expect(navegacion.focoPuntoCodigo, 'PC-PROTO');
    });

    testWidgets('sin alertas muestra el estado vacío', (tester) async {
      await mostrar(tester, const []);
      expect(find.text('Sin alertas activas'), findsOneWidget);
      expect(find.text('0 activas'), findsOneWidget);
    });
  });
}
