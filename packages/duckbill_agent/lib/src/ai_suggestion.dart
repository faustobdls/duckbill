import 'dart:convert';

/// The kind of action the AI is suggesting.
enum SuggestionKind {
  /// Execute a shell command.
  command,

  /// Write content to a file.
  fileWrite,

  /// Informational text explanation — nothing to execute.
  explanation,
}

/// An immutable value object representing a single AI suggestion.
///
/// Clean Architecture domain object with no external dependencies.
class AiSuggestion {
  final SuggestionKind kind;
  final String value;
  final String? explanation;

  /// Only set when [kind] == [SuggestionKind.fileWrite]; holds file contents.
  final String? secondaryValue;

  const AiSuggestion({
    required this.kind,
    required this.value,
    this.explanation,
    this.secondaryValue,
  });

  const AiSuggestion.command(String command, {String? explanation})
      : kind = SuggestionKind.command,
        value = command,
        explanation = explanation,
        secondaryValue = null;

  const AiSuggestion.fileWrite(String path, String content, {String? explanation})
      : kind = SuggestionKind.fileWrite,
        value = path,
        explanation = explanation,
        secondaryValue = content;

  const AiSuggestion.explanation(String text)
      : kind = SuggestionKind.explanation,
        value = text,
        explanation = null,
        secondaryValue = null;

  /// Parses a JSON map into an [AiSuggestion]. Returns null on unrecognised shape.
  static AiSuggestion? fromJson(Map<String, dynamic> json) {
    if (json.containsKey('command')) {
      return AiSuggestion.command(
        json['command'] as String,
        explanation: json['explanation'] as String?,
      );
    }
    if (json.containsKey('file_path') && json.containsKey('file_content')) {
      return AiSuggestion.fileWrite(
        json['file_path'] as String,
        json['file_content'] as String,
        explanation: json['explanation'] as String?,
      );
    }
    if (json.containsKey('explanation')) {
      return AiSuggestion.explanation(json['explanation'] as String);
    }
    return null;
  }

  Map<String, dynamic> toJson() {
    return switch (kind) {
      SuggestionKind.command => {
          'kind': 'command',
          'value': value,
          if (explanation != null) 'explanation': explanation,
        },
      SuggestionKind.fileWrite => {
          'kind': 'file_write',
          'file_path': value,
          'file_content': secondaryValue ?? '',
          if (explanation != null) 'explanation': explanation,
        },
      SuggestionKind.explanation => {
          'kind': 'explanation',
          'value': value,
        },
    };
  }

  @override
  String toString() => 'AiSuggestion(kind: $kind, value: $value)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AiSuggestion &&
          kind == other.kind &&
          value == other.value &&
          explanation == other.explanation &&
          secondaryValue == other.secondaryValue;

  @override
  int get hashCode => Object.hash(kind, value, explanation, secondaryValue);
}

/// Parses raw AI text into a list of [AiSuggestion]s.
///
/// Understands both single-object and array JSON, optionally wrapped in
/// markdown code fences (``` json ... ```).
class SuggestionParser {
  SuggestionParser._();

  static final _mdBlockRegex =
      RegExp(r'```(?:json)?\s*(\[.*?\]|\{.*?\})\s*```', dotAll: true);

  static List<AiSuggestion> parse(String text) {
    final raw = _extractJson(text);
    if (raw == null) return [];

    try {
      final decoded = jsonDecode(raw);
      if (decoded is List) {
        return decoded
            .whereType<Map<String, dynamic>>()
            .map(AiSuggestion.fromJson)
            .whereType<AiSuggestion>()
            .toList();
      }
      if (decoded is Map<String, dynamic>) {
        final s = AiSuggestion.fromJson(decoded);
        return s != null ? [s] : [];
      }
    } catch (_) {}
    return [];
  }

  static String? _extractJson(String text) {
    final match = _mdBlockRegex.firstMatch(text);
    if (match != null) return match.group(1);
    final trimmed = text.trim();
    if (trimmed.startsWith('{') || trimmed.startsWith('[')) return trimmed;
    return null;
  }
}
