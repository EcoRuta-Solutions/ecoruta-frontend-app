import 'package:ecoruta_frontend_app/core/theme/app_theme.dart';
import 'package:ecoruta_frontend_app/features/municipalidad/data/modelos_lectura_nodo.dart';
import 'package:ecoruta_frontend_app/features/municipalidad/data/modelos_panel.dart';
import 'package:ecoruta_frontend_app/features/municipalidad/data/repositorios_mock.dart';
import 'package:ecoruta_frontend_app/features/municipalidad/presentation/pantalla_detalle_contenedor.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _RepositorioContenedoresFalso implements RepositorioContenedores {
  final NodoEstado nodo = NodoEstado(
    id: 42,
    codigo: 'TRU-042',
    nombre: 'Plaza de prueba',
    latitud: null,
    longitud: null,
    umbralCritico: 80,
    llenado: 72,
    volteado: false,
    ultimaLectura: DateTime(2026, 10, 8, 11, 30),
    estado: EstadoNodo.alerta,
    bateria: 80,
    senal: 3,
  );

  @override
  Future<List<NodoEstado>> listar() async => [nodo];

  @override
  Future<NodoEstado?> obtener(int id) async => id == nodo.id ? nodo : null;

  @override
  Future<DetalleNodo?> obtenerDetalle(int id, {required int dias}) async {
    if (id != nodo.id) return null;
    final lecturas = [
      for (var indice = 0; indice < (dias == 1 ? 9 : 7); indice++)
        LecturaLlenado(
          fecha: DateTime(2026, 10, 8).subtract(Duration(days: indice)),
          porcentaje: 40 + indice.toDouble(),
        ),
    ];
    return DetalleNodo(
      nodo: nodo,
      lecturas: lecturas,
      eventos: const [],
      prediccion: PrediccionLlenado(
        horaEstimadaDesborde: DateTime(2026, 10, 8, 17),
        confianza: 0.82,
      ),
    );
  }

  @override
  Future<void> guardar(NodoEstado nodo) async {}

  @override
  Future<void> eliminar(int id) async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('muestra detalle y permite cambiar el rango del historial', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          repositorioContenedoresProvider.overrideWithValue(
            _RepositorioContenedoresFalso(),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          home: const PantallaDetalleContenedor(nodoId: 42),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Plaza de prueba'), findsOneWidget);
    expect(find.text('TRU-042'), findsOneWidget);
    expect(find.text('Historial de llenado'), findsOneWidget);

    await tester.tap(find.text('7 días'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
