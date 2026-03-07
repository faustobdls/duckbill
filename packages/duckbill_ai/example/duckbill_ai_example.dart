import 'package:duckbill_ai/duckbill_ai.dart';

Future<void> main() async {
  final adapter = GeminiAdapter(apiKey: 'TEST');
  print(adapter.model);
}
