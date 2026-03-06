import 'dart:io';
import 'package:duckbill_ai/duckbill_ai.dart';
import 'package:duckbill_crypto/duckbill_crypto.dart';
import 'package:duckbill_protocol/duckbill_protocol.dart';
import 'package:duckbill_storage/duckbill_storage.dart';

import 'src/ai_request_handler.dart';
import 'src/client_handler.dart';
import 'src/config_sync_handler.dart';

export 'src/ai_request_handler.dart';
export 'src/client_handler.dart';
export 'src/config_sync_handler.dart';

/// Thin orchestrator that wires all SOLID-compliant components together.
///
/// Responsibilities (SRP):
/// - Initialise infrastructure (DB, security, AI provider).
/// - Start/stop the HTTP server.
/// - Accept connections and hand them off to [ClientHandler].
///
/// Does NOT contain business logic — delegates to specialised handlers.
class DuckbillServer {
  final SqliteDbManager db;
  final DuckbillSecurity security;
  final AiProvider aiProvider;
  final ClientRegistry _registry;
  final MessageRouter _router;
  final ConfigSyncHandler _configSync;

  HttpServer? _server;
  int _nextClientId = 0;

  DuckbillServer._({
    required this.db,
    required this.security,
    required this.aiProvider,
    required ClientRegistry registry,
    required MessageRouter router,
    required ConfigSyncHandler configSync,
  })  : _registry = registry,
        _router = router,
        _configSync = configSync;

  static Future<DuckbillServer> initialize({
    required String dbPath,
    required String apiKey,
    String model = 'gemini-3-flash-preview',
    String provider = 'gemini',
  }) async {
    final db = SqliteDbManager.init(dbPath);

    var token = await CryptoManager.getEncryptedPat();
    if (token == null) {
      token = 'generated_secret_token';
      await CryptoManager.saveEncryptedPat(token);
    }

    final security = DuckbillSecurity(token);
    final aiAdapter = GeminiAdapter(apiKey: apiKey, model: model);

    db.execute('CREATE TABLE IF NOT EXISTS agents (id INTEGER PRIMARY KEY, name TEXT)');

    final registry = ClientRegistry();
    final router = MessageRouter(registry);

    final aiHandler = AiRequestHandler(aiProvider: aiAdapter, model: model);
    final configSync = ConfigSyncHandler(model: model, provider: provider);

    // Register handlers (OCP: new types can be added without touching this class).
    router.on(MessageType.prompt, aiHandler.handle);
    router.on(MessageType.executionResult, _logExecutionResult);

    return DuckbillServer._(
      db: db,
      security: security,
      aiProvider: aiAdapter,
      registry: registry,
      router: router,
      configSync: configSync,
    );
  }

  Future<void> start({String address = '0.0.0.0', int port = 8080}) async {
    _server = await DuckbillTunnel.startServer(address: address, port: port);

    final modelName = aiProvider is GeminiAdapter
        ? (aiProvider as GeminiAdapter).model
        : 'unknown';
    print('Duckbill Server started on $address:$port [Model: $modelName]');
    print('Connected clients: ${_registry.count}');

    await for (final request in _server!) {
      final ws = await DuckbillTunnel.upgradeRequest(request, security);
      if (ws == null) continue;

      final clientId = 'client_${_nextClientId++}';
      _registry.register(clientId, ws);

      // Push config to new client immediately after handshake.
      _configSync.syncTo(ws);

      print('[+] Client connected: $clientId (total: ${_registry.count})');

      ClientHandler(
        clientId: clientId,
        socket: ws,
        registry: _registry,
        router: _router,
        onDisconnect: (id) => print('[-] Client disconnected: $id (total: ${_registry.count})'),
      ).listen();
    }
  }

  Future<void> stop() async {
    db.dispose();
    await _server?.close(force: true);
    print('Duckbill Server stopped.');
  }

  int get connectedClients => _registry.count;

  /// Static handler registered for execution-result frames (logging only).
  static Future<void> _logExecutionResult(
    String clientId,
    MessageFrame frame,
    WebSocket socket,
  ) async {
    final exitCode = frame.payload['exit_code'];
    final stdout = frame.payload['stdout'] ?? '';
    print('[$clientId] execution exit=$exitCode stdout_len=${stdout.toString().length}');
  }
}
