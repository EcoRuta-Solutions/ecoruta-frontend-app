import 'dart:convert';

import 'package:ecoruta_frontend_app/features/municipalidad/data/exportador_informes.dart';
import 'package:ecoruta_frontend_app/features/municipalidad/data/modelos_informe.dart';
import 'package:ecoruta_frontend_app/features/municipalidad/data/panel_mock.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() => initializeDateFormatting('es'));

  final inicio = DateTime(2026, 10, 1);
  final fin = DateTime(2026, 10, 8);
  final informe = DatosInforme(
    inicio: inicio,
    fin: fin,
    kpis: const [
      KpiInforme(
        clave: 'ahorro_km',
        nombre: 'Reducción de km ≥15% — análisis',
        valor: 16.4,
        meta: 15,
        unidad: '%',
        mayorEsMejor: true,
      ),
      KpiInforme(
        clave: 'mae',
        nombre: 'Error de predicción MAE',
        valor: 4.2,
        meta: 4,
        unidad: 'h',
        mayorEsMejor: false,
      ),
    ],
    llenadoPromedio: [],
    desbordesPorZona: {},
    kilometrosOptimizados: [],
    kilometrosFijos: [],
  );

  test('genera CSV UTF-8 con KPIs, nodos y caracteres en español', () {
    final csv = generarCsvInforme(informe, crearDatosPanelMock().nodos);
    final bytes = utf8.encode(csv);

    expect(csv.startsWith('\uFEFF'), isTrue);
    expect(bytes.take(3), equals([0xEF, 0xBB, 0xBF]));
    expect(utf8.decode(bytes), contains('Reducción de km ≥15% — análisis'));
    expect(csv, contains('TRU-001'));
    expect(csv, contains('Sin datos'));
    expect(csv, contains(';'));
  });

  test('genera PDF con fuente Unicode para KPIs y zonas', () async {
    final nodos = crearDatosPanelMock().nodos
        .map(
          (nodo) => nodo.copiar(nombre: 'Víctor Larco', zona: 'Víctor Larco'),
        )
        .toList();
    final bytes = await generarPdfInforme(informe, nodos);
    final pdf = latin1.decode(bytes);

    expect(bytes, isNotEmpty);
    expect(ascii.decode(bytes.take(4).toList()), '%PDF');
    expect(pdf, contains('/FontFile2'));
    expect(pdf, contains('/ToUnicode'));
  });

  test('evalúa las metas KPI según el sentido del indicador', () {
    expect(informe.kpis[0].cumple, isTrue);
    expect(informe.kpis[1].cumple, isFalse);
  });
}
