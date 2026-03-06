/// ANSI escape-code constants for terminal styling.
///
/// Keep purely as constants — no I/O in this layer.
abstract final class Ansi {
  // Reset
  static const reset = '\x1B[0m';

  // Text colours
  static const black = '\x1B[30m';
  static const red = '\x1B[31m';
  static const green = '\x1B[32m';
  static const yellow = '\x1B[33m';
  static const blue = '\x1B[34m';
  static const magenta = '\x1B[35m';
  static const cyan = '\x1B[36m';
  static const white = '\x1B[37m';
  static const brightBlack = '\x1B[90m';
  static const brightRed = '\x1B[91m';
  static const brightGreen = '\x1B[92m';
  static const brightYellow = '\x1B[93m';
  static const brightBlue = '\x1B[94m';
  static const brightMagenta = '\x1B[95m';
  static const brightCyan = '\x1B[96m';
  static const brightWhite = '\x1B[97m';

  // Text styles
  static const bold = '\x1B[1m';
  static const dim = '\x1B[2m';
  static const italic = '\x1B[3m';
  static const underline = '\x1B[4m';

  // Cursor / screen control
  static const clearScreen = '\x1B[2J\x1B[H';
  static const clearLine = '\x1B[2K\r';
  static const hideCursor = '\x1B[?25l';
  static const showCursor = '\x1B[?25h';

  // Helpers
  static String colorize(String text, String color) => '$color$text$reset';
  static String bold_(String text) => '$bold$text$reset';
  static String dim_(String text) => '$dim$text$reset';
}

/// High-level semantic styles used across Duckbill UI components.
abstract final class DuckbillTheme {
  static String header(String text) => Ansi.colorize(Ansi.bold_(text), Ansi.cyan);
  static String success(String text) => Ansi.colorize(text, Ansi.brightGreen);
  static String warning(String text) => Ansi.colorize(text, Ansi.brightYellow);
  static String error(String text) => Ansi.colorize(text, Ansi.brightRed);
  static String muted(String text) => Ansi.colorize(text, Ansi.brightBlack);
  static String highlight(String text) => Ansi.colorize(text, Ansi.brightCyan);
  static String selected(String text) => Ansi.colorize('▶ $text', Ansi.brightGreen);
  static String normal(String text) => '  $text';
  static String aiMessage(String text) => Ansi.colorize(text, Ansi.brightBlue);
  static String userMessage(String text) => Ansi.colorize(text, Ansi.brightWhite);
  static String separator([int width = 60]) =>
      Ansi.colorize('─' * width, Ansi.brightBlack);
}
