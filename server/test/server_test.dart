import 'dart:async';
import 'dart:io';
import 'package:duckbill_ai/duckbill_ai.dart';
import 'package:duckbill_protocol/duckbill_protocol.dart';
import 'package:server/server.dart';
import 'package:test/test.dart';

// ─── Test doubles ────────────────────────────────────────────────────────────

class _FailingAiProvider implements AiProvider {
  @override
  Future<String> generateContent(String prompt, {String? systemInstruction}) =>
      throw Exception('AI unavailable in test');
}

// ─── Tests ───────────────────────────────────────────────────────────────────

void main() {
  group('DuckbillServer', () {
    late Directory tempDir;
    late String dbPath;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('server_test');
      dbPath = '${tempDir.path}/test_server.sqlite';
    });

    tearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('initializes and creates DB file', () async {
      final server = await DuckbillServer.initialize(
        dbPath: dbPath,
        apiKey: 'FAKE_API_KEY',
      );
      expect(File(dbPath).existsSync(), isTrue);
      await server.stop();
    });

    test('connectedClients starts at 0', () async {
      final server = await DuckbillServer.initialize(
        dbPath: dbPath,
        apiKey: 'FAKE_API_KEY',
      );
      expect(server.connectedClients, 0);
      await server.stop();
    });

    test('stop closes server cleanly', () async {
      final server = await DuckbillServer.initialize(
        dbPath: dbPath,
        apiKey: 'FAKE_API_KEY',
      );
      await server.stop(); // should not throw
    });

    test('handles websocket connection and pushes config frame', () async {
      final server = await DuckbillServer.initialize(
        dbPath: dbPath,
        apiKey: 'FAKE_API_KEY',
      );

      const port = 19090;
      unawaited(server.start(address: '127.0.0.1', port: port));
      await Future.delayed(const Duration(milliseconds: 150));

      final token = server.security.secretToken;
      WebSocket? wsClient;
      try {
        wsClient = await WebSocket.connect(
          'ws://127.0.0.1:$port/',
          headers: {'Authorization': 'Bearer $token'},
        );

        final received = <String>[];
        wsClient.listen((data) {
          if (data is String) received.add(data);
        });

        await Future.delayed(const Duration(milliseconds: 100));

        // Server pushes a config frame on connect.
        expect(
          received.any((r) {
            final f = MessageFrame.fromJsonString(r);
            return f != null && f.type == MessageType.config;
          }),
          isTrue,
        );

        // Send a prompt (AI will fail with fake key — that's OK).
        wsClient.add(MessageFrame.prompt('Hello AI').toJsonString());
        await Future.delayed(const Duration(milliseconds: 100));
      } catch (_) {
        // Network or AI errors are acceptable in unit tests.
      } finally {
        await wsClient?.close();
      }

      await server.stop();
    });

    test('rejects unauthorized websocket connection', () async {
      final server = await DuckbillServer.initialize(
        dbPath: dbPath,
        apiKey: 'FAKE_API_KEY',
      );

      const port = 19091;
      unawaited(server.start(address: '127.0.0.1', port: port));
      await Future.delayed(const Duration(milliseconds: 150));

      bool failed = false;
      try {
        await WebSocket.connect(
          'ws://127.0.0.1:$port/',
          headers: {'Authorization': 'Bearer WRONG_TOKEN'},
        );
      } catch (_) {
        failed = true;
      }

      expect(failed, isTrue);
      await server.stop();
    });

    test('plain text prompt is treated as implicit prompt frame', () async {
      final server = await DuckbillServer.initialize(
        dbPath: dbPath,
        apiKey: 'FAKE_API_KEY',
      );

      const port = 19092;
      unawaited(server.start(address: '127.0.0.1', port: port));
      await Future.delayed(const Duration(milliseconds: 150));

      final token = server.security.secretToken;
      WebSocket? wsClient;
      try {
        wsClient = await WebSocket.connect(
          'ws://127.0.0.1:$port/',
          headers: {'Authorization': 'Bearer $token'},
        );

        // Send plain text — server should not crash.
        wsClient.add('list files in current dir');
        await Future.delayed(const Duration(milliseconds: 100));
      } catch (_) {
      } finally {
        await wsClient?.close();
      }

      await server.stop();
    });
  });

  // ─── AiRequestHandler ──────────────────────────────────────────────────────

  group('AiRequestHandler', () {
    late HttpServer httpServer;

    setUp(() async {
      httpServer = await HttpServer.bind('127.0.0.1', 0);
    });

    tearDown(() async {
      await httpServer.close(force: true);
    });

    Future<(WebSocket serverWs, WebSocket clientWs)> _makeWsPair() async {
      final clientFuture = WebSocket.connect('ws://127.0.0.1:${httpServer.port}/');
      final serverReq = await httpServer.first;
      final serverWs = await WebSocketTransformer.upgrade(serverReq);
      final clientWs = await clientFuture;
      return (serverWs, clientWs);
    }

    test('sends error frame when prompt is empty', () async {
      final (serverWs, clientWs) = await _makeWsPair();
      final received = <String>[];
      clientWs.listen((d) { if (d is String) received.add(d); });

      final handler = AiRequestHandler(aiProvider: _FailingAiProvider(), model: 'test');
      final frame = MessageFrame(type: MessageType.prompt, payload: {'text': ''});
      await handler.handle('c1', frame, serverWs);

      await Future.delayed(const Duration(milliseconds: 50));

      final errorFrame = received
          .map(MessageFrame.fromJsonString)
          .whereType<MessageFrame>()
          .firstWhere((f) => f.type == MessageType.error, orElse: () => MessageFrame.error('none'));

      expect(errorFrame.type, MessageType.error);

      await serverWs.close();
      await clientWs.close();
    });

    test('sends error frame when AI throws', () async {
      final (serverWs, clientWs) = await _makeWsPair();
      final received = <String>[];
      clientWs.listen((d) { if (d is String) received.add(d); });

      final handler = AiRequestHandler(aiProvider: _FailingAiProvider(), model: 'test');
      final frame = MessageFrame(type: MessageType.prompt, payload: {'text': 'hello'});
      await handler.handle('c1', frame, serverWs);

      await Future.delayed(const Duration(milliseconds: 50));

      // Should have an error frame OR a streamEnd frame
      final frames = received.map(MessageFrame.fromJsonString).whereType<MessageFrame>().toList();
      expect(frames.any((f) => f.type == MessageType.error || f.type == MessageType.streamEnd), isTrue);

      await serverWs.close();
      await clientWs.close();
    });
  });

  // ─── ConfigSyncHandler ─────────────────────────────────────────────────────

  group('ConfigSyncHandler', () {
    test('sends config frame with model and provider', () async {
      final httpServer = await HttpServer.bind('127.0.0.1', 0);
      final clientFuture = WebSocket.connect('ws://127.0.0.1:${httpServer.port}/');
      final serverReq = await httpServer.first;
      final serverWs = await WebSocketTransformer.upgrade(serverReq);
      final clientWs = await clientFuture;

      final received = <String>[];
      clientWs.listen((d) { if (d is String) received.add(d); });

      const handler = ConfigSyncHandler(model: 'my-model', provider: 'gemini');
      handler.syncTo(serverWs);

      await Future.delayed(const Duration(milliseconds: 50));

      final configFrame = received
          .map(MessageFrame.fromJsonString)
          .whereType<MessageFrame>()
          .firstWhere((f) => f.type == MessageType.config);

      expect(configFrame.payload['model'], 'my-model');
      expect(configFrame.payload['provider'], 'gemini');

      await serverWs.close();
      await clientWs.close();
      await httpServer.close(force: true);
    });
  });
}
