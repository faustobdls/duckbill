import 'dart:io';
import 'package:duckbill_protocol/duckbill_protocol.dart';

import 'ai_suggestion.dart';
import 'execution_gate.dart';
import 'local_executor.dart';

/// Callback invoked for every line of output produced by the session.
typedef SessionOutputSink = void Function(String line);

/// Configuration received from the server when connecting.
class RemoteConfig {
  final String model;
  final String provider;
  final String? systemInstruction;

  const RemoteConfig({
    required this.model,
    required this.provider,
    this.systemInstruction,
  });

  static RemoteConfig fromJson(Map<String, dynamic> json) {
    return RemoteConfig(
      model: json['model'] as String? ?? 'unknown',
      provider: json['provider'] as String? ?? 'unknown',
      systemInstruction: json['system_instruction'] as String?,
    );
  }
}

/// Result of a single agent turn (one user message → AI response → execution).
class AgentTurnResult {
  final String prompt;
  final String rawResponse;
  final List<AiSuggestion> suggestions;
  final List<ExecutionResult> results;

  const AgentTurnResult({
    required this.prompt,
    required this.rawResponse,
    required this.suggestions,
    required this.results,
  });
}

/// Manages a single interactive session between the user and the remote AI.
///
/// Responsibilities (SRP):
/// - Send/receive [MessageFrame]s over a WebSocket.
/// - Parse [AiSuggestion]s from server responses.
/// - Delegate approval to [ExecutionGate].
/// - Delegate execution to [LocalExecutor].
///
/// Does NOT handle UI — that belongs to the presentation layer.
class AgentSession {
  final WebSocket _ws;
  final ExecutionGate _gate;
  final LocalExecutor _executor;
  final SessionOutputSink _output;

  RemoteConfig? _remoteConfig;

  AgentSession({
    required WebSocket ws,
    required ExecutionGate gate,
    required LocalExecutor executor,
    required SessionOutputSink output,
  })  : _ws = ws,
        _gate = gate,
        _executor = executor,
        _output = output;

  /// The model/provider config pushed by the server after handshake.
  RemoteConfig? get remoteConfig => _remoteConfig;

  /// Sends [prompt] to the server and processes the response.
  ///
  /// Returns the complete [AgentTurnResult] for this turn.
  Future<AgentTurnResult> sendPrompt(String prompt) async {
    final frame = MessageFrame.prompt(prompt);
    _ws.add(frame.toJsonString());

    final suggestions = <AiSuggestion>[];
    final results = <ExecutionResult>[];
    var rawResponse = '';

    await for (final raw in _ws) {
      if (raw is! String) continue;

      final frame = MessageFrame.fromJsonString(raw);
      if (frame == null) {
        _output(raw); // plain-text fallback
        rawResponse += raw;
        continue;
      }

      switch (frame.type) {
        case MessageType.config:
          _remoteConfig = RemoteConfig.fromJson(frame.payload);
          _output('[Config] Model: ${_remoteConfig!.model} (${_remoteConfig!.provider})');

        case MessageType.response:
          rawResponse = frame.payload['text'] as String? ?? '';
          _output('[AI] $rawResponse');
          suggestions.addAll(SuggestionParser.parse(rawResponse));

        case MessageType.suggestion:
          final parsed = _parseSuggestionFrame(frame.payload);
          if (parsed != null) {
            suggestions.add(parsed);
            final result = await _processOne(parsed);
            if (result != null) results.add(result);
          }

        case MessageType.streamEnd:
          // Flush any remaining suggestions accumulated from response frames.
          for (final s in suggestions.where((s) => !results.any((r) => r.suggestion == s))) {
            final result = await _processOne(s);
            if (result != null) results.add(result);
          }
          return AgentTurnResult(
            prompt: prompt,
            rawResponse: rawResponse,
            suggestions: suggestions,
            results: results,
          );

        case MessageType.error:
          _output('[Error] ${frame.payload['message'] ?? 'Unknown server error'}');
          return AgentTurnResult(
            prompt: prompt,
            rawResponse: rawResponse,
            suggestions: suggestions,
            results: results,
          );

        case MessageType.prompt:
          break; // Clients don't receive prompts back.
        case MessageType.executionResult:
          break; // Server may mirror results; ignore on client.
      }
    }

    return AgentTurnResult(
      prompt: prompt,
      rawResponse: rawResponse,
      suggestions: suggestions,
      results: results,
    );
  }

  Future<ExecutionResult?> _processOne(AiSuggestion suggestion) async {
    final gate = await _gate.evaluate(suggestion);
    if (gate.isCancelled) {
      _output('[Session] Cancelled by user.');
      return null;
    }
    if (!gate.isApproved) {
      _output('[Session] Skipped.');
      return null;
    }

    _output('[Executing] ${suggestion.value}');
    final result = await _executor.execute(suggestion);
    _printResult(result);

    // Send execution result back to server for context.
    _ws.add(MessageFrame.executionResult(
      exitCode: result.exitCode,
      stdout: result.stdout,
      stderr: result.stderr,
    ).toJsonString());

    return result;
  }

  void _printResult(ExecutionResult result) {
    if (result.stdout.isNotEmpty) _output('[stdout]\n${result.stdout.trim()}');
    if (result.stderr.isNotEmpty) _output('[stderr]\n${result.stderr.trim()}');
    _output('[exit: ${result.exitCode}] (${result.elapsed.inMilliseconds}ms)');
  }

  AiSuggestion? _parseSuggestionFrame(Map<String, dynamic> payload) {
    try {
      return AiSuggestion.fromJson(payload);
    } catch (_) {
      return null;
    }
  }

  Future<void> close() async {
    await _ws.close();
  }
}
