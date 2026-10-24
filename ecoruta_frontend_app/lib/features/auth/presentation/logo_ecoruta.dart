import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Logo de EcoRuta: un árbol a la izquierda y un camión de recolección
/// sobre una calle punteada a la derecha. Todo dibujado con CustomPainter,
/// sin imágenes externas.
///
/// Se dibuja sobre un lienzo base de 334 x 150 y se escala con
/// AspectRatio/FittedBox, así mantiene la proporción en cualquier pantalla.
/// Las coordenadas de los pintores son las del diseño, con origen (0,0)
/// en la esquina superior izquierda de ese lienzo.
///
/// [salidaCamion] va de 0 (camión en su sitio) a 1 (camión fuera del logo,
/// por la derecha). El árbol y la calle no se mueven.
///
/// [giroRuedas] (en radianes), [desplazamientoCamion] y [inclinacionCamion]
/// sirven para las animaciones de carga y error: mueven el camión unos pocos
/// píxeles alrededor de su sitio, sin sacarlo de él.
///
/// Para cambiar el camión basta con reemplazar [CamionEcoRuta].
class LogoEcoRuta extends StatelessWidget {
  final double salidaCamion;
  final double giroRuedas;
  final Offset desplazamientoCamion;
  final double inclinacionCamion;

  const LogoEcoRuta({
    super.key,
    this.salidaCamion = 0,
    this.giroRuedas = 0,
    this.desplazamientoCamion = Offset.zero,
    this.inclinacionCamion = 0,
  });

  /// Medidas del diseño; el logo se escala para ocupar el espacio que tenga.
  static const ancho = 334.0;
  static const alto = 150.0;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Logo de EcoRuta Trujillo',
      image: true,
      child: AspectRatio(
        aspectRatio: ancho / alto,
        child: FittedBox(
          child: SizedBox(
            width: ancho,
            height: alto,
            child: ClipRect(
              child: Stack(
                children: [
                  const Positioned.fill(
                    child: CustomPaint(painter: _PintorEscena()),
                  ),
                  Positioned(
                    left:
                        CamionEcoRuta.origen.dx +
                        salidaCamion * (ancho - CamionEcoRuta.origen.dx),
                    top: CamionEcoRuta.origen.dy,
                    child: Transform.translate(
                      offset: desplazamientoCamion,
                      child: Transform.rotate(
                        angle: inclinacionCamion,
                        // Se inclina apoyado en la calle.
                        alignment: Alignment.bottomCenter,
                        child: CamionEcoRuta(giroRuedas: giroRuedas),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Camión de recolección genérico de EcoRuta (ilustración propia).
class CamionEcoRuta extends StatelessWidget {
  /// Ángulo de las ruedas en radianes.
  final double giroRuedas;

  const CamionEcoRuta({super.key, this.giroRuedas = 0});

  /// Esquina superior izquierda del camión dentro del logo.
  static const origen = Offset(69, 31);

  /// Caja trasera desde x=69 hasta el final de la cabina en x=307.
  static const ancho = 238.0;
  static const alto = 88.0;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: ancho,
      height: alto,
      child: CustomPaint(painter: _PintorCamion(giroRuedas)),
    );
  }
}

const _verdeOscuro = Color(0xFF2E7D32);
const _verdeClaro = Color(0xFF4CAF50);
const _pasto = Color(0xFF8BC34A);
const _tronco = Color(0xFF5D4037);
const _azul = Color(0xFF1F4E9C);
const _azulClaro = Color(0xFF3A6FC4);
const _celeste = Color(0xFFBFE3F7);
const _naranja = Color(0xFFF28C28);
const _oscuro = Color(0xFF16233B);
const _gris = Color(0xFFB9C7B2);

/// Árbol, pasto y calle punteada.
class _PintorEscena extends CustomPainter {
  const _PintorEscena();

  @override
  void paint(Canvas canvas, Size size) {
    final pincel = Paint()..isAntiAlias = true;

    // Calle: línea punteada de 245 x 9 en x=65, y=121.
    pincel.color = _oscuro;
    const calle = Rect.fromLTWH(65, 121, 245, 9);
    const trazo = 18.0;
    const hueco = 10.0;
    for (var x = calle.left; x < calle.right; x += trazo + hueco) {
      final fin = (x + trazo).clamp(x, calle.right);
      canvas.drawRRect(
        RRect.fromLTRBR(
          x,
          calle.top,
          fin,
          calle.bottom,
          Radius.circular(calle.height / 2),
        ),
        pincel,
      );
    }

    // Base de pasto: elipse de 51 x 18 en x=4, y=101.
    pincel.color = _pasto;
    canvas.drawOval(const Rect.fromLTWH(4, 101, 51, 18), pincel);

    // Tronco: 14 x 69 en x=22, y=39.
    pincel.color = _tronco;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(22, 39, 14, 69),
        const Radius.circular(3),
      ),
      pincel,
    );

    // Copa: círculos laterales de 27 y el central de 43 encima.
    pincel.color = _verdeOscuro;
    canvas.drawOval(const Rect.fromLTWH(0, 33, 27, 27), pincel);
    canvas.drawOval(const Rect.fromLTWH(30, 31, 27, 27), pincel);
    pincel.color = _verdeClaro;
    canvas.drawOval(const Rect.fromLTWH(7, 8, 43, 43), pincel);
  }

  @override
  bool shouldRepaint(covariant _PintorEscena oldDelegate) => false;
}

/// Camión: caja trasera, cabina, ventana, baliza y tres ruedas.
class _PintorCamion extends CustomPainter {
  final double giroRuedas;

  const _PintorCamion(this.giroRuedas);

  @override
  void paint(Canvas canvas, Size size) {
    // Dibuja con las coordenadas del logo (el widget empieza en x=69, y=31).
    canvas.translate(-CamionEcoRuta.origen.dx, -CamionEcoRuta.origen.dy);
    final pincel = Paint()..isAntiAlias = true;

    // Baliza naranja sobre la cabina: 16 x 7 en x=257, y=47.
    pincel.color = _naranja;
    canvas.drawRRect(
      RRect.fromLTRBAndCorners(
        257,
        47,
        273,
        54,
        topLeft: const Radius.circular(4),
        topRight: const Radius.circular(4),
      ),
      pincel,
    );

    // Caja trasera: 171 x 73 desde x=69, y=31, con la esquina trasera
    // superior recortada.
    pincel.color = _azul;
    canvas.drawPath(
      Path()
        ..moveTo(77, 31)
        ..lineTo(240, 31)
        ..lineTo(240, 104)
        ..lineTo(69, 104)
        ..lineTo(69, 39)
        ..close(),
      pincel,
    );

    // Cabina: 67 x 49 desde x=240, y=54, con el parabrisas inclinado.
    pincel.color = _azulClaro;
    canvas.drawPath(
      Path()
        ..moveTo(240, 54)
        ..lineTo(292, 54)
        ..lineTo(307, 72)
        ..lineTo(307, 103)
        ..lineTo(240, 103)
        ..close(),
      pincel,
    );

    // Ventana: 45 x 20 en x=251, y=60, siguiendo la inclinación.
    pincel.color = _celeste;
    canvas.drawPath(
      Path()
        ..moveTo(251, 60)
        ..lineTo(291, 60)
        ..lineTo(296, 66)
        ..lineTo(296, 80)
        ..lineTo(251, 80)
        ..close(),
      pincel,
    );

    // Ruedas de 27 (parte inferior en y=118) con un centro de 10.
    // Los rayos dejan ver el giro.
    final rayo = Paint()
      ..color = _gris
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    for (final x in const [94.0, 143.0, 257.0]) {
      final centro = Offset(x + 13.5, 118 - 13.5);
      pincel.color = _oscuro;
      canvas.drawCircle(centro, 13.5, pincel);
      for (var i = 0; i < 3; i++) {
        final angulo = giroRuedas + i * math.pi * 2 / 3;
        canvas.drawLine(
          centro,
          centro + Offset(math.cos(angulo), math.sin(angulo)) * 9.5,
          rayo,
        );
      }
      pincel.color = _gris;
      canvas.drawCircle(centro, 5, pincel);
    }
  }

  @override
  bool shouldRepaint(covariant _PintorCamion oldDelegate) =>
      oldDelegate.giroRuedas != giroRuedas;
}
