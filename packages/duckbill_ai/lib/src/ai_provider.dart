import 'dart:convert';
import 'package:http/http.dart' as http;

abstract class AiProvider {
  Future<String> generateContent(String prompt, {String? systemInstruction});
}

class GeminiAdapter implements AiProvider {
  final String apiKey;
  final String model;
  final http.Client client;

  GeminiAdapter({
    required this.apiKey, 
    this.model = 'gemini-3-flash-preview',
    http.Client? httpClient,
  }) : client = httpClient ?? http.Client();

  @override
  Future<String> generateContent(String prompt, {String? systemInstruction}) async {
    final url = Uri.parse('https://generativelanguage.googleapis.com/v1beta/models/$model:generateContent?key=$apiKey');
    
    final payload = {
      if (systemInstruction != null)
        'systemInstruction': {
          'parts': [{'text': systemInstruction}]
        },
      'contents': [
        {
          'role': 'user',
          'parts': [{'text': prompt}]
        }
      ],
      if (model.contains('gemini-3'))
        'generationConfig': {
          'thinkingConfig': {
            'thinkingLevel': 'HIGH'
          }
        }
    };

    final response = await client.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(payload),
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to generate content: ${response.body}');
    }

    final data = jsonDecode(response.body);
    try {
      return data['candidates'][0]['content']['parts'][0]['text'] as String;
    } catch (e) {
      throw Exception('Failed to parse Gemini response: $data');
    }
  }
}

class FunctionParser {
  /// Parses possible function calls from LLM output.
  /// Useful when the LLM is instructed to output JSON or specific syntax.
  static Map<String, dynamic>? parseFunctionCall(String text) {
    try {
      // Look for code blocks if LLM wrapped it
      final regex = RegExp(r'```json\s*(\{.*?\})\s*```', dotAll: true);
      final match = regex.firstMatch(text);
      if (match != null) {
        final jsonText = match.group(1)!;
        return jsonDecode(jsonText) as Map<String, dynamic>;
      }
      
      // Fallback: try to decode the whole text
      return jsonDecode(text.trim()) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }
}
