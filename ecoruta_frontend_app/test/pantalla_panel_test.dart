import 'package:ecoruta_frontend_app/core/theme/app_theme.dart';
import 'package:ecoruta_frontend_app/features/municipalidad/data/modelos_panel.dart';
import 'package:ecoruta_frontend_app/features/municipalidad/data/panel_mock.dart';
import 'package:ecoruta_frontend_app/features/municipalidad/data/repositorios_mock.dart';
import 'package:ecoruta_frontend_app/features/municipalidad/presentation/pantalla_panel.dart';
import 'package:ecoruta_frontend_app/features/municipalidad/presentation/widgets/tarjeta_contenedor.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _RepositorioPanelFalso implements RepositorioPanel {
  _RepositorioPanelFalso(this.datos);

  final DatosPanel datos;

  @override
  Future<DatosPanel> cargar() async => datos;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('cada filtro muestra la cantidad de nodos correspondiente', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1000, 4000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await _mostrarPanel(tester, crearDatosPanelMock());

    const filtros = {
      'Todos': 8,
      'Críticos': 2,
      'Alertas': 2,
      'Normales': 3,
      'Sin datos': 1,
    };

    for (final filtro in filtros.entries) {
      await tester.tap(find.widgetWithText(ChoiceChip, filtro.key));
      await tester.pumpAndSettle();
      expect(
        find.byType(TarjetaContenedor).evaluate().length,
        filtro.value,
        reason: 'El filtro ${filtro.key} debe mostrar ${filtro.value} nodos',
      );
    }
  });

  testWidgets('el estado vacío se conserva cuando no hay nodos', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1000, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await _mostrarPanel(
      tester,
      const DatosPanel(
        nodos: [],
        resumen: ResumenPanel(
          totalNodos: 0,
          criticos: 0,
          alertas: 0,
          normales: 0,
          sinDatos: 0,
          promedioLlenado: null,
        ),
      ),
    );

    expect(find.text('No hay contenedores en este filtro'), findsOneWidget);
  });
}

Future<void> _mostrarPanel(WidgetTester tester, DatosPanel datos) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        repositorioPanelProvider.overrideWithValue(
          _RepositorioPanelFalso(datos),
        ),
      ],
      child: MaterialApp(
        theme: AppTheme.light,
        home: const Scaffold(body: PantallaPanel()),
      ),
    ),
  );
  await tester.pumpAndSettle();
}
