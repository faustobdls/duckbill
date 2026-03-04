import 'dart:io';
import 'package:duckbill_protocol/src/security.dart';

class DuckbillTunnel {
  final DuckbillSecurity security;

  DuckbillTunnel(String secretToken) : security = DuckbillSecurity(secretToken);

  /// Helper to start a secure WebSocket Server with TLS pinning/support
  static Future<HttpServer> startServer({
    required String address,
    required int port,
    SecurityContext? securityContext,
  }) async {
    if (securityContext != null) {
      return await HttpServer.bindSecure(address, port, securityContext);
    }
    // Using simple binding without TLS only for local/development if context is null
    return await HttpServer.bind(address, port);
  }

  /// Helper to map HTTP request to WebSocket with token checks
  static Future<WebSocket?> upgradeRequest(
    HttpRequest request,
    DuckbillSecurity security,
  ) async {
    // 1. Check Bearer Token in Headers or URL params
    final authHeader = request.headers.value(HttpHeaders.authorizationHeader);
    if (authHeader == null || !authHeader.startsWith('Bearer ')) {
      request.response.statusCode = HttpStatus.unauthorized;
      await request.response.close();
      return null;
    }

    final token = authHeader.substring(7);
    // Simple direct token match check for handshake
    if (token != security.secretToken) {
      request.response.statusCode = HttpStatus.unauthorized;
      await request.response.close();
      return null;
    }

    // 2. Upgrade to WebSocket
    return await WebSocketTransformer.upgrade(request);
  }
}
