import 'package:flutter/material.dart';

/// Logo de EcoRuta: un árbol a la izquierda y un camión de recolección
/// sobre una calle punteada a la derecha. Todo dibujado con CustomPainter,
/// sin imágenes externas.
///
/// [salidaCamion] va de 0 (camión en su sitio) a 1 (camión fuera del logo,
/// por la derecha). El árbol y la calle no se mueven.
///
/// Para cambiar el camión basta con reemplazar [CamionEcoRuta].
class LogoEcoRuta extends StatelessWidget {
  final double salidaCamion;

  const LogoEcoRuta({super.key, this.salidaCamion = 0});

  /// Medidas del diseño; el logo se escala para ocupar el espacio que tenga.
  static const ancho = 334.0;
  static const alto = 150.0;

  static const _camionIzquierda = 168.0;
  static const _camionArriba = 52.0;

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
                    left: _camionIzquierda +
                        salidaCamion * (ancho - _camionIzquierda),
                    top: _camionArriba,
                    child: const CamionEcoRuta(),
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
  const CamionEcoRuta({super.key});

  static const ancho = 150.0;
  static const alto = 82.0;

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      width: ancho,
      height: alto,
      child: CustomPaint(painter: _PintorCamion()),
    );
  }
}

const _verdeOscuro = Color(0xFF2E7D32);
const _verdeClaro = Color(0xFF4CAF50);
const _pasto = Color(0xFF7CB342);
const _tronco = Color(0xFF5D4037);
const _azul = Color(0xFF1F4E9C);
const _azulClaro = Color(0xFF3A6FC4);
const _vidrio = Color(0xFFDCE8F7);
const _oscuro = Color(0xFF16233B);
const _gris = Color(0xFFB9C7B2);

/// Árbol, pasto y calle punteada.
class _PintorEscena extends CustomPainter {
  const _PintorEscena();

  @override
  void paint(Canvas canvas, Size size) {
    final pincel = Paint()..isAntiAlias = true;

    // Calle punteada bajo el camión.
    final calle = Paint()
      ..color = _oscuro.withValues(alpha: 0.55)
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    for (var x = 136.0; x < size.width - 4; x += 17) {
      canvas.drawLine(Offset(x, 138), Offset(x + 10, 138), calle);
    }

    // Base de pasto.
    pincel.color = _pasto;
    canvas.drawRRect(
      RRect.fromLTRBR(14, 128, 126, 142, const Radius.circular(7)),
      pincel,
    );

    // Tronco.
    pincel.color = _tronco;
    canvas.drawRRect(
      RRect.fromLTRBR(62, 76, 78, 132, const Radius.circular(3)),
      pincel,
    );

    // Copa: tres círculos, el central más claro encima.
    pincel.color = _verdeOscuro;
    canvas.drawCircle(const Offset(44, 72), 24, pincel);
    canvas.drawCircle(const Offset(96, 72), 24, pincel);
    pincel.color = _verdeClaro;
    canvas.drawCircle(const Offset(70, 50), 34, pincel);
  }

  @override
  bool shouldRepaint(covariant _PintorEscena oldDelegate) => false;
}

/// Camión: tolva azul, cabina, ventana y dos ruedas.
class _PintorCamion extends CustomPainter {
  const _PintorCamion();

  @override
  void paint(Canvas canvas, Size size) {
    final pincel = Paint()..isAntiAlias = true;

    // Tolva (caja de carga).
    pincel.color = _azul;
    canvas.drawRRect(
      RRect.fromLTRBR(0, 6, 96, 64, const Radius.circular(8)),
      pincel,
    );

    // Franja verde en la tolva.
    pincel.color = _verdeClaro;
    canvas.drawRRect(
      RRect.fromLTRBR(10, 30, 86, 38, const Radius.circular(4)),
      pincel,
    );

    // Cabina.
    pincel.color = _azulClaro;
    canvas.drawRRect(
      RRect.fromLTRBAndCorners(
        100,
        22,
        146,
        64,
        topRight: const Radius.circular(14),
        topLeft: const Radius.circular(6),
        bottomLeft: const Radius.circular(4),
        bottomRight: const Radius.circular(6),
      ),
      pincel,
    );

    // Ventana.
    pincel.color = _vidrio;
    canvas.drawRRect(
      RRect.fromLTRBAndCorners(
        110,
        30,
        138,
        44,
        topRight: const Radius.circular(8),
        topLeft: const Radius.circular(3),
        bottomLeft: const Radius.circular(3),
        bottomRight: const Radius.circular(3),
      ),
      pincel,
    );

    // Chasis.
    pincel.color = _oscuro;
    canvas.drawRRect(
      RRect.fromLTRBR(0, 60, 148, 68, const Radius.circular(3)),
      pincel,
    );

    // Ruedas.
    for (final x in const [28.0, 120.0]) {
      pincel.color = _oscuro;
      canvas.drawCircle(Offset(x, 70), 12, pincel);
      pincel.color = _gris;
      canvas.drawCircle(Offset(x, 70), 4.5, pincel);
    }
  }

  @override
  bool shouldRepaint(covariant _PintorCamion oldDelegate) => false;
}
