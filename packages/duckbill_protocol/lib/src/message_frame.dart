import 'dart:convert';

/// All message types exchanged over the Duckbill WebSocket channel.
enum MessageType {
  /// Client → Server: user's prompt text.
  prompt,

  /// Server → Client: AI-generated response.
  response,

  /// Server → Client: a structured AI suggestion ready for execution.
  suggestion,

  /// Client → Server: result of a locally executed suggestion.
  executionResult,

  /// Server → Client: AI/model configuration pushed after connection.
  config,

  /// Server → Client: signals the end of a response stream.
  streamEnd,

  /// Either direction: error information.
  error,
}

/// A typed, JSON-serialisable envelope for all WebSocket messages.
///
/// Using structured frames (instead of plain strings) enables:
/// - Type-safe routing on the server ([MessageRouter]).
/// - Versioning and forward-compatible extension.
/// - Clean separation of metadata (type, timestamp) from payload.
class MessageFrame {
  final MessageType type;
  final Map<String, dynamic> payload;
  final int timestampMs;

  MessageFrame({
    required this.type,
    required this.payload,
    int? timestampMs,
  }) : timestampMs = timestampMs ?? DateTime.now().millisecondsSinceEpoch;

  // ─── Factory constructors ───────────────────────────────────────────────────

  factory MessageFrame.prompt(String text) => MessageFrame(
        type: MessageType.prompt,
        payload: {'text': text},
      );

  factory MessageFrame.response(String text, {String? model}) => MessageFrame(
        type: MessageType.response,
        payload: {
          'text': text,
          'model': ?model,
        },
      );

  factory MessageFrame.suggestion(Map<String, dynamic> suggestionJson) =>
      MessageFrame(
        type: MessageType.suggestion,
        payload: suggestionJson,
      );

  factory MessageFrame.executionResult({
    required int exitCode,
    required String stdout,
    required String stderr,
  }) =>
      MessageFrame(
        type: MessageType.executionResult,
        payload: {
          'exit_code': exitCode,
          'stdout': stdout,
          'stderr': stderr,
        },
      );

  factory MessageFrame.config({
    required String model,
    required String provider,
    String? systemInstruction,
  }) =>
      MessageFrame(
        type: MessageType.config,
        payload: {
          'model': model,
          'provider': provider,
          'system_instruction': ?systemInstruction,
        },
      );

  factory MessageFrame.streamEnd() =>
      MessageFrame(type: MessageType.streamEnd, payload: {});

  factory MessageFrame.error(String message) => MessageFrame(
        type: MessageType.error,
        payload: {'message': message},
      );

  // ─── Serialisation ──────────────────────────────────────────────────────────

  Map<String, dynamic> toJson() => {
        'type': type.name,
        'payload': payload,
        'ts': timestampMs,
      };

  String toJsonString() => jsonEncode(toJson());

  /// Returns null if [raw] is not a valid [MessageFrame] JSON string.
  static MessageFrame? fromJsonString(String raw) {
    try {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      return fromJson(decoded);
    } catch (_) {
      return null;
    }
  }

  static MessageFrame? fromJson(Map<String, dynamic> json) {
    try {
      final typeStr = json['type'] as String;
      final type = MessageType.values.firstWhere((e) => e.name == typeStr);
      final payload = (json['payload'] as Map<String, dynamic>?) ?? {};
      final ts = json['ts'] as int?;
      return MessageFrame(type: type, payload: payload, timestampMs: ts);
    } catch (_) {
      return null;
    }
  }

  @override
  String toString() => 'MessageFrame(type: $type, ts: $timestampMs)';
}
