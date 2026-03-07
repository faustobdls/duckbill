import 'dart:convert';
import 'dart:io';
import 'package:duckbill_protocol/duckbill_protocol.dart';
import 'package:test/test.dart';

void main() {
  // ─── DuckbillSecurity ──────────────────────────────────────────────────────

  group('DuckbillSecurity', () {
    test('signs properly', () {
      final security = DuckbillSecurity('my_super_secret');
      final sign = security.sign('sample_payload', 1700000000000);
      expect(sign, isNotEmpty);
      expect(sign.length, greaterThan(30));
    });

    test('verifies correctly within TTL', () {
      final security = DuckbillSecurity('my_secret');
      const ts = 1700000000000;
      final sign = security.sign('test_payload', ts);
      expect(security.verify('test_payload', ts, sign, currentTimestampMs: ts + 5000), isTrue);
    });

    test('fails verification if outside TTL', () {
      final security = DuckbillSecurity('my_secret');
      const ts = 1700000000000;
      final sign = security.sign('test_payload', ts);
      expect(
        security.verify('test_payload', ts, sign, currentTimestampMs: ts + 181000),
        isFalse,
      );
    });

    test('fails verification on mismatched signature length', () {
      final security = DuckbillSecurity('my_secret');
      const ts = 1700000000000;
      expect(security.verify('test_payload', ts, 'too_short_sign', currentTimestampMs: ts + 1000), isFalse);
    });

    test('fails verification on modified signature', () {
      final security = DuckbillSecurity('my_secret');
      const ts = 1700000000000;
      final original = security.sign('test_payload', ts);
      final fake = (original[0] == 'a' ? 'b' : 'a') + original.substring(1);
      expect(security.verify('test_payload', ts, fake, currentTimestampMs: ts + 1000), isFalse);
    });

    test('different secrets produce different signatures', () {
      final a = DuckbillSecurity('secret_a').sign('payload', 1000);
      final b = DuckbillSecurity('secret_b').sign('payload', 1000);
      expect(a, isNot(equals(b)));
    });
  });

  // ─── DuckbillTunnel ────────────────────────────────────────────────────────

  group('DuckbillTunnel', () {
    test('authenticates valid handshake', () async {
      final security = DuckbillSecurity('my_token');
      final server = await DuckbillTunnel.startServer(address: '127.0.0.1', port: 0);

      final serverFuture = server.first.then((req) => DuckbillTunnel.upgradeRequest(req, security));

      final wsClient = await WebSocket.connect(
        'ws://127.0.0.1:${server.port}/',
        headers: {'Authorization': 'Bearer my_token'},
      );

      final wsServer = await serverFuture;
      expect(wsServer, isA<WebSocket>());

      await wsServer?.close();
      await wsClient.close();
      await server.close(force: true);
    });

    test('rejects missing token', () async {
      final security = DuckbillSecurity('my_token');
      final server = await DuckbillTunnel.startServer(address: '127.0.0.1', port: 0);

      final client = HttpClient();
      final request = await client.get('127.0.0.1', server.port, '/');
      final responseFuture = request.close();

      final serverRequest = await server.first;
      final ws = await DuckbillTunnel.upgradeRequest(serverRequest, security);

      expect(ws, isNull);
      expect((await responseFuture).statusCode, HttpStatus.unauthorized);

      await server.close(force: true);
      client.close();
    });

    test('rejects wrong token', () async {
      final security = DuckbillSecurity('my_token');
      final server = await DuckbillTunnel.startServer(address: '127.0.0.1', port: 0);

      final client = HttpClient();
      final request = await client.get('127.0.0.1', server.port, '/');
      request.headers.set('Authorization', 'Bearer wrong_token');
      final responseFuture = request.close();

      final serverRequest = await server.first;
      final ws = await DuckbillTunnel.upgradeRequest(serverRequest, security);

      expect(ws, isNull);
      expect((await responseFuture).statusCode, HttpStatus.unauthorized);

      await server.close(force: true);
      client.close();
    });
  });

  // ─── MessageFrame ──────────────────────────────────────────────────────────

  group('MessageFrame', () {
    test('prompt factory sets type and text payload', () {
      final f = MessageFrame.prompt('hello');
      expect(f.type, MessageType.prompt);
      expect(f.payload['text'], 'hello');
    });

    test('response factory sets type, text and model', () {
      final f = MessageFrame.response('answer', model: 'gemini-3');
      expect(f.type, MessageType.response);
      expect(f.payload['text'], 'answer');
      expect(f.payload['model'], 'gemini-3');
    });

    test('response without model has no model key', () {
      final f = MessageFrame.response('text');
      expect(f.payload.containsKey('model'), isFalse);
    });

    test('suggestion factory encodes payload', () {
      final f = MessageFrame.suggestion({'command': 'ls'});
      expect(f.type, MessageType.suggestion);
      expect(f.payload['command'], 'ls');
    });

    test('executionResult factory sets all fields', () {
      final f = MessageFrame.executionResult(exitCode: 0, stdout: 'out', stderr: '');
      expect(f.type, MessageType.executionResult);
      expect(f.payload['exit_code'], 0);
      expect(f.payload['stdout'], 'out');
    });

    test('config factory sets model and provider', () {
      final f = MessageFrame.config(model: 'gemini-3', provider: 'gemini');
      expect(f.type, MessageType.config);
      expect(f.payload['model'], 'gemini-3');
      expect(f.payload['provider'], 'gemini');
    });

    test('config with systemInstruction includes it', () {
      final f = MessageFrame.config(
          model: 'm', provider: 'p', systemInstruction: 'be helpful');
      expect(f.payload['system_instruction'], 'be helpful');
    });

    test('config without systemInstruction omits it', () {
      final f = MessageFrame.config(model: 'm', provider: 'p');
      expect(f.payload.containsKey('system_instruction'), isFalse);
    });

    test('streamEnd has empty payload', () {
      final f = MessageFrame.streamEnd();
      expect(f.type, MessageType.streamEnd);
      expect(f.payload, isEmpty);
    });

    test('error factory sets message', () {
      final f = MessageFrame.error('something went wrong');
      expect(f.type, MessageType.error);
      expect(f.payload['message'], 'something went wrong');
    });

    test('toJson serialises correctly', () {
      final f = MessageFrame.prompt('hi');
      final json = f.toJson();
      expect(json['type'], 'prompt');
      expect(json['payload'], isA<Map>());
      expect(json['ts'], isA<int>());
    });

    test('toJsonString produces parseable JSON', () {
      final f = MessageFrame.prompt('test');
      final str = f.toJsonString();
      expect(() => jsonDecode(str), returnsNormally);
    });

    test('fromJsonString round-trips', () {
      final f = MessageFrame.response('hello', model: 'gpt');
      final parsed = MessageFrame.fromJsonString(f.toJsonString());
      expect(parsed, isNotNull);
      expect(parsed!.type, MessageType.response);
      expect(parsed.payload['text'], 'hello');
    });

    test('fromJsonString returns null for invalid JSON', () {
      expect(MessageFrame.fromJsonString('not json'), isNull);
    });

    test('fromJsonString returns null for unknown type', () {
      final json = jsonEncode({'type': 'unknown_type', 'payload': {}, 'ts': 1234});
      expect(MessageFrame.fromJsonString(json), isNull);
    });

    test('fromJsonString handles missing ts', () {
      final json = jsonEncode({'type': 'prompt', 'payload': {'text': 'hi'}});
      final f = MessageFrame.fromJsonString(json);
      expect(f, isNotNull);
      expect(f!.type, MessageType.prompt);
    });

    test('timestamp defaults to now when not provided', () {
      final before = DateTime.now().millisecondsSinceEpoch;
      final f = MessageFrame.prompt('x');
      final after = DateTime.now().millisecondsSinceEpoch;
      expect(f.timestampMs, greaterThanOrEqualTo(before));
      expect(f.timestampMs, lessThanOrEqualTo(after));
    });

    test('toString is descriptive', () {
      final f = MessageFrame.prompt('x');
      expect(f.toString(), contains('prompt'));
    });
  });

  // ─── ClientRegistry ────────────────────────────────────────────────────────

  group('ClientRegistry', () {
    late HttpServer server;
    late WebSocket ws1;
    late WebSocket ws2;

    setUp(() async {
      server = await HttpServer.bind('127.0.0.1', 0);
    });

    tearDown(() async {
      await ws1.close().catchError((_) {});
      await ws2.close().catchError((_) {});
      await server.close(force: true);
    });

    Future<WebSocket> makeWs() async {
      final clientFuture = WebSocket.connect('ws://127.0.0.1:${server.port}/');
      final serverReq = await server.first;
      final serverWs = await WebSocketTransformer.upgrade(serverReq);
      final clientWs = await clientFuture;
      // We return server-side socket to register
      await clientWs.close();
      return serverWs;
    }

    test('register and count', () async {
      ws1 = await makeWs();
      ws2 = await makeWs();

      final registry = ClientRegistry();
      registry.register('a', ws1);
      registry.register('b', ws2);

      expect(registry.count, 2);
      expect(registry.contains('a'), isTrue);
      expect(registry.contains('b'), isTrue);
      expect(registry.contains('c'), isFalse);
    });

    test('unregister removes client', () async {
      ws1 = await makeWs();
      ws2 = await makeWs();

      final registry = ClientRegistry();
      registry.register('a', ws1);
      registry.unregister('a');

      expect(registry.count, 0);
      expect(registry.contains('a'), isFalse);
    });

    test('get returns null for unknown id', () async {
      ws1 = await makeWs();
      ws2 = await makeWs();

      final registry = ClientRegistry();
      expect(registry.get('nobody'), isNull);
    });

    test('get returns info for registered client', () async {
      ws1 = await makeWs();
      ws2 = await makeWs();

      final registry = ClientRegistry();
      registry.register('x', ws1);
      final info = registry.get('x');
      expect(info, isNotNull);
      expect(info!.id, 'x');
    });

    test('all returns all registered clients', () async {
      ws1 = await makeWs();
      ws2 = await makeWs();

      final registry = ClientRegistry();
      registry.register('a', ws1);
      registry.register('b', ws2);
      expect(registry.all.length, 2);
    });
  });

  // ─── MessageRouter ─────────────────────────────────────────────────────────

  group('MessageRouter', () {
    test('dispatches to correct handler by type', () async {
      final registry = ClientRegistry();
      final router = MessageRouter(registry);

      final received = <MessageFrame>[];
      router.on(MessageType.prompt, (id, frame, ws) async => received.add(frame));

      final server = await HttpServer.bind('127.0.0.1', 0);
      final clientFuture = WebSocket.connect('ws://127.0.0.1:${server.port}/');
      final serverReq = await server.first;
      final serverWs = await WebSocketTransformer.upgrade(serverReq);
      final clientWs = await clientFuture;

      final frame = MessageFrame.prompt('hello');
      await router.dispatch('c1', frame.toJsonString(), serverWs);

      expect(received, hasLength(1));
      expect(received.first.type, MessageType.prompt);

      await serverWs.close();
      await clientWs.close();
      await server.close(force: true);
    });

    test('calls onUnknown for non-JSON raw string', () async {
      final registry = ClientRegistry();
      final router = MessageRouter(registry);
      final unknowns = <String>[];

      final server = await HttpServer.bind('127.0.0.1', 0);
      final clientFuture = WebSocket.connect('ws://127.0.0.1:${server.port}/');
      final serverReq = await server.first;
      final serverWs = await WebSocketTransformer.upgrade(serverReq);
      final clientWs = await clientFuture;

      await router.dispatch('c1', 'plain text', serverWs,
          onUnknown: (id, raw, ws) async => unknowns.add(raw));

      expect(unknowns, ['plain text']);

      await serverWs.close();
      await clientWs.close();
      await server.close(force: true);
    });

    test('ignores non-string data', () async {
      final registry = ClientRegistry();
      final router = MessageRouter(registry);
      final called = <bool>[];
      router.on(MessageType.prompt, (id, frame, ws) async => called.add(true));

      final server = await HttpServer.bind('127.0.0.1', 0);
      final clientFuture = WebSocket.connect('ws://127.0.0.1:${server.port}/');
      final serverReq = await server.first;
      final serverWs = await WebSocketTransformer.upgrade(serverReq);
      final clientWs = await clientFuture;

      await router.dispatch('c1', 42, serverWs); // not a String

      expect(called, isEmpty);

      await serverWs.close();
      await clientWs.close();
      await server.close(force: true);
    });

    test('hasHandler returns true when registered', () {
      final router = MessageRouter(ClientRegistry());
      router.on(MessageType.config, (id, frame, ws) async {});
      expect(router.hasHandler(MessageType.config), isTrue);
      expect(router.hasHandler(MessageType.prompt), isFalse);
    });

    test('registry accessor returns the injected registry', () {
      final registry = ClientRegistry();
      final router = MessageRouter(registry);
      expect(router.registry, same(registry));
    });
  });
}
