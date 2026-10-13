import 'package:flutter_riverpod/flutter_riverpod.dart';

enum DestinoCiudadano { inicio, reportar, misReportes, perfil }

class NavegacionCiudadano {
  const NavegacionCiudadano({this.destino = DestinoCiudadano.inicio});

  final DestinoCiudadano destino;
}

final navegacionCiudadanoProvider =
    NotifierProvider<NavegacionCiudadanoController, NavegacionCiudadano>(
      NavegacionCiudadanoController.new,
    );

class NavegacionCiudadanoController extends Notifier<NavegacionCiudadano> {
  @override
  NavegacionCiudadano build() => const NavegacionCiudadano();

  void seleccionar(DestinoCiudadano destino) {
    state = NavegacionCiudadano(destino: destino);
  }
}
