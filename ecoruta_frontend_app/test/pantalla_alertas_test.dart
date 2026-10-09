import 'package:ecoruta_frontend_app/core/theme/app_theme.dart';
import 'package:ecoruta_frontend_app/features/municipalidad/data/panel_mock.dart';
import 'package:ecoruta_frontend_app/features/municipalidad/data/repositorios_mock.dart';
import 'package:ecoruta_frontend_app/features/municipalidad/presentation/pantalla_alertas.dart';
import 'package:ecoruta_frontend_app/features/municipalidad/presentation/widgets/tarjeta_alerta.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _RepositorioPanelFalso implements RepositorioPanel {
  @override
  Future<DatosPanel> cargar() async => crearDatosPanelMock();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('reconoce una alerta y actualiza su estado en la ficha', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(900, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          repositorioPanelProvider.overrideWithValue(_RepositorioPanelFalso()),
          repositorioAlertasProvider.overrideWithValue(
            RepositorioAlertasMock(),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          home: const Scaffold(body: PantallaAlertas()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(TarjetaAlerta), findsWidgets);
    await tester.tap(find.byType(TarjetaAlerta).first);
    await tester.pumpAndSettle();
    expect(find.text('Reconocer'), findsOneWidget);

    await tester.tap(find.text('Reconocer'));
    await tester.pump(const Duration(milliseconds: 450));
    await tester.pumpAndSettle();
    expect(find.text('Reconocida'), findsWidgets);
    expect(find.text('Alerta reconocida.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
