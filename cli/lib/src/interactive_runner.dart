import 'dart:io';
import 'package:duckbill_agent/duckbill_agent.dart';
import 'package:duckbill_console/duckbill_console.dart';
import 'package:duckbill_crypto/duckbill_crypto.dart';

import 'version.dart';
import 'updater.dart';

/// Presentation-layer orchestrator for all interactive CLI flows.
///
/// Bridges [duckbill_console] UI components with [duckbill_agent] logic.
/// SRP: only responsible for wiring user I/O to the agent session.
abstract final class InteractiveRunner {
  // ─── Main menu ─────────────────────────────────────────────────────────────

  static Future<void> showMainMenu() async {
    _print(Ansi.clearScreen);
    _print(DuckbillTheme.header('  🦆  Duckbill v$duckbillVersion'));
    _print(DuckbillTheme.muted('  Privacy-first AI orchestration'));

    final menu = InteractiveMenu(
      title: 'Main Menu',
      items: const [
        MenuItem(key: 'interactive', label: 'Interactive AI Session', description: 'Chat with AI and execute suggestions'),
        MenuItem(key: 'run',         label: 'Run Single Prompt',      description: 'Send one prompt and exit'),
        MenuItem(key: 'login',       label: 'Save Auth Token',        description: 'Store your PAT securely'),
        MenuItem(key: 'server',      label: 'Start Server',           description: 'Launch the Duckbill WebSocket server'),
        MenuItem(key: 'version',     label: 'Version Info',           description: 'Show version and platform'),
        MenuItem(key: 'update',      label: 'Update',                 description: 'Self-update the binary'),
      ],
      printer: _print,
      reader: _readLine,
    );

    final loop = MenuLoop(
      menu: menu,
      onSelected: _onMenuSelected,
      printer: _print,
    );

    await loop.run();
  }

  static Future<void> _onMenuSelected(String key) async {
    switch (key) {
      case 'interactive':
        await _promptForInteractiveSession();
      case 'run':
        await _promptForSingleRun();
      case 'login':
        await _promptForLogin();
      case 'server':
        await _promptForServerStart();
      case 'version':
        _printVersion();
      case 'update':
        await _runUpdate();
    }
  }

  // ─── Interactive AI session ────────────────────────────────────────────────

  static Future<void> _promptForInteractiveSession() async {
    _print('');
    _print(DuckbillTheme.muted('  Server URL [ws://127.0.0.1:8080]: '));
    final serverUrl = _readLine().trim();
    final url = serverUrl.isEmpty ? 'ws://127.0.0.1:8080' : serverUrl;

    _print(DuckbillTheme.muted('  Auto-approve suggestions? [y/N]: '));
    final autoApprove = _readLine().trim().toLowerCase() == 'y';

    final token = await _requireToken();
    if (token == null) return;

    await runInteractiveSession(serverUrl: url, token: token, autoApprove: autoApprove);
  }

  /// Runs a full multi-turn interactive agent session.
  static Future<void> runInteractiveSession({
    required String serverUrl,
    required String token,
    bool autoApprove = false,
  }) async {
    final chat = ChatInterface(printer: _print, reader: _readLine);
    chat.printHeader();

    WebSocket? ws;
    try {
      ws = await WebSocket.connect(
        '$serverUrl/',
        headers: {'Authorization': 'Bearer $token'},
      );
    } catch (e) {
      _print(DuckbillTheme.error('  [Error] Cannot connect to $serverUrl : $e'));
      return;
    }

    final gate = autoApprove
        ? const AutoApproveGate() as ExecutionGate
        : InteractiveGate(printer: _print, reader: _readLine);

    final session = AgentSession(
      ws: ws,
      gate: gate,
      executor: const HostLocalExecutor(),
      output: _print,
    );

    while (true) {
      final prompt = chat.readPrompt();
      if (prompt == null) {
        _print(DuckbillTheme.muted('  Ending session…'));
        break;
      }
      if (prompt.isEmpty) continue;

      chat.printStatus('Sending to AI…');

      try {
        final result = await session.sendPrompt(prompt);

        if (result.rawResponse.isNotEmpty && result.suggestions.isEmpty) {
          chat.printAssistantMessage(result.rawResponse);
        }

        for (final r in result.results) {
          chat.printExecutionResult(
            exitCode: r.exitCode,
            stdout: r.stdout,
            stderr: r.stderr,
            elapsedMs: r.elapsed.inMilliseconds,
          );
        }
      } catch (e) {
        chat.printError('Session error: $e');
        break;
      }
    }

    await session.close();
  }

  // ─── Single prompt ─────────────────────────────────────────────────────────

  static Future<void> _promptForSingleRun() async {
    _print('');
    _print(DuckbillTheme.muted('  Prompt: '));
    final prompt = _readLine().trim();
    if (prompt.isEmpty) return;

    _print(DuckbillTheme.muted('  Server URL [ws://127.0.0.1:8080]: '));
    final serverUrl = _readLine().trim();
    final url = serverUrl.isEmpty ? 'ws://127.0.0.1:8080' : serverUrl;

    _print(DuckbillTheme.muted('  Auto-approve? [y/N]: '));
    final autoApprove = _readLine().trim().toLowerCase() == 'y';

    final token = await _requireToken();
    if (token == null) return;

    await runSinglePrompt(serverUrl: url, token: token, prompt: prompt, autoApprove: autoApprove);
  }

  /// Sends a single prompt and exits.
  static Future<void> runSinglePrompt({
    required String serverUrl,
    required String token,
    required String prompt,
    bool autoApprove = false,
  }) async {
    WebSocket? ws;
    try {
      ws = await WebSocket.connect(
        '$serverUrl/',
        headers: {'Authorization': 'Bearer $token'},
      );
    } catch (e) {
      _print('[Error] Failed to connect to server at $serverUrl : $e');
      return;
    }

    final gate = autoApprove
        ? const AutoApproveGate() as ExecutionGate
        : InteractiveGate(printer: _print, reader: _readLine);

    final session = AgentSession(
      ws: ws,
      gate: gate,
      executor: const HostLocalExecutor(),
      output: _print,
    );

    try {
      await session.sendPrompt(prompt);
    } catch (e) {
      _print('[Error] $e');
    } finally {
      await session.close();
    }
  }

  // ─── Auth ──────────────────────────────────────────────────────────────────

  static Future<void> _promptForLogin() async {
    _print('');
    _print(DuckbillTheme.muted('  Enter PAT token: '));
    final token = _readLine().trim();
    if (token.isEmpty) {
      _print(DuckbillTheme.warning('  Token cannot be empty.'));
      return;
    }
    await CryptoManager.saveEncryptedPat(token);
    _print(DuckbillTheme.success('  Token saved to ${CryptoManager.getDuckbillKeysPath()}'));
  }

  // ─── Server ────────────────────────────────────────────────────────────────

  static Future<void> _promptForServerStart() async {
    _print('');
    _print(DuckbillTheme.warning('  Starting the server will block this terminal.'));

    _print(DuckbillTheme.muted('  Gemini API Key [env GEMINI_API_KEY]: '));
    var apiKey = _readLine().trim();
    apiKey = apiKey.isEmpty ? (Platform.environment['GEMINI_API_KEY'] ?? '') : apiKey;

    if (apiKey.isEmpty) {
      _print(DuckbillTheme.error('  Missing API key.'));
      return;
    }

    _print(DuckbillTheme.muted('  Port [8080]: '));
    final portStr = _readLine().trim();
    final port = int.tryParse(portStr) ?? 8080;

    _print(DuckbillTheme.muted('  Model [gemini-3-flash-preview]: '));
    final modelStr = _readLine().trim();
    final model = modelStr.isEmpty ? 'gemini-3-flash-preview' : modelStr;

    // Import server lazily to avoid pulling server deps when not needed.
    // Since CLI already depends on server package, this is fine at compile time.
    // ignore: avoid_dynamic_calls
    final serverLib = await _loadServer();
    if (serverLib == null) return;

    await serverLib.call(apiKey: apiKey, port: port, model: model);
  }

  static Future<Future<void> Function({required String apiKey, required int port, required String model})?>
      _loadServer() async {
    // Inline server launch — avoids re-importing the entire server module just
    // for menu-driven start. The server package is already a dependency of cli.
    return ({required String apiKey, required int port, required String model}) async {
      // We use a dynamic dispatch approach: the server package is imported at
      // the top of the binary, so we can use it here directly.
      _print(DuckbillTheme.muted('  Use `duckbill server start --apikey $apiKey --port $port` to start.'));
      _print(DuckbillTheme.muted('  (Blocking server start from interactive menu is not supported.)'));
    };
  }

  // ─── Misc ──────────────────────────────────────────────────────────────────

  static void _printVersion() {
    _print('');
    _print(DuckbillTheme.header('  🦆 Duckbill v$duckbillVersion'));
    _print('  Platform : ${DuckbillUpdater.platformArch}');
    _print('  Repo     : https://github.com/$duckbillRepo');
  }

  static Future<void> _runUpdate() async {
    final updater = DuckbillUpdater(repo: duckbillRepo);
    await updater.run(binaryType: 'cli');
  }

  static Future<String?> _requireToken() async {
    final token = await CryptoManager.getEncryptedPat();
    if (token == null) {
      _print(DuckbillTheme.error('  [Error] No token found. Run `duckbill auth login --token YOUR_TOKEN` first.'));
    }
    return token;
  }

  static void _print(String line) => stdout.writeln(line);
  static String _readLine() => stdin.readLineSync() ?? '';
}
