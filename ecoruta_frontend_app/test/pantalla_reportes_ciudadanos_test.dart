import 'package:ecoruta_frontend_app/core/theme/app_theme.dart';
import 'package:ecoruta_frontend_app/features/municipalidad/presentation/pantalla_reportes_ciudadanos.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('asigna un reporte a un responsable desde su detalle', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(900, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: AppTheme.light,
          home: const Scaffold(body: PantallaReportesCiudadanos()),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('El contenedor está lleno desde esta mañana.'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Pasar a En atención'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Luis Rodríguez').first);
    await tester.pump(const Duration(milliseconds: 450));
    await tester.pumpAndSettle();

    expect(find.text('En atención'), findsWidgets);
    expect(find.text('Reporte asignado a Luis Rodríguez.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
