import 'package:ecoruta_frontend_app/core/config/mostrar_demo.dart';
import 'package:ecoruta_frontend_app/core/theme/app_theme.dart';
import 'package:ecoruta_frontend_app/features/municipalidad/presentation/navegacion_controller.dart';
import 'package:ecoruta_frontend_app/features/municipalidad/presentation/pantalla_contenedores.dart';
import 'package:ecoruta_frontend_app/features/municipalidad/presentation/pantalla_mas.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

Future<ProviderContainer> _mostrar(
  WidgetTester tester, {
  required bool mostrarDemo,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [mostrarDemoProvider.overrideWithValue(mostrarDemo)],
      child: MaterialApp(
        theme: AppTheme.light,
        home: const Scaffold(body: PantallaMas()),
      ),
    ),
  );
  await tester.pump();
  return ProviderScope.containerOf(tester.element(find.byType(PantallaMas)));
}

void main() {
  testWidgets('sin MOSTRAR_DEMO, Más no ofrece Contenedores', (tester) async {
    final contenedor = await _mostrar(tester, mostrarDemo: false);

    expect(find.text('Contenedores'), findsNothing);
    expect(find.text('Usuarios y flota'), findsOneWidget);
    expect(find.text('Informes'), findsOneWidget);

    // Aunque algo intente abrirla, la pantalla simulada no se muestra.
    contenedor
        .read(navegacionMunicipalidadProvider.notifier)
        .abrirOpcion(OpcionMasMunicipalidad.contenedores);
    await tester.pump();
    expect(find.byType(PantallaContenedores), findsNothing);
    expect(find.text('Más herramientas'), findsOneWidget);
  });

  testWidgets('con datos de ejemplo o MOSTRAR_DEMO, Contenedores aparece', (
    tester,
  ) async {
    await _mostrar(tester, mostrarDemo: true);

    expect(find.text('Contenedores'), findsOneWidget);
    expect(find.text('Usuarios y flota'), findsOneWidget);
    expect(find.text('Informes'), findsOneWidget);
  });
}
