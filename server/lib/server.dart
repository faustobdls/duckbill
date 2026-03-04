import 'dart:io';
import 'package:duckbill_ai/duckbill_ai.dart';
import 'package:duckbill_crypto/duckbill_crypto.dart';
import 'package:duckbill_protocol/duckbill_protocol.dart';
import 'package:duckbill_storage/duckbill_storage.dart';

class DuckbillServer {
  final SqliteDbManager db;
  final DuckbillSecurity security;
  final AiProvider aiProvider;
  
  HttpServer? _server;

  DuckbillServer._(this.db, this.security, this.aiProvider);

  static Future<DuckbillServer> initialize({
    required String dbPath,
    required String apiKey,
    String model = 'gemini-3-flash-preview',
  }) async {
    final db = SqliteDbManager.init(dbPath);
    
    // Load Token or generate for tunnel
    var token = await CryptoManager.getEncryptedPat();
    if (token == null) {
      // for demo, the token can just be a known string or randomly generated base64
      token = 'generated_secret_token';
      await CryptoManager.saveEncryptedPat(token);
    }

    final security = DuckbillSecurity(token);
    final aiProvider = GeminiAdapter(apiKey: apiKey, model: model);

    // Initial DB setup
    db.execute('CREATE TABLE IF NOT EXISTS agents (id INTEGER PRIMARY KEY, name TEXT)');

    return DuckbillServer._(db, security, aiProvider);
  }

  Future<void> start({String address = '0.0.0.0', int port = 8080}) async {
    _server = await DuckbillTunnel.startServer(address: address, port: port);
    print('Duckbill Server started on ' + address + ':' + port.toString() + ' [Model: ' + (aiProvider as GeminiAdapter).model + ']');

    await for (final request in _server!) {
      final ws = await DuckbillTunnel.upgradeRequest(request, security);
      if (ws == null) {
        continue; // unauthorized or failed upgrade handled internally
      }
      
      _handleWebSocket(ws);
    }
  }

  void _handleWebSocket(WebSocket ws) {
    ws.listen(
      (data) async {
        print('Client connected');
        try {
          if (data is String) {
            final osInfo = Platform.operatingSystem + ' ' + Platform.operatingSystemVersion;
            final sysInstruction = 'Você é o Duckbill, um servidor AI autônomo executando localmente em ' + osInfo + '.\n'
                'A intenção do usuário é executar um comando. Responda APENAS com um bloco JSON (em markdown) contendo o comando shell exato para executar.\n'
                'Formato:\n'
                '```json\n{"command": "comando_aqui"}\n```\n'
                'Não adicione mais nenhum texto. Apenas o JSON.';

            ws.add('[Server] Consultando LLM sobre como executar sua intenção...');
            final response = await aiProvider.generateContent(
              data,
              systemInstruction: sysInstruction,
            );

            final parsed = FunctionParser.parseFunctionCall(response);
            if (parsed != null && parsed.containsKey('command')) {
              final cmd = parsed['command'] as String;
              ws.add('[Server] Inteligência sugeriu e e o servidor executará: ' + cmd + '\n' + '-' * 30);
              
              try {
                // Execute using bash
                final result = await Process.run('bash', ['-c', cmd]);
                
                if (result.stdout.toString().isNotEmpty) {
                  ws.add('[Stdout]\n' + result.stdout.toString().trim());
                }
                
                if (result.stderr.toString().isNotEmpty) {
                  ws.add('[Stderr]\n' + result.stderr.toString().trim());
                }
                
                ws.add('-' * 30 + '\n[Server] Execução concluída.');

              } catch (e) {
                ws.add('[Error] Falha ao rodar sub-processo: ' + e.toString());
              }
            } else {
              // Fallback se a LLM ignorou o JSON e retornou texto nativo
              ws.add('AI Resposta: ' + response);
            }
          }
        } catch (e) {
          ws.add('Error: ' + e.toString());
        }
      },
      onDone: () => print('Client disconnected'),
      onError: (e) => print('Error from client: ' + e.toString()),
    );
  }

  Future<void> stop() async {
    db.dispose();
    await _server?.close(force: true);
  }
}
