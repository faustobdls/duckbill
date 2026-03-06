import 'ansi_styles.dart';

/// A single message in the chat history.
class ChatMessage {
  final ChatRole role;
  final String content;
  final DateTime timestamp;

  ChatMessage({
    required this.role,
    required this.content,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();
}

/// Who sent a [ChatMessage].
enum ChatRole { user, assistant, system }

/// Renders a Claude-Code-style chat interface in the terminal.
///
/// Presentation concern only — depends on [AnsiStyles] and injectable I/O.
class ChatInterface {
  final void Function(String) printer;
  final String Function() reader;
  final String agentName;

  final List<ChatMessage> _history = [];

  ChatInterface({
    required this.printer,
    required this.reader,
    this.agentName = 'Duckbill',
  });

  List<ChatMessage> get history => List.unmodifiable(_history);

  /// Renders the chat header.
  void printHeader() {
    printer('');
    printer(DuckbillTheme.separator());
    printer(DuckbillTheme.header('  🦆 $agentName — AI Agent'));
    printer(DuckbillTheme.muted('  Type your prompt. Ctrl+C or "exit" to quit.'));
    printer(DuckbillTheme.separator());
  }

  /// Reads a prompt from the user and adds it to history.
  ///
  /// Returns null if the user typed 'exit' or 'quit'.
  String? readPrompt() {
    printer('');
    printer('${Ansi.bold}${Ansi.brightGreen}you${Ansi.reset} › ');
    final input = reader().trim();
    if (input.isEmpty) return '';
    if (input.toLowerCase() == 'exit' || input.toLowerCase() == 'quit') {
      return null;
    }
    _history.add(ChatMessage(role: ChatRole.user, content: input));
    return input;
  }

  /// Prints a system-level status message (not stored in history).
  void printStatus(String message) {
    printer(DuckbillTheme.muted('  ⠿ $message'));
  }

  /// Prints a structured AI response and stores it in history.
  void printAssistantMessage(String content) {
    _history.add(ChatMessage(role: ChatRole.assistant, content: content));
    printer('');
    printer('${Ansi.bold}${Ansi.brightBlue}$agentName${Ansi.reset} › ');
    for (final line in content.split('\n')) {
      printer(DuckbillTheme.aiMessage('  $line'));
    }
  }

  /// Prints a suggestion block with visual emphasis.
  void printSuggestion({
    required String kind,
    required String value,
    String? explanation,
  }) {
    printer('');
    printer(DuckbillTheme.separator(50));
    printer(DuckbillTheme.warning('  ⚡ Suggestion [${kind.toUpperCase()}]'));
    printer('  ${DuckbillTheme.highlight(value)}');
    if (explanation != null) {
      printer(DuckbillTheme.muted('  $explanation'));
    }
    printer(DuckbillTheme.separator(50));
  }

  /// Prints the result of a local execution.
  void printExecutionResult({
    required int exitCode,
    required String stdout,
    required String stderr,
    required int elapsedMs,
  }) {
    if (stdout.isNotEmpty) {
      printer('');
      printer(DuckbillTheme.muted('  [stdout]'));
      for (final line in stdout.trim().split('\n')) {
        printer('  $line');
      }
    }
    if (stderr.isNotEmpty) {
      printer('');
      printer(DuckbillTheme.error('  [stderr]'));
      for (final line in stderr.trim().split('\n')) {
        printer(DuckbillTheme.error('  $line'));
      }
    }
    final statusMsg = exitCode == 0
        ? DuckbillTheme.success('  ✓ exit $exitCode')
        : DuckbillTheme.error('  ✗ exit $exitCode');
    printer('$statusMsg  ${DuckbillTheme.muted('(${elapsedMs}ms)')}');
  }

  /// Prints an error message.
  void printError(String message) {
    printer(DuckbillTheme.error('  ✗ $message'));
  }
}
