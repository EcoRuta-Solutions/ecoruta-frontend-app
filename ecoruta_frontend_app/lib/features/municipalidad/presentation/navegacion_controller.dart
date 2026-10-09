import 'package:flutter_riverpod/flutter_riverpod.dart';

enum DestinoMunicipalidad { panel, mapa, alertas, rutas, mas }

enum OpcionMasMunicipalidad {
  contenedores,
  reportesCiudadanos,
  usuariosYFlota,
  informes,
}

class NavegacionMunicipalidad {
  const NavegacionMunicipalidad({
    this.destino = DestinoMunicipalidad.panel,
    this.opcionMas,
    this.focoNodoId,
  });

  final DestinoMunicipalidad destino;
  final OpcionMasMunicipalidad? opcionMas;
  final int? focoNodoId;
}

final navegacionMunicipalidadProvider =
    NotifierProvider<
      NavegacionMunicipalidadController,
      NavegacionMunicipalidad
    >(NavegacionMunicipalidadController.new);

class NavegacionMunicipalidadController
    extends Notifier<NavegacionMunicipalidad> {
  @override
  NavegacionMunicipalidad build() => const NavegacionMunicipalidad();

  void seleccionar(DestinoMunicipalidad destino) {
    state = NavegacionMunicipalidad(destino: destino);
  }

  void verNodoEnMapa(int nodoId) {
    state = NavegacionMunicipalidad(
      destino: DestinoMunicipalidad.mapa,
      focoNodoId: nodoId,
    );
  }

  void abrirOpcion(OpcionMasMunicipalidad opcion) {
    state = NavegacionMunicipalidad(
      destino: DestinoMunicipalidad.mas,
      opcionMas: opcion,
    );
  }

  void volverAMas() {
    state = const NavegacionMunicipalidad(destino: DestinoMunicipalidad.mas);
  }
}
