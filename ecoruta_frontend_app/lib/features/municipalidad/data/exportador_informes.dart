import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:pdf/widgets.dart' as pw;

import 'modelos_informe.dart';
import 'modelos_panel.dart';

final _fechaExportacion = DateFormat('dd/MM/yyyy', 'es');

String generarCsvInforme(DatosInforme informe, List<NodoEstado> nodos) {
  final filas = <List<String>>[
    ['Informe EcoRuta Trujillo'],
    [
      'Periodo',
      _fechaExportacion.format(informe.inicio),
      _fechaExportacion.format(informe.fin),
    ],
    [],
    ['Indicador', 'Valor', 'Meta', 'Resultado'],
    for (final kpi in informe.kpis)
      [
        kpi.nombre,
        '${_numero(kpi.valor)}${kpi.unidad}',
        '${_numero(kpi.meta)}${kpi.unidad}',
        kpi.cumple ? 'Cumple' : 'No cumple',
      ],
    [],
    ['Código', 'Contenedor', 'Zona', 'Estado', 'Llenado', 'Última lectura'],
    for (final nodo in nodos)
      [
        nodo.codigo,
        nodo.nombre,
        nodo.zona,
        _nombreEstado(nodo.estado),
        nodo.llenado == null ? '' : '${_numero(nodo.llenado!)}%',
        nodo.ultimaLectura == null
            ? ''
            : _fechaExportacion.format(nodo.ultimaLectura!),
      ],
  ];
  return '\uFEFF${filas.map((fila) => fila.map(_celdaCsv).join(';')).join('\r\n')}';
}

Future<Uint8List> generarPdfInforme(
  DatosInforme informe,
  List<NodoEstado> nodos,
) async {
  final fuenteRegular = pw.Font.ttf(
    await rootBundle.load('assets/fonts/NotoSans-Regular.ttf'),
  );
  final fuenteNegrita = pw.Font.ttf(
    await rootBundle.load('assets/fonts/NotoSans-Bold.ttf'),
  );
  final fuenteSimbolos = pw.Font.ttf(
    await rootBundle.load('assets/fonts/NotoSansMath-Regular.ttf'),
  );
  final documento = pw.Document();
  documento.addPage(
    pw.MultiPage(
      theme: pw.ThemeData.withFont(
        base: fuenteRegular,
        bold: fuenteNegrita,
        fontFallback: [fuenteSimbolos],
      ),
      build: (context) => [
        pw.Text(
          'Informe EcoRuta Trujillo',
          style: pw.Theme.of(context).header1,
        ),
        pw.SizedBox(height: 8),
        pw.Text(
          'Periodo: ${_fechaExportacion.format(informe.inicio)} - '
          '${_fechaExportacion.format(informe.fin)}',
        ),
        pw.SizedBox(height: 20),
        pw.Text(
          'Indicadores de desempeño',
          style: pw.Theme.of(context).header2,
        ),
        pw.SizedBox(height: 8),
        pw.TableHelper.fromTextArray(
          headers: const ['Indicador', 'Valor', 'Meta', 'Resultado'],
          data: [
            for (final kpi in informe.kpis)
              [
                kpi.nombre,
                '${_numero(kpi.valor)}${kpi.unidad}',
                '${_numero(kpi.meta)}${kpi.unidad}',
                kpi.cumple ? 'Cumple' : 'No cumple',
              ],
          ],
        ),
        pw.SizedBox(height: 20),
        pw.Text('Contenedores', style: pw.Theme.of(context).header2),
        pw.SizedBox(height: 8),
        pw.TableHelper.fromTextArray(
          headers: const ['Código', 'Nombre', 'Zona', 'Estado', 'Llenado'],
          data: [
            for (final nodo in nodos)
              [
                nodo.codigo,
                nodo.nombre,
                nodo.zona,
                _nombreEstado(nodo.estado),
                nodo.llenado == null
                    ? 'Sin datos'
                    : '${_numero(nodo.llenado!)}%',
              ],
          ],
        ),
      ],
    ),
  );
  return documento.save();
}

String _celdaCsv(String valor) {
  final escapado = valor.replaceAll('"', '""');
  return '"$escapado"';
}

String _numero(double valor) => valor == valor.roundToDouble()
    ? valor.round().toString()
    : valor.toStringAsFixed(1);

String _nombreEstado(EstadoNodo estado) => switch (estado) {
  EstadoNodo.critico => 'Crítico',
  EstadoNodo.alerta => 'En alerta',
  EstadoNodo.normal => 'Normal',
  EstadoNodo.sinDatos => 'Sin datos',
};
