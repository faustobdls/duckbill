import 'dart:io';
import 'package:args/command_runner.dart';
import 'package:duckbill_crypto/duckbill_crypto.dart';
import 'package:server/server.dart';

import 'src/version.dart';
import 'src/updater.dart';
import 'src/interactive_runner.dart';

// ─── Auth ────────────────────────────────────────────────────────────────────

class AuthLoginCommand extends Command {
  @override
  final name = 'login';
  @override
  final description = 'Configures PAT authentication token.';

  AuthLoginCommand() {
    argParser.addOption('token', abbr: 't', help: 'The PAT to securely store.');
  }

  @override
  Future<void> run() async {
    final token = argResults?['token'] as String?;
    if (token == null) {
      print('Please provide a token using --token or -t');
      return;
    }
    await CryptoManager.saveEncryptedPat(token);
    print('Token saved successfully to ${CryptoManager.getDuckbillKeysPath()}');
  }
}

class AuthCommand extends Command {
  @override
  final name = 'auth';
  @override
  final description = 'Authentication commands.';

  AuthCommand() {
    addSubcommand(AuthLoginCommand());
  }
}

// ─── Server ──────────────────────────────────────────────────────────────────

class ServerStartCommand extends Command {
  @override
  final name = 'start';
  @override
  final description = 'Starts the Duckbill Server.';

  ServerStartCommand() {
    argParser.addOption('db', help: 'Path to SQLite DB', defaultsTo: 'duckbill.sqlite');
    argParser.addOption('apikey', help: 'Gemini API Key');
    argParser.addOption('port', abbr: 'p', help: 'Port', defaultsTo: '8080');
    argParser.addOption('model', abbr: 'm', help: 'AI model', defaultsTo: 'gemini-3-flash-preview');
  }

  @override
  Future<void> run() async {
    final startTime = DateTime.now();

    var apiKey = argResults?['apikey'] as String?;
    apiKey ??= Platform.environment['GEMINI_API_KEY'];

    if (apiKey == null || apiKey.isEmpty) {
      print('Missing API key. Provide --apikey or set GEMINI_API_KEY');
      return;
    }

    final dbPath = argResults?['db'] as String;
    final portStr = argResults?['port'] as String;
    final port = int.tryParse(portStr) ?? 8080;

    print('[Metrics] Initializing Duckbill Server...');

    try {
      final server = await DuckbillServer.initialize(
        dbPath: dbPath,
        apiKey: apiKey,
        model: argResults?['model'] as String? ?? 'gemini-3-flash-preview',
      );

      final initTime = DateTime.now().difference(startTime);
      print('[Metrics] Server initialized in ${initTime.inMilliseconds}ms');

      ProcessSignal.sigint.watch().listen((signal) async {
        print('\n[Metrics] Shutting down server...');
        await server.stop();
        exit(0);
      });

      await server.start(address: '0.0.0.0', port: port);
    } catch (e) {
      print('[Error] Failed to start server: $e');
    }
  }
}

class ServerCommand extends Command {
  @override
  final name = 'server';
  @override
  final description = 'Server commands.';

  ServerCommand() {
    addSubcommand(ServerStartCommand());
  }
}

// ─── Agent ───────────────────────────────────────────────────────────────────

/// Sends a single prompt to the server and prints the result.
///
/// For a full interactive session, use [AgentInteractiveCommand].
class AgentRunCommand extends Command {
  @override
  final name = 'run';
  @override
  final description = 'Sends a single prompt to the Duckbill AI Server.';

  AgentRunCommand() {
    argParser.addOption('server', abbr: 's', help: 'Server address', defaultsTo: 'ws://127.0.0.1:8080');
    argParser.addFlag('auto-approve', abbr: 'y', help: 'Auto-approve all AI suggestions', defaultsTo: false);
  }

  @override
  Future<void> run() async {
    final prompt = argResults?.rest.join(' ');
    if (prompt == null || prompt.isEmpty) {
      print('Please provide a prompt. Example: duckbill agent run "Hello AI"');
      return;
    }

    final token = await CryptoManager.getEncryptedPat();
    if (token == null) {
      print('[Error] No token found. Please run `duckbill auth login --token YOUR_TOKEN` first.');
      return;
    }

    final serverUrl = argResults?['server'] as String;
    final autoApprove = argResults?['auto-approve'] as bool? ?? false;

    await InteractiveRunner.runSinglePrompt(
      serverUrl: serverUrl,
      token: token,
      prompt: prompt,
      autoApprove: autoApprove,
    );
  }
}

/// Launches a full interactive chat session similar to Claude Code.
class AgentInteractiveCommand extends Command {
  @override
  final name = 'interactive';
  @override
  final description = 'Starts an interactive AI chat session (Claude Code style).';

  AgentInteractiveCommand() {
    argParser.addOption('server', abbr: 's', help: 'Server address', defaultsTo: 'ws://127.0.0.1:8080');
    argParser.addFlag('auto-approve', abbr: 'y', help: 'Auto-approve all AI suggestions', defaultsTo: false);
  }

  @override
  Future<void> run() async {
    final token = await CryptoManager.getEncryptedPat();
    if (token == null) {
      print('[Error] No token found. Please run `duckbill auth login --token YOUR_TOKEN` first.');
      return;
    }

    final serverUrl = argResults?['server'] as String;
    final autoApprove = argResults?['auto-approve'] as bool? ?? false;

    await InteractiveRunner.runInteractiveSession(
      serverUrl: serverUrl,
      token: token,
      autoApprove: autoApprove,
    );
  }
}

class AgentCommand extends Command {
  @override
  final name = 'agent';
  @override
  final description = 'Agent execution commands.';

  AgentCommand() {
    addSubcommand(AgentRunCommand());
    addSubcommand(AgentInteractiveCommand());
  }
}

// ─── Update / Version ────────────────────────────────────────────────────────

class UpdateCommand extends Command {
  @override
  final name = 'update';
  @override
  final description = 'Checks for updates and self-updates the binary.';

  UpdateCommand() {
    argParser.addOption('repo', abbr: 'r', help: 'GitHub repository', defaultsTo: duckbillRepo);
    argParser.addOption('type', abbr: 't', help: 'Binary type (cli or server)', defaultsTo: 'server');
  }

  @override
  Future<void> run() async {
    final repo = argResults?['repo'] as String? ?? duckbillRepo;
    final binaryType = argResults?['type'] as String? ?? 'server';
    final updater = DuckbillUpdater(repo: repo);
    await updater.run(binaryType: binaryType);
  }
}

class VersionCommand extends Command {
  @override
  final name = 'version';
  @override
  final description = 'Prints the current Duckbill version.';

  @override
  void run() {
    print('🦆 Duckbill v$duckbillVersion');
    print('Platform: ${DuckbillUpdater.platformArch}');
    print('Repo: https://github.com/$duckbillRepo');
  }
}

// ─── Entry point ─────────────────────────────────────────────────────────────

/// Main wrapper — delegates to [InteractiveRunner.showMainMenu] when no
/// arguments are provided (interactive/TUI mode).
Future<void> mainWrapper(List<String> arguments) async {
  // No arguments → show interactive menu.
  if (arguments.isEmpty) {
    await InteractiveRunner.showMainMenu();
    return;
  }

  final runner = CommandRunner('duckbill', 'Duckbill CLI v$duckbillVersion — AI orchestration.')
    ..addCommand(AuthCommand())
    ..addCommand(ServerCommand())
    ..addCommand(AgentCommand())
    ..addCommand(UpdateCommand())
    ..addCommand(VersionCommand());

  try {
    await runner.run(arguments);
  } catch (e) {
    print(e);
    exit(1);
  }
}
