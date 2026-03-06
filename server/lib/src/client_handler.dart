import 'dart:io';
import 'package:duckbill_protocol/duckbill_protocol.dart';

/// Handles lifecycle and message dispatch for a single connected client.
///
/// SRP: manages only per-client communication, not AI logic.
class ClientHandler {
  final String clientId;
  final WebSocket socket;
  final ClientRegistry registry;
  final MessageRouter router;
  final void Function(String id) onDisconnect;

  ClientHandler({
    required this.clientId,
    required this.socket,
    required this.registry,
    required this.router,
    required this.onDisconnect,
  });

  /// Starts listening to the client's WebSocket stream.
  void listen() {
    socket.listen(
      (data) => _onData(data),
      onDone: _onDone,
      onError: _onError,
    );
  }

  Future<void> _onData(dynamic data) async {
    await router.dispatch(
      clientId,
      data,
      socket,
      onUnknown: _onUnknown,
    );
  }

  Future<void> _onUnknown(String id, String raw, WebSocket ws) async {
    // Treat plain-text as an implicit prompt frame for backwards compatibility.
    await router.dispatch(
      id,
      MessageFrame.prompt(raw).toJsonString(),
      ws,
    );
  }

  void _onDone() {
    registry.unregister(clientId);
    onDisconnect(clientId);
  }

  void _onError(Object error) {
    registry.unregister(clientId);
    onDisconnect(clientId);
  }
}
