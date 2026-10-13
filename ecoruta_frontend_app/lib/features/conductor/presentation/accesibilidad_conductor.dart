import 'package:flutter/material.dart';

const ButtonStyle estiloBotonConductor = ButtonStyle(
  minimumSize: WidgetStatePropertyAll<Size>(Size(48, 48)),
  tapTargetSize: MaterialTapTargetSize.padded,
);

Widget semanticaBotonConductor({
  required String etiqueta,
  required Widget child,
}) => Semantics(label: etiqueta, child: child);
