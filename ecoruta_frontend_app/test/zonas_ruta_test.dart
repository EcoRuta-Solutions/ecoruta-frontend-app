import 'package:ecoruta_frontend_app/core/theme/app_theme.dart';
import 'package:ecoruta_frontend_app/features/municipalidad/data/modelos_zonas_ruta.dart';
import 'package:ecoruta_frontend_app/features/municipalidad/data/repositorio_zonas_ruta.dart';
import 'package:ecoruta_frontend_app/features/municipalidad/presentation/pantalla_zonas_ruta.dart';
import 'package:ecoruta_frontend_app/features/municipalidad/presentation/zonas_ruta_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Respuesta con la forma de `ZonaRutaOut` del backend (filas de prueba,
/// no datos oficiales).
Map<String, dynamic> _json({
  int id = 1,
  String codigo = 'M-1',
  String turno = 'manana',
  String? tramo = 'Tramo de prueba',
  String? sectores = 'Sector A, Sector B',
  String recojoInicio = '05:00:00',
  String recojoFin = '09:00:00',
  String? sacarInicio = '04:30:00',
  String? sacarFin = '05:00:00',
  bool cruzaMedianoche = false,
  bool revisar = false,
}) => {
  'id': id,
  'codigo': codigo,
  'turno': turno,
  'tramo': tramo,
  'sectores': sectores,
  'recojo_inicio': recojoInicio,
  'recojo_fin': recojoFin,
  'sacar_basura_inicio': sacarInicio,
  'sacar_basura_fin': sacarFin,
  'cruza_medianoche': cruzaMedianoche,
  'revisar': revisar,
};

final _manana = ZonaRuta.fromJson(_json());
final _tarde = ZonaRuta.fromJson(
  _json(
    id: 2,
    codigo: 'T-1',
    turno: 'tarde',
    tramo: 'Tramo de tarde',
    recojoInicio: '13:00:00',
    recojoFin: '17:00:00',
    sacarInicio: null,
    sacarFin: null,
    revisar: true,
  ),
);
final _noche = ZonaRuta.fromJson(
  _json(
    id: 3,
    codigo: 'N-1',
    turno: 'noche',
    tramo: 'Tramo de noche',
    recojoInicio: '21:00:00',
    recojoFin: '05:00:00',
    sacarInicio: '20:00:00',
    sacarFin: '21:00:00',
    cruzaMedianoche: true,
  ),
);

class _RepositorioFalso implements RepositorioZonasRuta {
  _RepositorioFalso(this.zonas, {this.fallosPendientes = 0});

  final List<ZonaRuta> zonas;
  int fallosPendientes;
  final pedidos = <TurnoZona?>[];

  @override
  Future<List<ZonaRuta>> listar({TurnoZona? turno}) async {
    pedidos.add(turno);
    if (fallosPendientes > 0) {
      fallosPendientes--;
      throw Exception('backend apagado');
    }
    return [
      for (final zona in zonas)
        if (turno == null || zona.turno == turno) zona,
    ];
  }

  @override
  Future<List<ZonaRuta>> tramos(String codigo) async => [
    for (final zona in zonas)
      if (zona.codigo == codigo) zona,
  ];
}

Future<_RepositorioFalso> _abrir(
  WidgetTester tester, {
  List<ZonaRuta>? zonas,
  DateTime? ahora,
  bool municipalidad = true,
  int fallos = 0,
}) async {
  tester.view.physicalSize = const Size(900, 1600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  final repositorio = _RepositorioFalso(
    zonas ?? [_manana, _tarde, _noche],
    fallosPendientes: fallos,
  );
  final hora = ahora ?? DateTime(2026, 11, 17, 8);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        repositorioZonasRutaProvider.overrideWithValue(repositorio),
        relojZonasRutaProvider.overrideWithValue(() => hora),
        resaltarZonaActivaProvider.overrideWithValue(municipalidad),
      ],
      child: MaterialApp(
        theme: AppTheme.light,
        home: const PantallaZonasRuta(),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return repositorio;
}

void main() {
  group('modelo ZonaRuta', () {
    test('parsea la respuesta de GET /zonas-ruta', () {
      expect(_manana.id, 1);
      expect(_manana.codigo, 'M-1');
      expect(_manana.turno, TurnoZona.manana);
      expect(_manana.tramo, 'Tramo de prueba');
      expect(_manana.sectores, 'Sector A, Sector B');
      expect(_manana.recojoInicio, const HoraDia(5, 0));
      expect(_manana.recojoFin, const HoraDia(9, 0));
      expect(_manana.ventanaRecojo, '05:00 – 09:00');
      expect(_manana.ventanaSacarBasura, '04:30 – 05:00');
      expect(_manana.cruzaMedianoche, isFalse);
      expect(_manana.revisar, isFalse);
    });

    test('acepta tramo, sectores y horario de sacar la basura nulos', () {
      final zona = ZonaRuta.fromJson(
        _json(tramo: null, sectores: null, sacarInicio: null, sacarFin: null),
      );
      expect(zona.tramo, isNull);
      expect(zona.sectores, isNull);
      expect(zona.sacarBasuraInicio, isNull);
      expect(zona.ventanaSacarBasura, isNull);
    });

    test('rechaza un turno desconocido', () {
      expect(
        () => ZonaRuta.fromJson(_json(turno: 'madrugada')),
        throwsFormatException,
      );
    });

    test('turno que cruza medianoche: 21:00 – 05:00', () {
      expect(_noche.ventanaRecojo, '21:00 – 05:00');
      expect(_noche.ventanaCruzaMedianoche, isTrue);
      bool a(int hora, [int minuto = 0]) =>
          _noche.recogiendoA(DateTime(2026, 11, 17, hora, minuto));
      expect(a(21), isTrue, reason: 'el inicio es inclusivo');
      expect(a(23, 30), isTrue);
      expect(a(0), isTrue);
      expect(a(4, 59), isTrue);
      expect(a(5), isFalse, reason: 'el fin es exclusivo');
      expect(a(12), isFalse);
      expect(a(20, 59), isFalse);
    });

    test('ventana normal: no se activa fuera del horario', () {
      expect(_manana.ventanaCruzaMedianoche, isFalse);
      expect(_manana.recogiendoA(DateTime(2026, 1, 1, 5)), isTrue);
      expect(_manana.recogiendoA(DateTime(2026, 1, 1, 9)), isFalse);
      expect(_manana.recogiendoA(DateTime(2026, 1, 1, 22)), isFalse);
    });

    test('fin antes del inicio cuenta como nocturna aunque el indicador '
        'venga apagado', () {
      final zona = ZonaRuta.fromJson(
        _json(recojoInicio: '22:00:00', recojoFin: '02:00:00'),
      );
      expect(zona.ventanaCruzaMedianoche, isTrue);
      expect(zona.recogiendoA(DateTime(2026, 1, 1, 1)), isTrue);
    });

    test('turno de la hora actual con los horarios de SEGAT', () {
      TurnoZona t(int hora) => TurnoZona.deHora(DateTime(2026, 1, 1, hora));
      expect(t(4), TurnoZona.noche);
      expect(t(5), TurnoZona.manana);
      expect(t(12), TurnoZona.manana);
      expect(t(13), TurnoZona.tarde);
      expect(t(21), TurnoZona.noche);
    });
  });

  group('agrupación de tramos', () {
    test('una ruta por código con todos sus tramos, en el orden recibido', () {
      final filas = [
        ZonaRuta.fromJson(_json(id: 1, codigo: 'M-1', tramo: 'Tramo A')),
        ZonaRuta.fromJson(
          _json(id: 2, codigo: 'M-1', tramo: 'Tramo B', revisar: true),
        ),
        ZonaRuta.fromJson(_json(id: 3, codigo: 'M-2', tramo: 'Tramo A')),
      ];

      final rutas = agruparPorCodigo(filas);

      expect(rutas.map((r) => r.codigo), ['M-1', 'M-2']);
      expect(rutas.first.tramos.map((t) => t.tramo), ['Tramo A', 'Tramo B']);
      expect(rutas.first.revisar, isTrue);
      expect(rutas.last.tramos, hasLength(1));
      expect(rutas.last.revisar, isFalse);
      expect(agruparPorCodigo(const []), isEmpty);
    });

    test('la ruta está activa si algún tramo lo está', () {
      final ruta = agruparPorCodigo([
        ZonaRuta.fromJson(_json(id: 1, codigo: 'N-1', turno: 'noche',
            recojoInicio: '21:00:00', recojoFin: '23:00:00')),
        ZonaRuta.fromJson(_json(id: 2, codigo: 'N-1', turno: 'noche',
            recojoInicio: '23:00:00', recojoFin: '03:00:00',
            cruzaMedianoche: true)),
      ]).single;
      expect(ruta.recogiendoA(DateTime(2026, 11, 18, 1)), isTrue);
      expect(ruta.recogiendoA(DateTime(2026, 11, 18, 12)), isFalse);
    });
  });

  group('pantalla Rutas por zona', () {
    testWidgets('cada ruta aparece una vez con sus tramos y su "Por verificar"', (
      tester,
    ) async {
      await _abrir(
        tester,
        zonas: [
          ZonaRuta.fromJson(_json(
            id: 1,
            codigo: 'M-1',
            tramo: 'Tramo A',
            sectores: 'Sector 1',
          )),
          ZonaRuta.fromJson(_json(
            id: 2,
            codigo: 'M-1',
            tramo: 'Tramo B',
            sectores: 'Sector 2',
            recojoInicio: '09:00:00',
            recojoFin: '11:00:00',
            revisar: true,
          )),
          ZonaRuta.fromJson(_json(id: 3, codigo: 'M-2', tramo: 'Tramo único')),
        ],
      );

      expect(find.byType(TarjetaZonaRuta), findsNWidgets(2));
      expect(find.text('M-1'), findsOneWidget);
      expect(find.text('2 tramos'), findsOneWidget);
      expect(find.text('1 tramo'), findsOneWidget);

      final m1 = find.ancestor(
        of: find.text('M-1'),
        matching: find.byType(TarjetaZonaRuta),
      );
      Finder enM1(String texto) =>
          find.descendant(of: m1, matching: find.text(texto));
      expect(enM1('Tramo A'), findsOneWidget);
      expect(enM1('Tramo B'), findsOneWidget);
      expect(enM1('Sector 1'), findsOneWidget);
      expect(enM1('Sector 2'), findsOneWidget);
      expect(enM1('05:00 – 09:00'), findsOneWidget);
      expect(enM1('09:00 – 11:00'), findsOneWidget);
      // Solo el tramo B está por verificar.
      expect(find.text('Por verificar'), findsOneWidget);
      final tramoB = find.ancestor(
        of: find.text('Tramo B'),
        matching: find.byType(Wrap),
      ).first;
      expect(
        find.descendant(of: tramoB, matching: find.text('Por verificar')),
        findsOneWidget,
      );
    });

    testWidgets('muestra los datos de la tarjeta', (tester) async {
      final repositorio = await _abrir(tester);

      expect(repositorio.pedidos, [TurnoZona.manana]);
      expect(find.text('M-1'), findsOneWidget);
      expect(find.text('Tramo de prueba'), findsOneWidget);
      expect(find.text('Sector A, Sector B'), findsOneWidget);
      expect(find.text('05:00 – 09:00'), findsOneWidget);
      expect(find.text('04:30 – 05:00'), findsOneWidget);
      expect(find.text('Cruza medianoche'), findsNothing);
      expect(find.text('Por verificar'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('cambio de pestaña: carga y muestra las zonas de la tarde', (
      tester,
    ) async {
      final repositorio = await _abrir(tester);

      await tester.tap(find.widgetWithText(Tab, 'Tarde'));
      await tester.pumpAndSettle();

      expect(repositorio.pedidos, [TurnoZona.manana, TurnoZona.tarde]);
      expect(find.text('T-1'), findsOneWidget);
      expect(find.text('13:00 – 17:00'), findsOneWidget);
      expect(find.text('Sin horario registrado'), findsOneWidget);
      expect(find.text('M-1'), findsNothing);
    });

    testWidgets('turno que cruza medianoche: indicador y zona activa', (
      tester,
    ) async {
      // A las 23:30 abre en la pestaña Noche.
      await _abrir(tester, ahora: DateTime(2026, 11, 17, 23, 30));

      expect(find.text('N-1'), findsOneWidget);
      expect(find.text('21:00 – 05:00'), findsOneWidget);
      expect(find.text('Cruza medianoche'), findsOneWidget);
      expect(find.text('Recojo en curso'), findsOneWidget);
    });

    testWidgets('zona activa de madrugada (03:00) en un turno nocturno', (
      tester,
    ) async {
      await _abrir(tester, ahora: DateTime(2026, 11, 18, 3));

      expect(find.text('N-1'), findsOneWidget);
      expect(find.text('Recojo en curso'), findsOneWidget);
    });

    testWidgets('fuera de la ventana no se resalta ninguna zona', (
      tester,
    ) async {
      await _abrir(tester, ahora: DateTime(2026, 11, 17, 11));

      expect(find.text('M-1'), findsOneWidget);
      expect(find.text('Recojo en curso'), findsNothing);
    });

    testWidgets('sin rol municipalidad no se resalta la zona activa', (
      tester,
    ) async {
      await _abrir(tester, municipalidad: false);

      expect(find.text('M-1'), findsOneWidget);
      expect(find.text('Recojo en curso'), findsNothing);
    });

    testWidgets('"Por verificar" solo si revisar=true, con su explicación', (
      tester,
    ) async {
      await _abrir(tester, ahora: DateTime(2026, 11, 17, 14));

      expect(find.text('T-1'), findsOneWidget);
      expect(find.text('Por verificar'), findsOneWidget);
      final tooltip = tester.widget<Tooltip>(
        find.ancestor(
          of: find.text('Por verificar'),
          matching: find.byType(Tooltip),
        ),
      );
      expect(
        tooltip.message,
        'Dato transcrito de la hoja de la municipalidad, '
        'pendiente de confirmación',
      );

      await tester.tap(find.text('Por verificar'));
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.text(mensajePorVerificar), findsOneWidget);
      await tester.pumpAndSettle(const Duration(seconds: 2));
    });

    testWidgets('vacío: mensaje del listado oficial y sin datos inventados', (
      tester,
    ) async {
      await _abrir(tester, zonas: const []);

      expect(
        find.text(
          'Aún no hay rutas cargadas. Se importan desde el listado oficial '
          'de SEGAT.',
        ),
        findsOneWidget,
      );
      expect(find.byType(TarjetaZonaRuta), findsNothing);
    });

    testWidgets('error: muestra reintentar y vuelve a cargar', (tester) async {
      final repositorio = await _abrir(tester, fallos: 1);

      expect(find.text('No se pudo cargar la información'), findsOneWidget);
      expect(find.text('M-1'), findsNothing);

      await tester.tap(find.text('Reintentar'));
      await tester.pumpAndSettle();

      expect(repositorio.pedidos, [TurnoZona.manana, TurnoZona.manana]);
      expect(find.text('M-1'), findsOneWidget);
    });
  });
}
