import 'package:ecoruta_frontend_app/core/theme/app_theme.dart';
import 'package:ecoruta_frontend_app/features/municipalidad/data/modelos_flota.dart';
import 'package:ecoruta_frontend_app/features/municipalidad/data/modelos_puntos_criticos.dart';
import 'package:ecoruta_frontend_app/features/municipalidad/data/repositorio_puntos_criticos.dart';
import 'package:ecoruta_frontend_app/features/municipalidad/data/repositorio_resumen_flota.dart';
import 'package:ecoruta_frontend_app/features/municipalidad/presentation/widgets/resumen_operativo.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _RepositorioPuntosFalso implements RepositorioPuntosCriticos {
  _RepositorioPuntosFalso(this._resumen);

  final ResumenPuntosCriticos _resumen;

  @override
  Future<List<PuntoCritico>> listarTodos() async => const [];

  @override
  Future<ResumenPuntosCriticos> resumen() async => _resumen;

  @override
  Future<PuntoCritico?> obtener(String codigo) async => null;
}

class _RepositorioFlotaFalso implements RepositorioResumenFlota {
  _RepositorioFlotaFalso({this.fallar = false});

  bool fallar;

  @override
  Future<ResumenFlota> cargar() async {
    if (fallar) throw StateError('sin conexión');
    return const ResumenFlota(
      total: 12,
      porEstado: ConteoEstadosFlota(
        operativo: 8,
        reserva: 3,
        mantenimiento: 1,
        total: 12,
      ),
      porTurno: {
        TurnoFlota.manana: ConteoEstadosFlota(operativo: 4),
        TurnoFlota.tarde: ConteoEstadosFlota(operativo: 3),
        TurnoFlota.noche: ConteoEstadosFlota(operativo: 1),
      },
      demo: 2,
      datosProvisionales: 5,
    );
  }
}

const _resumenPuntos = ResumenPuntosCriticos(
  total: 151,
  potenciales: 120,
  recuperados: 31,
  prioritarios: 40,
  noPrioritarios: 111,
);

Future<void> _mostrar(
  WidgetTester tester, {
  required RepositorioPuntosCriticos puntos,
  required RepositorioResumenFlota flota,
}) async {
  tester.view.physicalSize = const Size(900, 2000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        repositorioPuntosCriticosProvider.overrideWithValue(puntos),
        repositorioResumenFlotaProvider.overrideWithValue(flota),
      ],
      child: MaterialApp(
        theme: AppTheme.light,
        home: const Scaffold(
          body: SingleChildScrollView(
            child: Column(children: [BloquePuntosCriticos(), BloqueFlota()]),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

String _valorDe(WidgetTester tester, String etiqueta) {
  final tarjeta = find.ancestor(
    of: find.text(etiqueta),
    matching: find.byType(Card),
  );
  final textos = tester
      .widgetList<Text>(
        find.descendant(of: tarjeta, matching: find.byType(Text)),
      )
      .map((texto) => texto.data)
      .whereType<String>()
      .where((texto) => texto != etiqueta);
  return textos.first;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('muestra los totales reales de puntos críticos y de flota', (
    tester,
  ) async {
    await _mostrar(
      tester,
      puntos: _RepositorioPuntosFalso(_resumenPuntos),
      flota: _RepositorioFlotaFalso(),
    );

    expect(_valorDe(tester, 'Total'), '151');
    expect(_valorDe(tester, 'Prioritarios'), '40');
    expect(_valorDe(tester, 'Potenciales'), '120');
    expect(_valorDe(tester, 'Recuperados'), '31');

    expect(_valorDe(tester, 'Mañana'), '4');
    expect(_valorDe(tester, 'Tarde'), '3');
    expect(_valorDe(tester, 'Noche'), '1');
    expect(_valorDe(tester, 'En reserva'), '3');
    expect(
      find.text('Incluye 2 camiones demo · 5 con datos provisionales'),
      findsOneWidget,
    );
  });

  testWidgets('un error de flota permite reintentar sin afectar puntos', (
    tester,
  ) async {
    final flota = _RepositorioFlotaFalso(fallar: true);
    await _mostrar(
      tester,
      puntos: _RepositorioPuntosFalso(_resumenPuntos),
      flota: flota,
    );

    expect(_valorDe(tester, 'Total'), '151');
    expect(find.text('Reintentar'), findsOneWidget);

    flota.fallar = false;
    await tester.tap(find.text('Reintentar'));
    await tester.pumpAndSettle();

    expect(find.text('Reintentar'), findsNothing);
    expect(_valorDe(tester, 'En reserva'), '3');
  });

  testWidgets('sin puntos críticos muestra el estado vacío', (tester) async {
    await _mostrar(
      tester,
      puntos: _RepositorioPuntosFalso(
        const ResumenPuntosCriticos(
          total: 0,
          potenciales: 0,
          recuperados: 0,
          prioritarios: 0,
          noPrioritarios: 0,
        ),
      ),
      flota: _RepositorioFlotaFalso(),
    );

    expect(find.text('No hay puntos críticos registrados'), findsOneWidget);
  });
}
