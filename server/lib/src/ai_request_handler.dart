import 'dart:io';
import 'package:duckbill_ai/duckbill_ai.dart';
import 'package:duckbill_protocol/duckbill_protocol.dart';

/// Handles AI prompt requests received from a client.
///
/// SRP: only responsible for AI invocation and response framing.
/// Does NOT execute commands — returns structured suggestions to the client.
class AiRequestHandler {
  final AiProvider aiProvider;
  final String model;

  AiRequestHandler({required this.aiProvider, required this.model});

  /// Processes a [MessageType.prompt] frame and streams responses back to [socket].
  Future<void> handle(
    String clientId,
    MessageFrame frame,
    WebSocket socket,
  ) async {
    final promptText = frame.payload['text'] as String? ?? '';
    if (promptText.isEmpty) {
      socket.add(MessageFrame.error('Empty prompt received.').toJsonString());
      return;
    }

    try {
      final osInfo = Platform.operatingSystem + ' ' + Platform.operatingSystemVersion;
      final systemInstruction = _buildSystemInstruction(osInfo);

      final rawResponse = await aiProvider.generateContent(
        promptText,
        systemInstruction: systemInstruction,
      );

      // Try to parse structured suggestions first.
      final parsed = FunctionParser.parseFunctionCall(rawResponse);

      if (parsed != null && parsed.containsKey('command')) {
        // Single-command legacy format — wrap into suggestion frame.
        socket.add(MessageFrame.suggestion({
          'command': parsed['command'],
          'explanation': parsed['explanation'],
        }).toJsonString());
      } else {
        // Return raw response; client can parse SuggestionParser.
        socket.add(MessageFrame.response(rawResponse, model: model).toJsonString());
      }

      socket.add(MessageFrame.streamEnd().toJsonString());
    } catch (e) {
      socket.add(MessageFrame.error('AI error: $e').toJsonString());
      socket.add(MessageFrame.streamEnd().toJsonString());
    }
  }

  String _buildSystemInstruction(String osInfo) {
    return 'Você é o Duckbill, um assistente AI autônomo executando em $osInfo.\n'
        'O cliente que enviou este prompt executará os comandos LOCALMENTE na própria máquina.\n'
        'Responda com um JSON estruturado contendo uma ou mais sugestões.\n\n'
        'Para um único comando use:\n'
        '```json\n{"command": "comando_aqui", "explanation": "por quê"}\n```\n\n'
        'Para múltiplas sugestões use um array:\n'
        '```json\n'
        '[\n'
        '  {"command": "primeiro_comando", "explanation": "razão"},\n'
        '  {"explanation": "texto explicativo sem execução"}\n'
        ']\n'
        '```\n\n'
        'Para escrever arquivos use:\n'
        '```json\n{"file_path": "/caminho/arquivo", "file_content": "conteúdo", "explanation": "razão"}\n```\n\n'
        'Apenas JSON dentro de blocos de código. Nada mais.';
  }
}
