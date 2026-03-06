import 'dart:io';
import 'package:duckbill_protocol/duckbill_protocol.dart';

/// Pushes model/provider configuration to newly connected clients.
///
/// SRP: only responsible for the config handshake after WebSocket upgrade.
class ConfigSyncHandler {
  final String model;
  final String provider;

  const ConfigSyncHandler({required this.model, required this.provider});

  /// Sends a [MessageType.config] frame to [socket].
  void syncTo(WebSocket socket) {
    final frame = MessageFrame.config(
      model: model,
      provider: provider,
      systemInstruction: null, // client builds its own context
    );
    socket.add(frame.toJsonString());
  }
}
