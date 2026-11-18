import 'package:dio/dio.dart';
import 'package:ecoruta_frontend_app/core/theme/app_theme.dart';
import 'package:ecoruta_frontend_app/core/ubicacion/servicio_ubicacion.dart';
import 'package:ecoruta_frontend_app/features/municipalidad/data/modelos_puntos_criticos.dart';
import 'package:ecoruta_frontend_app/features/municipalidad/data/modelos_reportes_campo.dart';
import 'package:ecoruta_frontend_app/features/municipalidad/data/repositorio_puntos_criticos.dart';
import 'package:ecoruta_frontend_app/features/municipalidad/data/repositorio_reportes_campo.dart';
import 'package:ecoruta_frontend_app/features/municipalidad/presentation/hoja_reportar_llenado.dart';
import 'package:ecoruta_frontend_app/features/municipalidad/presentation/mapa_puntos_criticos.dart';
import 'package:ecoruta_frontend_app/features/municipalidad/presentation/reportes_campo_providers.dart';
import 'package:ecoruta_frontend_app/features/municipalidad/presentation/widgets/resumen_operativo.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Reporte con la forma de `ReporteCampoOut` (datos de prueba).
Map<String, dynamic> _reporteJson({
  String estado = 'lleno',
  String creadoEn = '2026-11-17T09:00:00+00:00',
  double? lat = -8.1,
  double? lon = -79.03,
  double? distancia = 42.5,
  bool lejos = false,
  bool demo = false,
  String? observacion = 'Bolsas en la vereda',
}) => {
  'id': 7,
  'punto_critico_id': 3,
  'codigo_punto': '130101-1',
  'usuario_id': 11,
  'usuario_nombre': 'Ana Prueba',
  'estado': estado,
  'observacion': observacion,
  'lat': lat,
  'lon': lon,
  'distancia_m': distancia,
  'lejos_del_punto': lejos,
  'foto_url': null,
  'creado_en': creadoEn,
  'es_demo': demo,
};

Map<String, dynamic> _puntoJson({
  String estadoLlenado = 'lleno',
  bool vigente = true,
  Map<String, dynamic>? ultimo = const {
    'estado': 'lleno',
    'creado_en': '2026-11-17T09:00:00Z',
  },
}) => {
  'id': 3,
  'codigo': '130101-1',
  'estado': 'potencial',
  'priorizacion_obligatoria': false,
  'direccion': 'Av. de prueba 123',
  'referencia': null,
  'lat': -8.11,
  'lon': -79.02,
  'este_utm17s': null,
  'norte_utm17s': null,
  'creado_en': '2026-01-01T00:00:00Z',
  'ultimo_reporte': ultimo,
  'reporte_vigente': vigente,
  'estado_llenado': estadoLlenado,
};

class _RepositorioReportesFalso implements RepositorioReportesCampo {
  _RepositorioReportesFalso({
    this.lejos = false,
    this.fallos = 0,
    Map<String, UltimoReportePunto>? ultimos,
    this.resumenFijo,
  }) : ultimos = ultimos ?? {};

  final bool lejos;
  int fallos;
  final Map<String, UltimoReportePunto> ultimos;
  final ResumenReportes? resumenFijo;
  final enviados = <NuevoReporteCampo>[];

  @override
  Future<ReporteCampo> crear(NuevoReporteCampo reporte) async {
    enviados.add(reporte);
    if (fallos > 0) {
      fallos--;
      throw DioException.connectionError(
        requestOptions: RequestOptions(path: '/reportes-campo'),
        reason: 'sin red',
      );
    }
    return ReporteCampo(
      id: enviados.length,
      puntoCriticoId: 3,
      codigoPunto: reporte.codigoPunto,
      usuarioId: 11,
      usuarioNombre: 'Ana Prueba',
      estado: reporte.estado,
      observacion: reporte.observacion,
      lat: reporte.lat,
      lon: reporte.lon,
      distanciaM: reporte.lat == null ? null : (lejos ? 320 : 40),
      lejosDelPunto: lejos,
      creadoEn: DateTime(2026, 11, 17, 10, 30),
    );
  }

  @override
  Future<UltimoReportePunto> ultimoReporte(String codigo) async =>
      ultimos[codigo] ??
      UltimoReportePunto(
        codigo: codigo,
        reporteVigente: false,
        estadoLlenado: NivelLlenado.sinDatos,
        vigenciaHoras: 24,
      );

  @override
  Future<ResumenReportes> resumen() async => resumenFijo!;
}

class _UbicacionFalsa implements ServicioUbicacion {
  _UbicacionFalsa(this.coordenadas);

  final Coordenadas? coordenadas;
  int pedidos = 0;

  @override
  Future<Coordenadas?> ubicacionActual() async {
    pedidos++;
    return coordenadas;
  }
}

class _RepositorioPuntosFalso implements RepositorioPuntosCriticos {
  _RepositorioPuntosFalso(this.puntos);

  final List<PuntoCritico> puntos;

  @override
  Future<List<PuntoCritico>> listarTodos() async => puntos;

  @override
  Future<PuntoCritico?> obtener(String codigo) async =>
      puntos.where((p) => p.codigo == codigo).firstOrNull;

  @override
  Future<ResumenPuntosCriticos> resumen() async =>
      ResumenPuntosCriticos.desdePuntos(puntos);
}

/// Abre la hoja desde un botón, como en la app, y guarda lo que devuelve.
Future<List<ReporteCampo?>> _abrirHoja(
  WidgetTester tester, {
  required _RepositorioReportesFalso repositorio,
  required _UbicacionFalsa ubicacion,
}) async {
  tester.view.physicalSize = const Size(600, 1400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  final resultados = <ReporteCampo?>[];
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        repositorioReportesCampoProvider.overrideWithValue(repositorio),
        servicioUbicacionProvider.overrideWithValue(ubicacion),
        repositorioPuntosCriticosProvider.overrideWithValue(
          _RepositorioPuntosFalso(const []),
        ),
      ],
      child: MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: Builder(
            builder: (context) => Center(
              child: ElevatedButton(
                onPressed: () async => resultados.add(
                  await mostrarHojaReportarLlenado(
                    context,
                    codigoPunto: '130101-1',
                  ),
                ),
                child: const Text('abrir'),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('abrir'));
  await tester.pumpAndSettle();
  return resultados;
}

Finder _opcion(NivelLlenado nivel) =>
    find.byKey(Key('opcion-llenado-${nivel.valorApi}'));

FilledButton _botonEnviar(WidgetTester tester) =>
    tester.widget<FilledButton>(
      find.ancestor(of: find.text('Enviar'), matching: find.byType(FilledButton)),
    );

Color _colorMarcador(WidgetTester tester) {
  final circulo = tester.widget<Container>(
    find.descendant(
      of: find.byType(MarcadorPuntoCritico),
      matching: find.byType(Container),
    ),
  );
  return (circulo.decoration! as BoxDecoration).color!;
}

void main() {
  group('modelos', () {
    test('NivelLlenado: sin_datos, desconocido o ausente es "Sin datos"', () {
      expect(NivelLlenado.desdeApi('desbordado'), NivelLlenado.desbordado);
      expect(NivelLlenado.desdeApi('sin_datos'), NivelLlenado.sinDatos);
      expect(NivelLlenado.desdeApi('casi_lleno'), NivelLlenado.sinDatos);
      expect(NivelLlenado.desdeApi(null), NivelLlenado.sinDatos);
      expect(NivelLlenado.sinDatos.etiqueta, 'Sin datos');
    });

    test('ReporteCampo.fromJson lee todos los campos de ReporteCampoOut', () {
      final reporte = ReporteCampo.fromJson(_reporteJson(lejos: true));
      expect(reporte.id, 7);
      expect(reporte.puntoCriticoId, 3);
      expect(reporte.codigoPunto, '130101-1');
      expect(reporte.usuarioId, 11);
      expect(reporte.usuarioNombre, 'Ana Prueba');
      expect(reporte.estado, NivelLlenado.lleno);
      expect(reporte.observacion, 'Bolsas en la vereda');
      expect(reporte.lat, -8.1);
      expect(reporte.lon, -79.03);
      expect(reporte.distanciaM, 42.5);
      expect(reporte.lejosDelPunto, isTrue);
      expect(reporte.fotoUrl, isNull);
      expect(reporte.esDemo, isFalse);
      expect(
        reporte.creadoEn.toUtc(),
        DateTime.utc(2026, 11, 17, 9),
        reason: 'la fecha llega con zona horaria y se pasa a hora local',
      );
    });

    test('sin GPS: lat, lon y distancia_m nulos', () {
      final reporte = ReporteCampo.fromJson(
        _reporteJson(lat: null, lon: null, distancia: null),
      );
      expect(reporte.lat, isNull);
      expect(reporte.distanciaM, isNull);
      expect(reporte.lejosDelPunto, isFalse);
    });

    test('NuevoReporteCampo: lat/lon juntas o ninguna; observación opcional', () {
      final sinGps = NuevoReporteCampo(
        codigoPunto: '130101-1',
        estado: NivelLlenado.medio,
        observacion: '   ',
      );
      expect(sinGps.toJson(), {'codigo_punto': '130101-1', 'estado': 'medio'});

      final conGps = NuevoReporteCampo(
        codigoPunto: '130101-1',
        estado: NivelLlenado.desbordado,
        observacion: '  Basura en la pista ',
        lat: -8.1,
        lon: -79.0,
      );
      expect(conGps.toJson(), {
        'codigo_punto': '130101-1',
        'estado': 'desbordado',
        'observacion': 'Basura en la pista',
        'lat': -8.1,
        'lon': -79.0,
      });
    });

    test('PuntoCritico con reporte vigente', () {
      final punto = PuntoCritico.fromJson(_puntoJson());
      expect(punto.estadoLlenado, NivelLlenado.lleno);
      expect(punto.reporteVigente, isTrue);
      expect(punto.ultimoReporte?.estado, NivelLlenado.lleno);
      expect(punto.ultimoReporte?.creadoEn.toUtc(), DateTime.utc(2026, 11, 17, 9));
    });

    test('PuntoCritico con reporte vencido: "Sin datos", no el nivel viejo', () {
      final punto = PuntoCritico.fromJson(
        _puntoJson(estadoLlenado: 'sin_datos', vigente: false),
      );
      expect(punto.estadoLlenado, NivelLlenado.sinDatos);
      expect(punto.reporteVigente, isFalse);
      // Se conserva la fecha del último reporte, pero no define el nivel.
      expect(punto.ultimoReporte, isNotNull);
    });

    test('PuntoCritico sin reportes ni campos de llenado', () {
      final json = _puntoJson(estadoLlenado: 'sin_datos', vigente: false)
        ..['ultimo_reporte'] = null;
      final punto = PuntoCritico.fromJson(json);
      expect(punto.estadoLlenado, NivelLlenado.sinDatos);
      expect(punto.ultimoReporte, isNull);

      final antiguo = PuntoCritico.fromJson(
        _puntoJson()
          ..remove('estado_llenado')
          ..remove('reporte_vigente')
          ..remove('ultimo_reporte'),
      );
      expect(antiguo.estadoLlenado, NivelLlenado.sinDatos);
      expect(antiguo.reporteVigente, isFalse);
    });

    test('UltimoReportePunto.fromJson con y sin reporte', () {
      final con = UltimoReportePunto.fromJson({
        'codigo': '130101-1',
        'reporte_vigente': true,
        'estado_llenado': 'lleno',
        'vigencia_horas': 24,
        'reporte': _reporteJson(),
      });
      expect(con.estadoLlenado, NivelLlenado.lleno);
      expect(con.vigenciaHoras, 24);
      expect(con.reporte?.usuarioNombre, 'Ana Prueba');

      final sin = UltimoReportePunto.fromJson({
        'codigo': '130101-1',
        'reporte_vigente': false,
        'estado_llenado': 'sin_datos',
        'vigencia_horas': 24,
        'reporte': null,
      });
      expect(sin.estadoLlenado, NivelLlenado.sinDatos);
      expect(sin.reporte, isNull);
    });

    test('ResumenReportes.fromJson', () {
      final resumen = ResumenReportes.fromJson({
        'total_puntos': 10,
        'vigencia_horas': 24.0,
        'por_estado': {'vacio': 1, 'medio': 2, 'lleno': 3, 'desbordado': 0},
        'sin_datos': 4,
      });
      expect(resumen.totalPuntos, 10);
      expect(resumen.cantidad(NivelLlenado.vacio), 1);
      expect(resumen.cantidad(NivelLlenado.medio), 2);
      expect(resumen.cantidad(NivelLlenado.lleno), 3);
      expect(resumen.cantidad(NivelLlenado.desbordado), 0);
      expect(resumen.cantidad(NivelLlenado.sinDatos), 4);
    });

    test('"hace X" y fecha/hora', () {
      final ahora = DateTime(2026, 11, 17, 12);
      expect(haceCuanto(ahora.subtract(const Duration(seconds: 20)), ahora),
          'hace menos de un minuto');
      expect(haceCuanto(ahora.subtract(const Duration(minutes: 1)), ahora),
          'hace 1 minuto');
      expect(haceCuanto(ahora.subtract(const Duration(minutes: 45)), ahora),
          'hace 45 minutos');
      expect(haceCuanto(ahora.subtract(const Duration(hours: 1)), ahora),
          'hace 1 hora');
      expect(haceCuanto(ahora.subtract(const Duration(hours: 3)), ahora),
          'hace 3 horas');
      expect(haceCuanto(ahora.subtract(const Duration(days: 3)), ahora),
          'hace 3 días');
      expect(fechaHoraReporte(DateTime(2026, 11, 7, 9, 5)), '07/11/2026 09:05');
    });

    test('mock: marca lejos_del_punto a más de 150 m y lo guarda igual', () {
      ReportesCampoEjemplo.reiniciar();
      addTearDown(ReportesCampoEjemplo.reiniciar);
      final punto = RepositorioPuntosCriticosMock.puntos.first;
      final cerca = ReportesCampoEjemplo.agregar(
        NuevoReporteCampo(
          codigoPunto: punto.codigo,
          estado: NivelLlenado.vacio,
          lat: punto.latitud,
          lon: punto.longitud,
        ),
        punto,
      );
      expect(cerca.distanciaM, closeTo(0, 0.01));
      expect(cerca.lejosDelPunto, isFalse);

      // ~0,005° de latitud son unos 550 m.
      final lejos = ReportesCampoEjemplo.agregar(
        NuevoReporteCampo(
          codigoPunto: punto.codigo,
          estado: NivelLlenado.lleno,
          lat: punto.latitud! + 0.005,
          lon: punto.longitud,
        ),
        punto,
      );
      expect(lejos.distanciaM, inInclusiveRange(500, 600));
      expect(lejos.lejosDelPunto, isTrue);
      expect(
        ReportesCampoEjemplo.ultimoDe(punto.codigo).estadoLlenado,
        NivelLlenado.lleno,
      );
    });
  });

  group('hoja "Reportar llenado"', () {
    testWidgets('envía el reporte con GPS y confirma', (tester) async {
      final repositorio = _RepositorioReportesFalso();
      final ubicacion = _UbicacionFalsa((lat: -8.11, lon: -79.02));
      final resultados = await _abrirHoja(
        tester,
        repositorio: repositorio,
        ubicacion: ubicacion,
      );

      expect(find.text('Reportar llenado'), findsOneWidget);
      expect(find.text('Punto crítico 130101-1'), findsOneWidget);
      for (final nivel in NivelLlenado.reportables) {
        expect(_opcion(nivel), findsOneWidget);
      }
      expect(_botonEnviar(tester).onPressed, isNull,
          reason: 'sin elegir un nivel no se puede enviar');

      await tester.tap(_opcion(NivelLlenado.lleno));
      await tester.enterText(
        find.byKey(const Key('reporte-observacion')),
        'Bolsas en la vereda',
      );
      await tester.pump();
      await tester.tap(find.text('Enviar'));
      await tester.pumpAndSettle();

      expect(repositorio.enviados, hasLength(1));
      expect(repositorio.enviados.single.toJson(), {
        'codigo_punto': '130101-1',
        'estado': 'lleno',
        'observacion': 'Bolsas en la vereda',
        'lat': -8.11,
        'lon': -79.02,
      });
      expect(find.text('Reporte enviado'), findsOneWidget);
      expect(find.text('Lleno'), findsOneWidget);
      expect(find.text(mensajeLejosDelPunto), findsNothing);
      expect(find.textContaining('sin ubicación'), findsNothing);

      await tester.tap(find.text('Listo'));
      await tester.pumpAndSettle();
      expect(find.text('Reporte enviado'), findsNothing);
      expect(resultados.single?.estado, NivelLlenado.lleno);
    });

    testWidgets('lejos_del_punto=true muestra el aviso de 150 m', (
      tester,
    ) async {
      await _abrirHoja(
        tester,
        repositorio: _RepositorioReportesFalso(lejos: true),
        ubicacion: _UbicacionFalsa((lat: -8.2, lon: -79.1)),
      );

      await tester.tap(_opcion(NivelLlenado.desbordado));
      await tester.pump();
      await tester.tap(find.text('Enviar'));
      await tester.pumpAndSettle();

      expect(find.text('Reporte enviado'), findsOneWidget);
      expect(
        find.text('Estás a más de 150 m del punto; el reporte se guardó igual'),
        findsOneWidget,
      );
    });

    testWidgets('sin permiso de ubicación se envía sin coordenadas', (
      tester,
    ) async {
      final repositorio = _RepositorioReportesFalso();
      await _abrirHoja(
        tester,
        repositorio: repositorio,
        ubicacion: _UbicacionFalsa(null),
      );

      await tester.tap(_opcion(NivelLlenado.vacio));
      await tester.pump();
      await tester.tap(find.text('Enviar'));
      await tester.pumpAndSettle();

      expect(repositorio.enviados.single.toJson(), {
        'codigo_punto': '130101-1',
        'estado': 'vacio',
      });
      expect(find.text('Reporte enviado'), findsOneWidget);
      expect(
        find.text('Se envió sin ubicación (GPS apagado o sin permiso).'),
        findsOneWidget,
      );
    });

    testWidgets('error: muestra el motivo y reintenta con los mismos datos', (
      tester,
    ) async {
      final repositorio = _RepositorioReportesFalso(fallos: 1);
      final ubicacion = _UbicacionFalsa((lat: -8.11, lon: -79.02));
      await _abrirHoja(tester, repositorio: repositorio, ubicacion: ubicacion);

      await tester.tap(_opcion(NivelLlenado.medio));
      await tester.pump();
      await tester.tap(find.text('Enviar'));
      await tester.pumpAndSettle();

      expect(find.text('No se pudo enviar el reporte'), findsOneWidget);
      expect(
        find.text('No se pudo conectar con el servidor. Revisa tu conexión.'),
        findsOneWidget,
      );

      await tester.tap(find.text('Reintentar'));
      await tester.pumpAndSettle();

      expect(find.text('Reporte enviado'), findsOneWidget);
      expect(repositorio.enviados, hasLength(2));
      expect(repositorio.enviados.last.estado, NivelLlenado.medio);
      expect(ubicacion.pedidos, 1, reason: 'la ubicación se pide una vez');
    });

    test('mensajes de error según la respuesta', () {
      DioException conCodigo(int codigo) {
        final pedido = RequestOptions(path: '/reportes-campo');
        return DioException(
          requestOptions: pedido,
          response: Response(requestOptions: pedido, statusCode: codigo),
          type: DioExceptionType.badResponse,
        );
      }

      expect(mensajeErrorReporte(conCodigo(404)),
          'El punto crítico no existe en el sistema.');
      expect(mensajeErrorReporte(conCodigo(422)),
          'El reporte no es válido. Revisa el estado y la observación.');
      expect(mensajeErrorReporte(conCodigo(403)),
          'Tu sesión no tiene permiso para reportar.');
    });
  });

  group('mapa y detalle del punto', () {
    final ahora = DateTime(2026, 11, 17, 12);

    Future<void> mostrarMapa(
      WidgetTester tester, {
      required PuntoCritico punto,
      required UltimoReportePunto ultimo,
    }) async {
      tester.view.physicalSize = const Size(900, 1400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            repositorioPuntosCriticosProvider.overrideWithValue(
              _RepositorioPuntosFalso([punto]),
            ),
            repositorioReportesCampoProvider.overrideWithValue(
              _RepositorioReportesFalso(ultimos: {punto.codigo: ultimo}),
            ),
            relojReportesProvider.overrideWithValue(() => ahora),
          ],
          child: MaterialApp(
            theme: AppTheme.light,
            home: const Scaffold(body: MapaPuntosCriticos()),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    PuntoCritico punto({
      required NivelLlenado nivel,
      required bool vigente,
      DateTime? fecha,
      NivelLlenado? estadoReporte,
    }) => PuntoCritico(
      id: 3,
      codigo: '130101-1',
      estado: EstadoPuntoCritico.potencial,
      priorizacionObligatoria: false,
      direccion: 'Av. de prueba 123',
      latitud: -8.11,
      longitud: -79.02,
      estadoLlenado: nivel,
      reporteVigente: vigente,
      ultimoReporte: fecha == null
          ? null
          : UltimoReporteBreve(
              estado: estadoReporte ?? nivel,
              creadoEn: fecha,
            ),
    );

    ReporteCampo reporte(NivelLlenado estado, DateTime fecha) => ReporteCampo(
      id: 1,
      puntoCriticoId: 3,
      codigoPunto: '130101-1',
      usuarioId: 11,
      usuarioNombre: 'Ana Prueba',
      estado: estado,
      creadoEn: fecha,
    );

    testWidgets('reporte vigente: color, estado, fecha y "hace X horas"', (
      tester,
    ) async {
      final fecha = ahora.subtract(const Duration(hours: 3));
      await mostrarMapa(
        tester,
        punto: punto(nivel: NivelLlenado.lleno, vigente: true, fecha: fecha),
        ultimo: UltimoReportePunto(
          codigo: '130101-1',
          reporteVigente: true,
          estadoLlenado: NivelLlenado.lleno,
          vigenciaHoras: 24,
          reporte: reporte(NivelLlenado.lleno, fecha),
        ),
      );

      expect(_colorMarcador(tester), const Color(0xFFE5702A));

      await tester.tap(find.byType(MarcadorPuntoCritico));
      await tester.pumpAndSettle();

      final detalle = find.byType(SeccionLlenadoPunto);
      expect(
        find.descendant(of: detalle, matching: find.text('Lleno')),
        findsOneWidget,
      );
      expect(
        find.text('Último reporte: 17/11/2026 09:00 · hace 3 horas'),
        findsOneWidget,
      );
      expect(find.text('Reportado por Ana Prueba'), findsOneWidget);
      expect(find.textContaining('Ya no está vigente'), findsNothing);
    });

    testWidgets('sin datos: marcador gris y "Sin datos", nunca el nivel viejo', (
      tester,
    ) async {
      // Hubo un reporte "desbordado" hace 30 h: ya no está vigente.
      final fecha = ahora.subtract(const Duration(hours: 30));
      await mostrarMapa(
        tester,
        punto: punto(
          nivel: NivelLlenado.sinDatos,
          vigente: false,
          fecha: fecha,
          estadoReporte: NivelLlenado.desbordado,
        ),
        ultimo: UltimoReportePunto(
          codigo: '130101-1',
          reporteVigente: false,
          estadoLlenado: NivelLlenado.sinDatos,
          vigenciaHoras: 24,
          reporte: reporte(NivelLlenado.desbordado, fecha),
        ),
      );

      final gris = AppTheme.light.extension<ColoresEstado>()!.sinDatos.color;
      expect(_colorMarcador(tester), gris);

      await tester.tap(find.byType(MarcadorPuntoCritico));
      await tester.pumpAndSettle();

      final detalle = find.byType(SeccionLlenadoPunto);
      expect(
        find.descendant(of: detalle, matching: find.text('Sin datos')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: detalle, matching: find.text('Desbordado')),
        findsNothing,
      );
      expect(find.text('Ya no está vigente (más de 24 h).'), findsOneWidget);
    });

    testWidgets('punto sin reportes: "Sin datos" y aviso de que no hay', (
      tester,
    ) async {
      await mostrarMapa(
        tester,
        punto: punto(nivel: NivelLlenado.sinDatos, vigente: false),
        ultimo: const UltimoReportePunto(
          codigo: '130101-1',
          reporteVigente: false,
          estadoLlenado: NivelLlenado.sinDatos,
          vigenciaHoras: 24,
        ),
      );

      await tester.tap(find.byType(MarcadorPuntoCritico));
      await tester.pumpAndSettle();

      expect(
        find.descendant(
          of: find.byType(SeccionLlenadoPunto),
          matching: find.text('Sin datos'),
        ),
        findsOneWidget,
      );
      expect(
        find.text('Aún no hay reportes de campo de este punto.'),
        findsOneWidget,
      );
    });

    testWidgets('"Reportar llenado" en el detalle abre la hoja del punto', (
      tester,
    ) async {
      await mostrarMapa(
        tester,
        punto: punto(nivel: NivelLlenado.sinDatos, vigente: false),
        ultimo: const UltimoReportePunto(
          codigo: '130101-1',
          reporteVigente: false,
          estadoLlenado: NivelLlenado.sinDatos,
          vigenciaHoras: 24,
        ),
      );

      await tester.tap(find.byType(MarcadorPuntoCritico));
      await tester.pumpAndSettle();
      final boton = find.widgetWithText(FilledButton, 'Reportar llenado');
      await tester.ensureVisible(boton);
      await tester.tap(boton);
      await tester.pumpAndSettle();

      expect(find.byType(HojaReportarLlenado), findsOneWidget);
      expect(find.text('Punto crítico 130101-1'), findsWidgets);
      expect(_opcion(NivelLlenado.desbordado), findsOneWidget);
    });

    testWidgets('la leyenda muestra los cinco estados de llenado', (
      tester,
    ) async {
      await mostrarMapa(
        tester,
        punto: punto(nivel: NivelLlenado.sinDatos, vigente: false),
        ultimo: const UltimoReportePunto(
          codigo: '130101-1',
          reporteVigente: false,
          estadoLlenado: NivelLlenado.sinDatos,
          vigenciaHoras: 24,
        ),
      );

      for (final nivel in NivelLlenado.values) {
        expect(find.text(nivel.etiqueta), findsOneWidget);
      }
    });
  });

  group('resumen en el panel', () {
    Future<void> mostrarResumen(
      WidgetTester tester,
      ResumenReportes resumen,
    ) async {
      tester.view.physicalSize = const Size(600, 1400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            repositorioReportesCampoProvider.overrideWithValue(
              _RepositorioReportesFalso(resumenFijo: resumen),
            ),
          ],
          child: MaterialApp(
            theme: AppTheme.light,
            home: const Scaffold(
              body: SingleChildScrollView(child: BloqueLlenadoReportado()),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('muestra cuántos puntos hay por estado y sin datos', (
      tester,
    ) async {
      await mostrarResumen(
        tester,
        const ResumenReportes(
          totalPuntos: 10,
          vigenciaHoras: 24,
          porEstado: {
            NivelLlenado.vacio: 1,
            NivelLlenado.medio: 2,
            NivelLlenado.lleno: 3,
            NivelLlenado.desbordado: 0,
          },
          sinDatos: 4,
        ),
      );

      expect(find.text('Llenado reportado'), findsOneWidget);
      expect(find.textContaining('10 puntos'), findsOneWidget);
      const esperados = {
        'vacio': ('Vacío', '1'),
        'medio': ('Medio', '2'),
        'lleno': ('Lleno', '3'),
        'desbordado': ('Desbordado', '0'),
        'sin_datos': ('Sin datos', '4'),
      };
      for (final MapEntry(key: clave, value: (etiqueta, valor))
          in esperados.entries) {
        final tarjeta = find.byKey(Key('resumen-llenado-$clave'));
        expect(tarjeta, findsOneWidget);
        expect(
          find.descendant(of: tarjeta, matching: find.text(etiqueta)),
          findsOneWidget,
        );
        expect(
          find.descendant(of: tarjeta, matching: find.text(valor)),
          findsOneWidget,
        );
      }
    });

    testWidgets('sin puntos registrados lo indica', (tester) async {
      await mostrarResumen(
        tester,
        const ResumenReportes(
          totalPuntos: 0,
          vigenciaHoras: 24,
          porEstado: {},
          sinDatos: 0,
        ),
      );

      expect(find.text('No hay puntos críticos registrados'), findsOneWidget);
    });
  });
}
