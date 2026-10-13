import 'dart:async';
import 'dart:convert';

import 'package:web_socket_channel/web_socket_channel.dart';

import '../config/app_config.dart';

/// Evento que el backend emite por `/ws/panel` cuando llega una lectura.
class EventoPanel {
  const EventoPanel({
    required this.tipo,
    required this.nodoId,
    required this.codigo,
    required this.llenado,
    required this.estado,
    required this.volteado,
    required this.timestamp,
  });

  final String tipo;
  final int nodoId;
  final String codigo;
  final double llenado;
  final String estado;
  final bool volteado;
  final DateTime timestamp;

  factory EventoPanel.fromJson(Map<String, dynamic> j) => EventoPanel(
    tipo: j['tipo'] as String? ?? 'lectura_nueva',
    nodoId: (j['nodo_id'] as num).toInt(),
    codigo: j['codigo'] as String? ?? '',
    llenado: (j['fill_pct'] as num).toDouble(),
    estado: j['estado'] as String? ?? 'normal',
    volteado: j['tilt_alert'] as bool? ?? false,
    timestamp:
        DateTime.tryParse(j['timestamp'] as String? ?? '') ?? DateTime.now(),
  );
}

/// Escucha el panel en tiempo real: convierte el `http(s)` de la API en el
/// `ws(s)` del endpoint `/ws/panel` y adjunta el token de la sesión.
class PanelSocket {
  PanelSocket(this._token);

  final String _token;
  WebSocketChannel? _canal;

  Uri get _url {
    final base = Uri.parse(AppConfig.baseUrl);
    return base.replace(
      scheme: base.scheme == 'https' ? 'wss' : 'ws',
      path: '/ws/panel',
      queryParameters: {'token': _token},
    );
  }

  Stream<EventoPanel> eventos() {
    final canal = WebSocketChannel.connect(_url);
    _canal = canal;
    return canal.stream.map(
      (mensaje) => EventoPanel.fromJson(
        jsonDecode(mensaje as String) as Map<String, dynamic>,
      ),
    );
  }

  Future<void> cerrar() async {
    await _canal?.sink.close();
    _canal = null;
  }
}
