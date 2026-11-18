import 'package:ecoruta_frontend_app/core/config/app_config.dart';
import 'package:ecoruta_frontend_app/core/config/mostrar_demo.dart';
import 'package:ecoruta_frontend_app/core/theme/app_theme.dart';
import 'package:ecoruta_frontend_app/features/municipalidad/data/panel_mock.dart';
import 'package:ecoruta_frontend_app/features/municipalidad/data/repositorios_mock.dart';
import 'package:ecoruta_frontend_app/features/municipalidad/presentation/mapa_puntos_criticos.dart';
import 'package:ecoruta_frontend_app/features/municipalidad/presentation/pantalla_mapa.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _RepositorioPanelFalso implements RepositorioPanel {
  @override
  Future<DatosPanel> cargar() async => crearDatosPanelMock();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('los filtros de estado actualizan el conteo de nodos del mapa', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(900, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          repositorioPanelProvider.overrideWithValue(_RepositorioPanelFalso()),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          home: const Scaffold(body: PantallaMapa()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // El mapa abre en la capa de puntos críticos; los nodos están en la capa
    // de contenedores (demo).
    await tester.tap(find.text('Contenedores · demo'));
    await tester.pumpAndSettle();

    expect(find.text('8 contenedores'), findsOneWidget);
    await tester.tap(find.byTooltip('Mostrar filtros'));
    await tester.pumpAndSettle();
    for (final estado in ['En alerta', 'Normal', 'Sin datos']) {
      final chip = find.widgetWithText(FilterChip, estado);
      await tester.ensureVisible(chip);
      await tester.tap(chip);
      await tester.pumpAndSettle();
    }
    await tester.pumpAndSettle();
    expect(find.text('2 contenedores'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('sin MOSTRAR_DEMO la capa "Contenedores · demo" no aparece', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(900, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          repositorioPanelProvider.overrideWithValue(_RepositorioPanelFalso()),
          mostrarDemoProvider.overrideWithValue(false),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          home: const Scaffold(body: PantallaMapa()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Contenedores · demo'), findsNothing);
    expect(find.byType(SegmentedButton<CapaMapa>), findsNothing);
    expect(find.byType(MapaPuntosCriticos), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  test('con USE_MOCK=true la capa demo se muestra por defecto', () {
    // Los tests corren con USE_MOCK por defecto (true).
    expect(AppConfig.usarDatosDeEjemplo, isTrue);
    expect(AppConfig.mostrarDemo, isTrue);
    final contenedor = ProviderContainer();
    addTearDown(contenedor.dispose);
    expect(contenedor.read(mostrarDemoProvider), isTrue);
  });
}
