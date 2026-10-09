import 'package:ecoruta_frontend_app/core/theme/app_theme.dart';
import 'package:ecoruta_frontend_app/features/municipalidad/data/modelos_informe.dart';
import 'package:ecoruta_frontend_app/features/municipalidad/data/panel_mock.dart';
import 'package:ecoruta_frontend_app/features/municipalidad/data/repositorios_mock.dart';
import 'package:ecoruta_frontend_app/features/municipalidad/presentation/pantalla_reportes.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

class _RepositorioPanelFalso implements RepositorioPanel {
  @override
  Future<DatosPanel> cargar() async => crearDatosPanelMock();
}

class _RepositorioInformesFalso implements RepositorioInformes {
  DateTime? ultimoInicio;
  DateTime? ultimoFin;

  @override
  Future<DatosInforme> cargar(DateTime inicio, DateTime fin) async {
    ultimoInicio = inicio;
    ultimoFin = fin;
    return RepositorioInformesMock().cargar(inicio, fin);
  }
}

void main() {
  setUpAll(() => initializeDateFormatting('es'));

  testWidgets('cambia el rango y abre las opciones de exportación', (
    tester,
  ) async {
    tester.view
      ..physicalSize = const Size(1200, 3000)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final informes = _RepositorioInformesFalso();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          repositorioPanelProvider.overrideWithValue(_RepositorioPanelFalso()),
          repositorioInformesProvider.overrideWithValue(informes),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          home: const Scaffold(body: PantallaReportes()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Reducción de km'), findsOneWidget);
    await tester.tap(find.widgetWithText(ChoiceChip, '30 días'));
    await tester.pumpAndSettle();
    expect(informes.ultimoInicio, isNotNull);
    expect(informes.ultimoFin, isNotNull);
    expect(
      informes.ultimoFin!.difference(informes.ultimoInicio!).inDays,
      greaterThanOrEqualTo(29),
    );

    await tester.tap(find.text('Exportar').first);
    await tester.pumpAndSettle();
    expect(find.text('Exportar CSV'), findsOneWidget);
    expect(find.text('Exportar PDF'), findsOneWidget);
  });
}
