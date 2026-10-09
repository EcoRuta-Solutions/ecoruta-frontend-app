import 'package:ecoruta_frontend_app/core/theme/app_theme.dart';
import 'package:ecoruta_frontend_app/features/municipalidad/presentation/pantalla_rutas.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('la lista abre el detalle y permite aprobar una ruta propuesta', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(900, 1500);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: AppTheme.light,
          home: const Scaffold(body: PantallaRutas()),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Centro mañana'));
    await tester.pumpAndSettle();

    expect(find.text('Ruta optimizada vs. ruta fija'), findsOneWidget);
    expect(find.text('Aprobar ruta'), findsOneWidget);
    await tester.tap(find.text('Aprobar ruta'));
    await tester.pump(const Duration(milliseconds: 450));
    await tester.pumpAndSettle();
    expect(find.text('Aprobada'), findsWidgets);
    expect(find.text('Ruta aprobada.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
