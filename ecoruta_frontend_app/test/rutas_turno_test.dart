import 'package:dio/dio.dart';
import 'package:ecoruta_frontend_app/core/theme/app_theme.dart';
import 'package:ecoruta_frontend_app/features/conductor/data/modelos_conductor.dart';
import 'package:ecoruta_frontend_app/features/municipalidad/data/modelos_generacion_rutas.dart';
import 'package:ecoruta_frontend_app/features/municipalidad/data/modelos_zonas_ruta.dart';
import 'package:ecoruta_frontend_app/features/municipalidad/data/repositorio_rutas_turno.dart';
import 'package:ecoruta_frontend_app/features/municipalidad/presentation/pantalla_mapa_rutas.dart';
import 'package:ecoruta_frontend_app/features/municipalidad/presentation/pantalla_rutas.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Respuesta 201 con la forma de `RutasTurnoOut` (datos de prueba).
Map<String, dynamic> _respuestaJson() => {
  'turno': 'tarde',
  'fecha': '2026-11-17',
  'nro_camiones': 2,
  'nro_puntos': 5,
  'max_paradas_por_ruta': 3,
  'metodo_distancia': 'haversine_aprox',
  'distancia_total_km': 18.46,
  'tiempo_total_min': 125.0,
  'rutas_reemplazadas': 1,
  'camiones_con_ruta_en_curso': ['T3X-999'],
  'parametros': {
    'velocidad_media_kmh': 18.0,
    'minutos_por_parada': 6.0,
    'factor_circuito': 1.3,
    'capacidad_camion_usada': false,
    'provisionales': ['velocidad_media_kmh', 'minutos_por_parada'],
    'notas': ['Sin datos de tráfico: velocidad media fija.'],
  },
  'rutas': [
    {
      'ruta_id': 41,
      'camion': {'id': 7, 'placa': 'T1A-111'},
      'conductor_id': 12,
      'hora_inicio': '2026-11-17T13:00:00',
      'hora_fin': '2026-11-17T14:10:00',
      'excede_turno': false,
      'distancia_km': 10.2,
      'tiempo_estimado_min': 70.0,
      'paradas': [
        // Llegan desordenadas a propósito: se ordenan por `orden`.
        {
          'orden': 2,
          'punto_critico_id': 302,
          'codigo': '130101-2',
          'lat': -8.12,
          'lon': -79.03,
          'direccion': 'Jr. B',
        },
        {
          'orden': 1,
          'punto_critico_id': 301,
          'codigo': '130101-1',
          'lat': -8.11,
          'lon': -79.02,
          'direccion': 'Av. A',
        },
      ],
    },
    {
      'ruta_id': 42,
      'camion': {'id': 8, 'placa': 'T1A-222'},
      'conductor_id': null,
      'hora_inicio': '2026-11-17T13:00:00',
      'hora_fin': '2026-11-17T21:30:00',
      'excede_turno': true,
      'distancia_km': 8.26,
      'tiempo_estimado_min': 55.0,
      'paradas': [
        {
          'orden': 1,
          'punto_critico_id': 303,
          'codigo': '130101-3',
          'lat': -8.10,
          'lon': -79.04,
          'direccion': 'Calle C',
        },
      ],
    },
  ],
};

class _RepositorioFalso implements RepositorioRutasTurno {
  _RepositorioFalso({this.error});

  final ErrorGeneracionRutas? error;
  final solicitudes = <SolicitudGenerarRutas>[];

  @override
  Future<ResultadoGeneracionRutas> generar(
    SolicitudGenerarRutas solicitud,
  ) async {
    solicitudes.add(solicitud);
    if (error != null) throw error!;
    return ResultadoGeneracionRutas.fromJson(_respuestaJson());
  }

  @override
  Future<List<RutaConductor>> rutasDeHoy() async => const [];
}

DioException _errorHttp(int codigo, Object? cuerpo) {
  final pedido = RequestOptions(path: '/rutas/generar');
  return DioException(
    requestOptions: pedido,
    response: Response(
      requestOptions: pedido,
      statusCode: codigo,
      data: cuerpo,
    ),
    type: DioExceptionType.badResponse,
  );
}

Future<void> _mostrar(
  WidgetTester tester,
  _RepositorioFalso repositorio, {
  Size pantalla = const Size(900, 2400),
}) async {
  tester.view.physicalSize = pantalla;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [repositorioRutasTurnoProvider.overrideWithValue(repositorio)],
      child: MaterialApp(
        theme: AppTheme.light,
        home: const Scaffold(body: PantallaRutas()),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

/// Abre el diálogo, elige el turno y los interruptores, y confirma.
Future<void> _generar(
  WidgetTester tester, {
  String turno = 'Tarde',
  bool prioritarios = false,
  bool reserva = false,
}) async {
  await tester.tap(find.widgetWithText(FilledButton, 'Generar rutas'));
  await tester.pumpAndSettle();
  expect(find.byType(DialogoGenerarRutas), findsOneWidget);

  await tester.tap(
    find.descendant(
      of: find.byType(SegmentedButton<TurnoZona>),
      matching: find.text(turno),
    ),
  );
  if (prioritarios) {
    await tester.tap(find.widgetWithText(SwitchListTile, 'Solo puntos prioritarios'));
  }
  if (reserva) {
    await tester.tap(
      find.widgetWithText(SwitchListTile, 'Incluir camiones de reserva'),
    );
  }
  await tester.pump();
  await tester.tap(find.widgetWithText(FilledButton, 'Generar'));
  await tester.pumpAndSettle();
}

void main() {
  group('modelos', () {
    test('parsea RutasTurnoOut completo', () {
      final r = ResultadoGeneracionRutas.fromJson(_respuestaJson());
      expect(r.turno, TurnoZona.tarde);
      expect(r.fecha, DateTime(2026, 11, 17));
      expect(r.nroCamiones, 2);
      expect(r.nroPuntos, 5);
      expect(r.maxParadasPorRuta, 3);
      expect(r.distanciaTotalKm, 18.46);
      expect(r.tiempoTotalMin, 125);
      expect(r.rutasReemplazadas, 1);
      expect(r.camionesConRutaEnCurso, ['T3X-999']);
      expect(r.distanciasAproximadas, isTrue);

      expect(r.parametros.velocidadMediaKmh, 18);
      expect(r.parametros.minutosPorParada, 6);
      expect(r.parametros.factorCircuito, 1.3);
      expect(r.parametros.capacidadCamionUsada, isFalse);
      expect(r.parametros.provisionales, hasLength(2));
      expect(r.parametros.notas.single, contains('velocidad media fija'));

      final primera = r.rutas.first;
      expect(primera.rutaId, 41);
      expect(primera.camionId, 7);
      expect(primera.placa, 'T1A-111');
      expect(primera.conductorId, 12);
      expect(primera.horaInicio, DateTime(2026, 11, 17, 13));
      expect(primera.excedeTurno, isFalse);
      expect(primera.distanciaKm, 10.2);
      expect(primera.tiempoEstimadoMin, 70);
      expect(primera.paradas.map((p) => p.orden), [1, 2]);
      expect(primera.paradas.first.codigo, '130101-1');
      expect(primera.paradas.first.puntoCriticoId, 301);

      expect(r.rutas.last.conductorId, isNull);
      expect(r.rutas.last.excedeTurno, isTrue);
    });

    test('factor_circuito puede venir null; otro método no es aproximado', () {
      final json = _respuestaJson()
        ..['metodo_distancia'] = 'osrm'
        ..['parametros'] = {
          'velocidad_media_kmh': 20,
          'minutos_por_parada': 5,
          'factor_circuito': null,
          'capacidad_camion_usada': true,
          'provisionales': <String>[],
          'notas': <String>[],
        };
      final r = ResultadoGeneracionRutas.fromJson(json);
      expect(r.parametros.factorCircuito, isNull);
      expect(r.distanciasAproximadas, isFalse);
    });

    test('cuerpo de la solicitud', () {
      expect(
        const SolicitudGenerarRutas(
          turno: TurnoZona.noche,
          soloPrioritarios: true,
        ).toJson(),
        {
          'turno': 'noche',
          'solo_prioritarios': true,
          'solo_con_reporte_lleno': false,
          'incluir_reserva': false,
          'max_paradas_por_ruta': null,
        },
      );
      expect(
        SolicitudGenerarRutas(
          turno: TurnoZona.manana,
          fecha: DateTime(2026, 3, 5),
          incluirReserva: true,
          maxParadasPorRuta: 12,
        ).toJson(),
        containsPair('fecha', '2026-03-05'),
      );
    });

    test('409, 404 y 422 tienen mensajes claros y conservan el detalle', () {
      final conflicto = errorGeneracionDesde(
        _errorHttp(409, {
          'detail': 'No hay camiones operativos (no demo) en el turno tarde.',
        }),
      );
      expect(conflicto.codigo, 409);
      expect(conflicto.mensaje, contains('No hay camiones disponibles'));
      expect(conflicto.detalle, contains('turno tarde'));

      final sinPuntos = errorGeneracionDesde(
        _errorHttp(404, {'detail': 'No hay puntos críticos que cumplan los filtros'}),
      );
      expect(
        sinPuntos.mensaje,
        'Ningún punto crítico cumple los filtros elegidos.',
      );

      // 422 de validación: `detail` es una lista y no se muestra tal cual.
      final invalido = errorGeneracionDesde(
        _errorHttp(422, {
          'detail': [
            {'loc': ['body', 'turno'], 'msg': 'inválido', 'type': 'enum'},
          ],
        }),
      );
      expect(invalido.mensaje, contains('revisa el turno'));
      expect(invalido.detalle, isNull);

      final sinRed = errorGeneracionDesde(
        DioException.connectionError(
          requestOptions: RequestOptions(path: '/rutas/generar'),
          reason: 'sin red',
        ),
      );
      expect(sinRed.mensaje, contains('No se pudo conectar'));
    });
  });

  group('pantalla Rutas', () {
    testWidgets('sin rutas hoy lo indica, sin datos inventados', (
      tester,
    ) async {
      await _mostrar(tester, _RepositorioFalso());

      expect(find.textContaining('Aún no hay rutas para hoy'), findsOneWidget);
      expect(find.textContaining('Ahorro'), findsNothing);
    });

    testWidgets('generar: turno, interruptores, confirmación y resumen', (
      tester,
    ) async {
      final repositorio = _RepositorioFalso();
      await _mostrar(tester, repositorio);

      await _generar(tester, turno: 'Tarde', prioritarios: true, reserva: true);

      expect(repositorio.solicitudes.single.toJson(), {
        'turno': 'tarde',
        'solo_prioritarios': true,
        'solo_con_reporte_lleno': false,
        'incluir_reserva': true,
        'max_paradas_por_ruta': null,
      });

      final resumen = find.byType(ResumenGeneracionRutas);
      Finder enResumen(String texto) =>
          find.descendant(of: resumen, matching: find.text(texto));

      expect(enResumen('Rutas generadas · Turno Tarde · 17/11/2026'),
          findsOneWidget);
      expect(enResumen('Camiones'), findsOneWidget);
      expect(enResumen('2'), findsOneWidget);
      expect(enResumen('5'), findsOneWidget);
      expect(enResumen('18.5 km'), findsOneWidget);
      expect(enResumen('2 h 5 min'), findsOneWidget);
      expect(
        enResumen('Distancias aproximadas (en línea recta, no por calles).'),
        findsOneWidget,
      );
      expect(
        enResumen('Se reemplazó 1 ruta pendiente de este turno.'),
        findsOneWidget,
      );
      expect(
        enResumen('Sin cambios por tener una ruta en curso: T3X-999.'),
        findsOneWidget,
      );

      // Rutas por camión.
      expect(find.byType(TarjetaRutaGenerada), findsNWidgets(2));
      expect(enResumen('T1A-111'), findsOneWidget);
      expect(enResumen('2 paradas · 10.2 km · 13:00 – 14:10'), findsOneWidget);
      expect(enResumen('1 paradas · 8.3 km · 13:00 – 21:30'), findsOneWidget);
      expect(enResumen('Excede el turno'), findsOneWidget);

      // Parámetros provisionales en texto pequeño.
      expect(enResumen('Parámetros provisionales'), findsOneWidget);
      expect(
        find.descendant(
          of: resumen,
          matching: find.textContaining('Velocidad media 18 km/h'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: resumen,
          matching: find.text(
            'Por confirmar: velocidad media, minutos por parada.',
          ),
        ),
        findsOneWidget,
      );
      expect(enResumen('Sin datos de tráfico: velocidad media fija.'),
          findsOneWidget);
    });

    testWidgets('cancelar el diálogo no genera', (tester) async {
      final repositorio = _RepositorioFalso();
      await _mostrar(tester, repositorio);

      await tester.tap(find.widgetWithText(FilledButton, 'Generar rutas'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();

      expect(repositorio.solicitudes, isEmpty);
      expect(find.byType(ResumenGeneracionRutas), findsNothing);
    });

    testWidgets('el selector de turno cabe en una línea en un celular', (
      tester,
    ) async {
      await _mostrar(
        tester,
        _RepositorioFalso(),
        pantalla: const Size(360, 800),
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Generar rutas'));
      await tester.pumpAndSettle();

      final selector = find.byType(SegmentedButton<TurnoZona>);
      Rect rect(String texto) => tester.getRect(
        find.descendant(of: selector, matching: find.text(texto)),
      );
      final manana = rect('Mañana');
      final tarde = rect('Tarde');
      final noche = rect('Noche');
      final alto = manana.height;

      // Misma altura (una línea), sin solaparse y dentro del selector.
      expect(tarde.height, alto);
      expect(noche.height, alto);
      expect(manana.right, lessThanOrEqualTo(tarde.left));
      expect(tarde.right, lessThanOrEqualTo(noche.left));
      expect(noche.right, lessThanOrEqualTo(tester.getRect(selector).right));
      expect(tester.takeException(), isNull);
    });

    testWidgets('409: sin camiones disponibles, con el detalle del backend', (
      tester,
    ) async {
      await _mostrar(
        tester,
        _RepositorioFalso(
          error: errorGeneracionDesde(
            _errorHttp(409, {
              'detail':
                  'Todos los camiones del turno tarde ya tienen una ruta en '
                  'curso o completada el 2026-11-17.',
            }),
          ),
        ),
      );

      await _generar(tester);

      expect(find.textContaining('No hay camiones disponibles en ese turno'),
          findsOneWidget);
      expect(find.textContaining('o completada el 2026-11-17'),
          findsOneWidget);
      expect(find.byType(ResumenGeneracionRutas), findsNothing);
    });

    testWidgets('404: ningún punto cumple los filtros', (tester) async {
      await _mostrar(
        tester,
        _RepositorioFalso(
          error: errorGeneracionDesde(
            _errorHttp(404, {
              'detail': 'No hay puntos críticos que cumplan los filtros',
            }),
          ),
        ),
      );

      await _generar(tester, prioritarios: true);

      expect(
        find.text('Ningún punto crítico cumple los filtros elegidos.'),
        findsOneWidget,
      );
    });

    testWidgets('el mapa dibuja las paradas numeradas y filtra por camión', (
      tester,
    ) async {
      final resultado = ResultadoGeneracionRutas.fromJson(_respuestaJson());
      tester.view.physicalSize = const Size(900, 1400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: PantallaMapaRutas(
            rutas: [
              for (final r in resultado.rutas) RutaEnMapa.desdeGenerada(r),
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(MarcadorParadaRuta), findsNWidgets(3));
      final colores = tester
          .widgetList<MarcadorParadaRuta>(find.byType(MarcadorParadaRuta))
          .map((m) => m.color)
          .toSet();
      expect(colores, hasLength(2), reason: 'un color por camión');

      await tester.tap(find.widgetWithText(ChoiceChip, 'T1A-222'));
      await tester.pumpAndSettle();
      expect(find.byType(MarcadorParadaRuta), findsOneWidget);

      await tester.tap(find.widgetWithText(ChoiceChip, 'Todas'));
      await tester.pumpAndSettle();
      expect(find.byType(MarcadorParadaRuta), findsNWidgets(3));
    });
  });
}
