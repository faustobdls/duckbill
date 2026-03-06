import 'dart:io';

/// Metadata stored alongside each connected WebSocket client.
class ClientInfo {
  final String id;
  final WebSocket socket;
  final DateTime connectedAt;

  const ClientInfo({
    required this.id,
    required this.socket,
    required this.connectedAt,
  });
}

/// Tracks active WebSocket connections (SRP: only manages the registry).
///
/// Thread-safe for single-isolate Dart async usage.
class ClientRegistry {
  final Map<String, ClientInfo> _clients = {};

  /// Registers [socket] under the given [id].
  void register(String id, WebSocket socket) {
    _clients[id] = ClientInfo(
      id: id,
      socket: socket,
      connectedAt: DateTime.now(),
    );
  }

  /// Removes the client with [id] from the registry.
  void unregister(String id) => _clients.remove(id);

  /// Returns the [ClientInfo] for [id], or null if not found.
  ClientInfo? get(String id) => _clients[id];

  /// All currently connected clients.
  Iterable<ClientInfo> get all => _clients.values;

  /// Number of connected clients.
  int get count => _clients.length;

  /// Whether [id] is currently registered.
  bool contains(String id) => _clients.containsKey(id);

  /// Broadcasts a raw string [message] to all connected clients.
  void broadcast(String message) {
    for (final client in _clients.values) {
      try {
        client.socket.add(message);
      } catch (_) {
        // Ignore send errors for individual clients; caller handles cleanup.
      }
    }
  }

  /// Broadcasts to all clients except [excludeId].
  void broadcastExcept(String excludeId, String message) {
    for (final client in _clients.values) {
      if (client.id == excludeId) continue;
      try {
        client.socket.add(message);
      } catch (_) {}
    }
  }
}
