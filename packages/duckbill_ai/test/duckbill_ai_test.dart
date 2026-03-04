import 'dart:convert';
import 'package:duckbill_ai/duckbill_ai.dart';
import 'package:http/http.dart' as http;
import 'package:test/test.dart';

class MockHttpClient extends http.BaseClient {
  final Future<http.StreamedResponse> Function(http.BaseRequest request) handler;

  MockHttpClient(this.handler);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    return handler(request);
  }
}

void main() {
  group('GeminiAdapter', () {
    test('sends request and parses valid response', () async {
      final mockClient = MockHttpClient((request) async {
        final Map<String, dynamic> responseData = {
          'candidates': [
            {
              'content': {
                'parts': [
                  {'text': 'Hello world'}
                ]
              }
            }
          ]
        };
        final response = http.Response(jsonEncode(responseData), 200);
        
        return http.StreamedResponse(
          Stream.value(response.bodyBytes),
          response.statusCode,
        );
      });

      final adapter = GeminiAdapter(apiKey: 'TEST', httpClient: mockClient);
      final text = await adapter.generateContent('Say hi');
      expect(text, equals('Hello world'));
    });

    test('throws exception on non-200 status', () async {
      final mockClient = MockHttpClient((request) async {
        final response = http.Response('Error', 400);
        return http.StreamedResponse(
          Stream.value(response.bodyBytes),
          response.statusCode,
        );
      });

      final adapter = GeminiAdapter(apiKey: 'TEST', httpClient: mockClient);
      
      expect(
        () async => await adapter.generateContent('Say hi'),
        throwsException,
      );
    });

    test('throws exception on invalid response format', () async {
      final mockClient = MockHttpClient((request) async {
        final response = http.Response('{"invalid": true}', 200);
        return http.StreamedResponse(
          Stream.value(response.bodyBytes),
          response.statusCode,
        );
      });

      final adapter = GeminiAdapter(apiKey: 'TEST', httpClient: mockClient);
      
      expect(
        () async => await adapter.generateContent('Say hi'),
        throwsException,
      );
    });
  });

  group('FunctionParser', () {
    test('parses markdown json block', () {
      final text = '''Here is the function call:
```json
{"method": "test"}
```
End of response.''';
      final parsed = FunctionParser.parseFunctionCall(text);
      expect(parsed, isNotNull);
      expect(parsed!['method'], equals('test'));
    });

    test('parses pure json', () {
      final text = '{"method": "test2"}';
      final parsed = FunctionParser.parseFunctionCall(text);
      expect(parsed, isNotNull);
      expect(parsed!['method'], equals('test2'));
    });

    test('returns null on invalid input', () {
      final text = 'No json here';
      final parsed = FunctionParser.parseFunctionCall(text);
      expect(parsed, isNull);
    });
  });
}
