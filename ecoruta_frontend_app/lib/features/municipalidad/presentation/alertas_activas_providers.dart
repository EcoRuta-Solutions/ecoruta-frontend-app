import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/app_config.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/panel_socket.dart';
import '../data/modelos_alertas_activas.dart';
import '../data/repositorio_alertas_activas.dart';

/// Abre el canal /ws/panel. Devuelve null cuando no hay WebSocket (datos de
/// ejemplo, sin sesión o en tests): entonces las alertas se sondean.
final abrirCanalPanelProvider = Provider<Future<PanelSocket?> Function()>((
  ref,
) {
  if (AppConfig.usarDatosDeEjemplo) return () async => null;
  return () async {
    final token = await ref.read(tokenStorageProvider).read();
    return token == null ? null : PanelSocket(token);
  };
});

/// Alertas activas (GET /alertas/activas).
///
/// Es autoDispose: solo se actualiza mientras una pantalla la está mirando
/// (Alertas de la municipalidad o el inicio del conductor). Se actualiza
/// con los eventos de /ws/panel (`sensor_lectura`, `alerta_nueva`,
/// `alerta_resuelta`); si el canal no está disponible o se cae, vuelve a
/// pedir la lista cada [AlertasActivasController.intervaloSondeo].
final alertasActivasProvider =
    AsyncNotifierProvider.autoDispose<
      AlertasActivasController,
      List<AlertaActiva>
    >(AlertasActivasController.new, retry: (_, _) => null);

class AlertasActivasController extends AsyncNotifier<List<AlertaActiva>> {
  static const intervaloSondeo = Duration(seconds: 5);

  /// Agrupa ráfagas de eventos del canal en una sola consulta.
  static const _espera = Duration(milliseconds: 500);

  Timer? _sondeo;
  Timer? _rafaga;
  StreamSubscription<Map<String, dynamic>>? _suscripcion;
  PanelSocket? _socket;
  bool _activo = false;

  @override
  Future<List<AlertaActiva>> build() async {
    _activo = true;
    ref.onDispose(_detener);
    final alertas = await ref
        .watch(repositorioAlertasActivasProvider)
        .listarActivas();
    unawaited(_escuchar());
    return alertas;
  }

  /// Vuelve a pedir la lista. Si falla, se conserva la última.
  Future<void> refrescar() async {
    try {
      final alertas = await ref
          .read(repositorioAlertasActivasProvider)
          .listarActivas();
      if (_activo) state = AsyncData(alertas);
    } catch (_) {
      // Un fallo puntual no borra lo que ya se ve; el próximo intento sigue.
    }
  }

  Future<void> _escuchar() async {
    PanelSocket? socket;
    try {
      socket = await ref.read(abrirCanalPanelProvider)();
    } catch (_) {
      socket = null;
    }
    if (!_activo) {
      await socket?.cerrar();
      return;
    }
    if (socket == null) {
      _iniciarSondeo();
      return;
    }
    _socket = socket;
    // El formato exacto de cada evento está por confirmar: cualquier
    // mensaje del canal hace que se vuelva a consultar la lista.
    _suscripcion = socket.mensajes().listen(
      (_) => _programarRefresco(),
      onError: (_) => _iniciarSondeo(),
      onDone: _iniciarSondeo,
      cancelOnError: true,
    );
  }

  void _programarRefresco() {
    _rafaga?.cancel();
    _rafaga = Timer(_espera, () => unawaited(refrescar()));
  }

  void _iniciarSondeo() {
    if (!_activo || _sondeo != null) return;
    _sondeo = Timer.periodic(intervaloSondeo, (_) => unawaited(refrescar()));
  }

  void _detener() {
    _activo = false;
    _sondeo?.cancel();
    _sondeo = null;
    _rafaga?.cancel();
    _rafaga = null;
    unawaited(_suscripcion?.cancel());
    _suscripcion = null;
    unawaited(_socket?.cerrar());
    _socket = null;
  }
}
