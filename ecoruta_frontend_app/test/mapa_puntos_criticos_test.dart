import 'package:ecoruta_frontend_app/core/theme/app_theme.dart';
import 'package:ecoruta_frontend_app/features/municipalidad/data/modelos_puntos_criticos.dart';
import 'package:ecoruta_frontend_app/features/municipalidad/data/repositorio_puntos_criticos.dart';
import 'package:ecoruta_frontend_app/features/municipalidad/presentation/mapa_puntos_criticos.dart';
import 'package:ecoruta_frontend_app/features/municipalidad/presentation/pantalla_mapa.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _RepositorioPuntosFalso implements RepositorioPuntosCriticos {
  _RepositorioPuntosFalso(this.puntos, {this.fallar = false});

  final List<PuntoCritico> puntos;
  bool fallar;

  @override
  Future<List<PuntoCritico>> listarTodos() async {
    if (fallar) throw StateError('sin conexión');
    return puntos;
  }

  @override
  Future<ResumenPuntosCriticos> resumen() async =>
      ResumenPuntosCriticos.desdePuntos(puntos);

  @override
  Future<PuntoCritico?> obtener(String codigo) async => null;
}

PuntoCritico _punto(
  String codigo, {
  EstadoPuntoCritico estado = EstadoPuntoCritico.potencial,
  bool prioritario = false,
  String? referencia,
  double latitud = -8.11,
  double longitud = -79.03,
}) => PuntoCritico(
  codigo: codigo,
  estado: estado,
  priorizacionObligatoria: prioritario,
  direccion: 'Dirección $codigo',
  referencia: referencia,
  latitud: latitud,
  longitud: longitud,
);

/// 2 prioritarios potenciales, 1 recuperado que fue prioritario,
/// 2 potenciales y 1 recuperado; uno más sin coordenadas.
final _puntos = [
  _punto('P1', prioritario: true, latitud: -8.10),
  _punto('P2', prioritario: true, latitud: -8.12),
  _punto(
    'R1',
    estado: EstadoPuntoCritico.recuperado,
    prioritario: true,
    longitud: -79.05,
  ),
  _punto('N1', longitud: -79.01),
  _punto('N2', latitud: -8.13, longitud: -79.02),
  _punto('R2', estado: EstadoPuntoCritico.recuperado, latitud: -8.09),
  const PuntoCritico(
    codigo: 'SIN-COORD',
    estado: EstadoPuntoCritico.potencial,
    priorizacionObligatoria: false,
    direccion: 'Sin coordenadas',
  ),
];

Future<void> _mostrarMapa(
  WidgetTester tester,
  RepositorioPuntosCriticos repositorio,
) async {
  tester.view.physicalSize = const Size(900, 1000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        repositorioPuntosCriticosProvider.overrideWithValue(repositorio),
      ],
      child: MaterialApp(
        theme: AppTheme.light,
        home: const Scaffold(body: PantallaMapa()),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('filtrarPuntosCriticos', () {
    test('cada filtro devuelve los puntos correspondientes', () {
      String codigos(FiltroPuntosCriticos filtro) => filtrarPuntosCriticos(
        _puntos,
        filtro,
      ).map((punto) => punto.codigo).join(',');

      expect(
        codigos(FiltroPuntosCriticos.todos),
        'P1,P2,R1,N1,N2,R2,SIN-COORD',
      );
      expect(codigos(FiltroPuntosCriticos.prioritarios), 'P1,P2,R1');
      expect(
        codigos(FiltroPuntosCriticos.potenciales),
        'P1,P2,N1,N2,SIN-COORD',
      );
      expect(codigos(FiltroPuntosCriticos.recuperados), 'R1,R2');
    });
  });

  testWidgets('los chips filtran los marcadores y actualizan el conteo', (
    tester,
  ) async {
    await _mostrarMapa(tester, _RepositorioPuntosFalso(_puntos));

    // El punto sin coordenadas no se dibuja.
    expect(find.text('6 puntos críticos'), findsOneWidget);
    expect(find.byType(MarcadorPuntoCritico), findsNWidgets(6));

    const esperados = {
      'Prioritarios': 3,
      'Potenciales': 4,
      'Recuperados': 2,
      'Todos': 6,
    };
    for (final filtro in esperados.entries) {
      await tester.tap(find.widgetWithText(ChoiceChip, filtro.key));
      await tester.pumpAndSettle();
      expect(
        find.byType(MarcadorPuntoCritico),
        findsNWidgets(filtro.value),
        reason: 'El filtro ${filtro.key} debe mostrar ${filtro.value} puntos',
      );
      expect(find.text('${filtro.value} puntos críticos'), findsOneWidget);
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('la leyenda muestra las tres categorías', (tester) async {
    await _mostrarMapa(tester, _RepositorioPuntosFalso(_puntos));

    for (final etiqueta in ['Prioritario', 'Potencial', 'Recuperado']) {
      expect(find.text(etiqueta), findsOneWidget);
    }
  });

  testWidgets('tocar un marcador abre la hoja con datos y "Cómo llegar"', (
    tester,
  ) async {
    await _mostrarMapa(
      tester,
      _RepositorioPuntosFalso([
        _punto('PC-042', prioritario: true, referencia: 'Frente al parque'),
      ]),
    );

    await tester.tap(find.byType(MarcadorPuntoCritico));
    await tester.pumpAndSettle();

    expect(find.text('Punto crítico PC-042'), findsOneWidget);
    expect(find.text('Dirección PC-042'), findsOneWidget);
    expect(find.text('Frente al parque'), findsOneWidget);
    expect(find.text('Potencial'), findsWidgets);
    expect(find.text('Priorización obligatoria'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Cómo llegar'), findsOneWidget);
  });

  testWidgets('sin referencia la hoja lo indica', (tester) async {
    await _mostrarMapa(tester, _RepositorioPuntosFalso([_punto('PC-1')]));

    await tester.tap(find.byType(MarcadorPuntoCritico));
    await tester.pumpAndSettle();

    expect(find.text('Sin referencia'), findsOneWidget);
    expect(find.text('Priorización obligatoria'), findsNothing);
  });

  testWidgets('un error muestra Reintentar y al reintentar carga', (
    tester,
  ) async {
    final repositorio = _RepositorioPuntosFalso(_puntos, fallar: true);
    await _mostrarMapa(tester, repositorio);

    expect(find.text('No se pudo cargar la información'), findsOneWidget);

    repositorio.fallar = false;
    await tester.tap(find.text('Reintentar'));
    await tester.pumpAndSettle();

    expect(find.text('6 puntos críticos'), findsOneWidget);
  });

  testWidgets('sin puntos muestra el estado vacío', (tester) async {
    await _mostrarMapa(tester, _RepositorioPuntosFalso(const []));

    expect(find.text('No hay puntos críticos registrados'), findsOneWidget);
    expect(find.byType(ChoiceChip), findsNothing);
  });

  testWidgets('un filtro sin resultados lo indica', (tester) async {
    await _mostrarMapa(tester, _RepositorioPuntosFalso([_punto('PC-1')]));

    await tester.tap(find.widgetWithText(ChoiceChip, 'Recuperados'));
    await tester.pumpAndSettle();

    expect(find.text('No hay puntos críticos en este filtro'), findsOneWidget);
  });
}
