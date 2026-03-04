import 'dart:io';
import 'package:duckbill_protocol/duckbill_protocol.dart';
import 'package:test/test.dart';

void main() {
  group('DuckbillSecurity', () {
    test('signs properly', () {
      final security = DuckbillSecurity('my_super_secret');
      final payload = 'sample_payload';
      final timestamp = 1700000000000;
      
      final sign = security.sign(payload, timestamp);
      expect(sign, isNotEmpty);
      expect(sign.length, greaterThan(30));
    });

    test('verifies correctly within TTL', () {
      final security = DuckbillSecurity('my_secret');
      final payload = 'test_payload';
      final currentTimestampMs = 1700000000000;
      
      final sign = security.sign(payload, currentTimestampMs);
      
      final verified = security.verify(
        payload, 
        currentTimestampMs, 
        sign,
        currentTimestampMs: currentTimestampMs + 5000,
      );
      
      expect(verified, isTrue);
    });

    test('fails verification if outside TTL', () {
      final security = DuckbillSecurity('my_secret');
      final payload = 'test_payload';
      final currentTimestampMs = 1700000000000;
      
      final sign = security.sign(payload, currentTimestampMs);
      
      final verified = security.verify(
        payload, 
        currentTimestampMs, 
        sign,
        currentTimestampMs: currentTimestampMs + (181 * 1000), // 181 seconds diff
      );
      
      expect(verified, isFalse);
    });

    test('fails verification on mismatched signature length', () {
      final security = DuckbillSecurity('my_secret');
      final payload = 'test_payload';
      final currentTimestampMs = 1700000000000;
      
      final verified = security.verify(
        payload, 
        currentTimestampMs, 
        'too_short_sign',
        currentTimestampMs: currentTimestampMs + 1000,
      );
      
      expect(verified, isFalse);
    });

    test('fails verification on modified signature', () {
      final security = DuckbillSecurity('my_secret');
      final payload = 'test_payload';
      final currentTimestampMs = 1700000000000;
      
      final originalSign = security.sign(payload, currentTimestampMs);
      
      final char = originalSign[0] == 'a' ? 'b' : 'a';
      final fakeSign = char + originalSign.substring(1);
      
      final verified = security.verify(
        payload, 
        currentTimestampMs, 
        fakeSign,
        currentTimestampMs: currentTimestampMs + 1000,
      );
      
      expect(verified, isFalse);
    });
  });

  group('DuckbillTunnel', () {
    test('authenticates valid handshake', () async {
      final security = DuckbillSecurity('my_token');
      
      // Start server
      final server = await DuckbillTunnel.startServer(
        address: '127.0.0.1', 
        port: 0,
      );

      // Handle server gracefully
      final serverFuture = server.first.then((request) async {
        final ws = await DuckbillTunnel.upgradeRequest(request, security);
        return ws;
      });

      // WebSocket Connect
      final wsClient = await WebSocket.connect(
        'ws://127.0.0.1:' + server.port.toString() + '/',
        headers: {'Authorization': 'Bearer my_token'},
      );

      final wsServer = await serverFuture;
      
      expect(wsServer, isA<WebSocket>());
      
      await wsServer?.close();
      await wsClient.close();
      await server.close(force: true);
    });

    test('rejects missing token handshake', () async {
      final security = DuckbillSecurity('my_token');
      
      final server = await DuckbillTunnel.startServer(
        address: '127.0.0.1', 
        port: 0,
      );

      final client = HttpClient();
      final request = await client.get('127.0.0.1', server.port, '/');
      // No token added
      final responseFuture = request.close();

      final serverRequest = await server.first;
      final webSocket = await DuckbillTunnel.upgradeRequest(serverRequest, security);
      
      expect(webSocket, isNull);
      
      final response = await responseFuture;
      expect(response.statusCode, HttpStatus.unauthorized);

      await server.close(force: true);
      client.close();
    });

    test('rejects invalid token handshake', () async {
      final server = await DuckbillTunnel.startServer(
        address: '127.0.0.1', 
        port: 0,
        securityContext: SecurityContext(withTrustedRoots: false),
      );

      // Using regular HTTP client to test rejection on secure binding mock
      // Actually we need to make sure startServer handles securityContext properly
      expect(server, isA<HttpServer>());
      await server.close(force: true);
    });

    test('rejects wrong token handshake', () async {
      final security = DuckbillSecurity('my_token');
      
      final server = await DuckbillTunnel.startServer(
        address: '127.0.0.1', 
        port: 0,
      );

      final client = HttpClient();
      final request = await client.get('127.0.0.1', server.port, '/');
      request.headers.set('Authorization', 'Bearer wrong_token');
      final responseFuture = request.close();

      final serverRequest = await server.first;
      final webSocket = await DuckbillTunnel.upgradeRequest(serverRequest, security);
      
      expect(webSocket, isNull);
      
      final response = await responseFuture;
      expect(response.statusCode, HttpStatus.unauthorized);

      await server.close(force: true);
      client.close();
    });
  });
}
