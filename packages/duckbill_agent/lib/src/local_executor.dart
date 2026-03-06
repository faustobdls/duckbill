import 'dart:io';
import 'ai_suggestion.dart';

/// Result of executing an [AiSuggestion] locally.
class ExecutionResult {
  final AiSuggestion suggestion;
  final int exitCode;
  final String stdout;
  final String stderr;
  final Duration elapsed;

  const ExecutionResult({
    required this.suggestion,
    required this.exitCode,
    required this.stdout,
    required this.stderr,
    required this.elapsed,
  });

  bool get isSuccess => exitCode == 0;

  @override
  String toString() =>
      'ExecutionResult(exitCode: $exitCode, elapsed: ${elapsed.inMilliseconds}ms)';
}

/// Interface (SRP + DIP) for executing AI suggestions on the local machine.
abstract interface class LocalExecutor {
  /// Executes [suggestion] and returns an [ExecutionResult].
  Future<ExecutionResult> execute(AiSuggestion suggestion);
}

/// Executes shell commands and file writes directly on the host OS.
class HostLocalExecutor implements LocalExecutor {
  /// Overridable for tests.
  final Future<ProcessResult> Function(String command)? processRunOverride;

  const HostLocalExecutor({this.processRunOverride});

  @override
  Future<ExecutionResult> execute(AiSuggestion suggestion) async {
    final start = DateTime.now();

    switch (suggestion.kind) {
      case SuggestionKind.command:
        return _runCommand(suggestion, start);
      case SuggestionKind.fileWrite:
        return _writeFile(suggestion, start);
      case SuggestionKind.explanation:
        return ExecutionResult(
          suggestion: suggestion,
          exitCode: 0,
          stdout: suggestion.value,
          stderr: '',
          elapsed: DateTime.now().difference(start),
        );
    }
  }

  Future<ExecutionResult> _runCommand(AiSuggestion suggestion, DateTime start) async {
    try {
      final runner = processRunOverride ?? _defaultRun;
      final result = await runner(suggestion.value);
      return ExecutionResult(
        suggestion: suggestion,
        exitCode: result.exitCode,
        stdout: result.stdout.toString(),
        stderr: result.stderr.toString(),
        elapsed: DateTime.now().difference(start),
      );
    } catch (e) {
      return ExecutionResult(
        suggestion: suggestion,
        exitCode: -1,
        stdout: '',
        stderr: 'Exception: $e',
        elapsed: DateTime.now().difference(start),
      );
    }
  }

  Future<ExecutionResult> _writeFile(AiSuggestion suggestion, DateTime start) async {
    try {
      final file = File(suggestion.value);
      await file.parent.create(recursive: true);
      await file.writeAsString(suggestion.secondaryValue ?? '');
      return ExecutionResult(
        suggestion: suggestion,
        exitCode: 0,
        stdout: 'File written: ${suggestion.value}',
        stderr: '',
        elapsed: DateTime.now().difference(start),
      );
    } catch (e) {
      return ExecutionResult(
        suggestion: suggestion,
        exitCode: -1,
        stdout: '',
        stderr: 'Failed to write file: $e',
        elapsed: DateTime.now().difference(start),
      );
    }
  }

  static Future<ProcessResult> _defaultRun(String command) =>
      Process.run('bash', ['-c', command]);
}
