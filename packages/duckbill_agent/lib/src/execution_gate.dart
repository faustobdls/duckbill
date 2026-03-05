import 'ai_suggestion.dart';

/// Decision returned by an [ExecutionGate].
enum GateDecision {
  /// User approved the suggestion — proceed with execution.
  approved,

  /// User skipped this specific suggestion — do not execute.
  skipped,

  /// User cancelled the entire session — stop processing all further suggestions.
  cancelled,
}

/// Result of a gate evaluation.
class GateResult {
  final GateDecision decision;
  final AiSuggestion suggestion;

  const GateResult({required this.decision, required this.suggestion});

  bool get isApproved => decision == GateDecision.approved;
  bool get isCancelled => decision == GateDecision.cancelled;
}

/// Interface (Open/Closed Principle) for approving or rejecting AI suggestions.
///
/// Different implementations can use interactive prompts, auto-approve rules,
/// or test stubs — without changing [AgentSession].
abstract interface class ExecutionGate {
  /// Evaluates [suggestion] and returns a [GateResult].
  Future<GateResult> evaluate(AiSuggestion suggestion);
}

/// Auto-approves all suggestions. Useful for CI/automated pipelines.
class AutoApproveGate implements ExecutionGate {
  const AutoApproveGate();

  @override
  Future<GateResult> evaluate(AiSuggestion suggestion) async =>
      GateResult(decision: GateDecision.approved, suggestion: suggestion);
}

/// Rejects every suggestion. Useful for dry-run / preview modes.
class DryRunGate implements ExecutionGate {
  const DryRunGate();

  @override
  Future<GateResult> evaluate(AiSuggestion suggestion) async =>
      GateResult(decision: GateDecision.skipped, suggestion: suggestion);
}

/// Interactive gate that asks the user via stdin before each suggestion.
class InteractiveGate implements ExecutionGate {
  final void Function(String message) printer;
  final String Function() reader;

  const InteractiveGate({required this.printer, required this.reader});

  @override
  Future<GateResult> evaluate(AiSuggestion suggestion) async {
    printer('');
    printer('┌─ AI Suggestion ─────────────────────────────────');
    printer('│  Kind   : ${suggestion.kind.name}');
    printer('│  Value  : ${suggestion.value}');
    if (suggestion.explanation != null) {
      printer('│  Why    : ${suggestion.explanation}');
    }
    printer('└─────────────────────────────────────────────────');
    printer('[y] Approve  [s] Skip  [q] Quit → ');

    final input = reader().trim().toLowerCase();
    final decision = switch (input) {
      'y' || 'yes' => GateDecision.approved,
      'q' || 'quit' || 'exit' => GateDecision.cancelled,
      _ => GateDecision.skipped,
    };
    return GateResult(decision: decision, suggestion: suggestion);
  }
}
