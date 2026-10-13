import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/app_config.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/panel_socket.dart';
import '../data/modelos_panel.dart';
import '../data/panel_mock.dart';
import '../data/repositorios_mock.dart';

final panelControllerProvider =
    AsyncNotifierProvider<PanelController, DatosPanel>(
      PanelController.new,
      retry: (_, _) => null,
    );

class PanelController extends AsyncNotifier<DatosPanel> {
  StreamSubscription<EventoPanel>? _suscripcion;
  PanelSocket? _socket;

  @override
  Future<DatosPanel> build() async {
    ref.onDispose(_cerrarSocket);
    final datos = await ref.watch(repositorioPanelProvider).cargar();
    if (!AppConfig.usarDatosDeEjemplo) {
      unawaited(_conectarSocket());
    }
    return datos;
  }

  Future<void> recargar() async {
    state = const AsyncLoading<DatosPanel>();
    state = await AsyncValue.guard(
      () => ref.read(repositorioPanelProvider).cargar(),
    );
  }

  Future<void> _conectarSocket() async {
    final token = await ref.read(tokenStorageProvider).read();
    if (token == null) return;

    final socket = PanelSocket(token);
    _socket = socket;
    _suscripcion = socket
        .eventos()
        .listen(_aplicarEvento, onError: (_) {}, cancelOnError: false);
  }

  Future<void> _cerrarSocket() async {
    await _suscripcion?.cancel();
    _suscripcion = null;
    await _socket?.cerrar();
    _socket = null;
  }

  void _aplicarEvento(EventoPanel evento) {
    final actual = state.asData?.value;
    if (actual == null) return;

    final nodos = [
      for (final nodo in actual.nodos)
        if (nodo.id == evento.nodoId)
          nodo.conLectura(
            llenado: evento.llenado,
            estado: estadoDesdeTexto(evento.estado),
            volteado: evento.volteado,
            ultimaLectura: evento.timestamp,
          )
        else
          nodo,
    ];
    state = AsyncData(
      DatosPanel(nodos: nodos, resumen: resumenDesdeNodos(nodos)),
    );
  }
}
