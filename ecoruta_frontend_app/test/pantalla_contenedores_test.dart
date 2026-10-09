import 'package:ecoruta_frontend_app/core/theme/app_theme.dart';
import 'package:ecoruta_frontend_app/features/municipalidad/presentation/pantalla_contenedores.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('crea un contenedor con código siguiente y ubicación elegida', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(900, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: AppTheme.light,
          home: const Scaffold(body: PantallaContenedores()),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Agregar'));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Nombre'),
      'Parque Unión',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Tipo de residuo'),
      'Residuos orgánicos',
    );
    await tester.tap(find.text('Crear contenedor'));
    await tester.pumpAndSettle();
    expect(find.textContaining('TRU-009'), findsOneWidget);
    expect(find.text('Parque Unión'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('muestra validación inline cuando el nombre está vacío', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(900, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: AppTheme.light,
          home: const FormularioContenedor(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Crear contenedor'));
    await tester.pumpAndSettle();
    expect(find.text('Ingresa el nombre.'), findsOneWidget);
  });
}
