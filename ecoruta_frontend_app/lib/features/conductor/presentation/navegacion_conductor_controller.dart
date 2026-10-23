import 'package:flutter_riverpod/flutter_riverpod.dart';

enum DestinoConductor { miRuta, mapa, mas }

class NavegacionConductor {
  const NavegacionConductor({this.destino = DestinoConductor.miRuta});

  final DestinoConductor destino;
}

final navegacionConductorProvider =
    NotifierProvider<NavegacionConductorController, NavegacionConductor>(
      NavegacionConductorController.new,
    );

class NavegacionConductorController extends Notifier<NavegacionConductor> {
  @override
  NavegacionConductor build() => const NavegacionConductor();

  void seleccionar(DestinoConductor destino) {
    state = NavegacionConductor(destino: destino);
  }
}
