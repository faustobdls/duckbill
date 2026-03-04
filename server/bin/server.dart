import 'dart:io';
import 'package:server/server.dart';

void main(List<String> arguments) async {
  final apiKey = Platform.environment['GEMINI_API_KEY'];
  if (apiKey == null || apiKey.isEmpty) {
    print('Missing GEMINI_API_KEY env var.');
    exit(1);
  }

  final model = Platform.environment['GEMINI_MODEL'] ?? 'gemini-3-flash-preview';

  print('Starting Duckbill Server...');
  final server = await DuckbillServer.initialize(
    dbPath: 'duckbill_server.sqlite',
    apiKey: apiKey,
    model: model,
  );

  await server.start(address: '0.0.0.0', port: 8080);
}
