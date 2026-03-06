import 'dart:io';
import 'message_frame.dart';
import 'client_registry.dart';

/// Callback type for handling a [MessageFrame] from a specific client.
typedef FrameHandler = Future<void> Function(
    String clientId, MessageFrame frame, WebSocket socket);

/// Routes incoming [MessageFrame]s to the appropriate registered handler.
///
/// Follows OCP: new message types can be handled by registering new handlers
/// without modifying this class.
class MessageRouter {
  final Map<MessageType, FrameHandler> _handlers = {};
  final ClientRegistry _registry;

  MessageRouter(this._registry);

  /// Registers [handler] for messages of [type].
  ///
  /// Replaces any previously registered handler for the same type.
  void on(MessageType type, FrameHandler handler) {
    _handlers[type] = handler;
  }

  /// Dispatches [raw] received from [clientId] to the appropriate handler.
  ///
  /// If the frame is not parseable, calls the [onUnknown] fallback if set.
  Future<void> dispatch(
    String clientId,
    dynamic raw,
    WebSocket socket, {
    Future<void> Function(String clientId, String raw, WebSocket socket)? onUnknown,
  }) async {
    if (raw is! String) return;

    final frame = MessageFrame.fromJsonString(raw);
    if (frame == null) {
      await onUnknown?.call(clientId, raw, socket);
      return;
    }

    final handler = _handlers[frame.type];
    if (handler != null) {
      await handler(clientId, frame, socket);
    }
  }

  /// Returns true if a handler is registered for [type].
  bool hasHandler(MessageType type) => _handlers.containsKey(type);

  ClientRegistry get registry => _registry;
}
