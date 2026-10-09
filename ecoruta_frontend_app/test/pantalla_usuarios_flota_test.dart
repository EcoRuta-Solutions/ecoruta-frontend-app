import 'package:ecoruta_frontend_app/core/theme/app_theme.dart';
import 'package:ecoruta_frontend_app/features/municipalidad/presentation/controladores_dominio.dart';
import 'package:ecoruta_frontend_app/features/municipalidad/presentation/pantalla_usuarios_flota.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

const _flotaVacia = DatosFlota(conductores: [], vehiculos: [], usuarios: []);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('valida el correo antes de guardar un usuario', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: AppTheme.light,
          home: const FormularioFlota(
            tipo: TipoRegistroFlota.usuario,
            datos: _flotaVacia,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Nombre'),
      'Operador de prueba',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Correo'),
      'correo-invalido',
    );
    await tester.tap(find.text('Guardar'));
    await tester.pumpAndSettle();
    expect(find.text('Ingresa un correo válido.'), findsOneWidget);
  });

  testWidgets('valida el formato de placa de un vehículo', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: AppTheme.light,
          home: const FormularioFlota(
            tipo: TipoRegistroFlota.vehiculo,
            datos: _flotaVacia,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Placa'),
      'ABC12',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Tipo'),
      'Compactador',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Capacidad (toneladas)'),
      '8',
    );
    await tester.tap(find.text('Guardar'));
    await tester.pumpAndSettle();
    expect(find.text('Usa el formato ABC-123.'), findsOneWidget);
  });
}
