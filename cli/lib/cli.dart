import 'dart:io';
import 'package:args/command_runner.dart';
import 'package:duckbill_crypto/duckbill_crypto.dart';
import 'package:server/server.dart';

class AuthLoginCommand extends Command {
  @override
  final name = 'login';
  @override
  final description = 'Configures PAT authentication token.';

  AuthLoginCommand() {
    argParser.addOption('token', abbr: 't', help: 'The PAT to securely store.');
  }

  @override
  void run() async {
    final token = argResults?['token'] as String?;
    if (token == null) {
      print('Please provide a token using --token or -t');
      return;
    }
    await CryptoManager.saveEncryptedPat(token);
    print('Token saved successfully to ' + CryptoManager.getDuckbillKeysPath());
  }
}

class ServerStartCommand extends Command {
  @override
  final name = 'start';
  @override
  final description = 'Starts the Duckbill Server wrapper.';

  ServerStartCommand() {
    argParser.addOption('db', help: 'Path to sqlite db', defaultsTo: 'duckbill.sqlite');
    argParser.addOption('apikey', help: 'Gemini API Key');
    argParser.addOption('port', abbr: 'p', help: 'Port', defaultsTo: '8080');
    argParser.addOption('model', abbr: 'm', help: 'Gemini model to use', defaultsTo: 'gemini-3-flash-preview');
  }

  @override
  void run() async {
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
      print('[Metrics] Server initialized in ' + initTime.inMilliseconds.toString() + 'ms');

      // Hook up graceful shutdown
      ProcessSignal.sigint.watch().listen((signal) async {
        print('\\n[Metrics] Shutting down server...');
        await server.stop();
        exit(0);
      });

      await server.start(address: '0.0.0.0', port: port);
    } catch (e) {
      print('[Error] Failed to start server: ' + e.toString());
    }
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

class ServerCommand extends Command {
  @override
  final name = 'server';
  @override
  final description = 'Server commands.';

  ServerCommand() {
    addSubcommand(ServerStartCommand());
  }
}

class AgentRunCommand extends Command {
  @override
  final name = 'run';
  @override
  final description = 'Prompts the Duckbill AI Server securely.';
  
  AgentRunCommand() {
    argParser.addOption('server', abbr: 's', help: 'Server address', defaultsTo: 'ws://127.0.0.1:8080');
  }

  @override
  void run() async {
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
    
    try {
      final ws = await WebSocket.connect(
        serverUrl + '/',
        headers: {'Authorization': 'Bearer ' + token},
      );
      
      ws.listen((data) {
        print(data); // print Server updates and command streams
        if (data.toString().contains('[Server] Execução concluída.') || 
            data.toString().startsWith('AI Resposta:')) {
          ws.close(); // Finish cleanly after streaming the whole process
        }
      }, onError: (e) {
        print('[Error] Server connection error: ' + e.toString());
      }, onDone: () {
        exit(0);
      });

      // Send the prompt
      ws.add(prompt);
      
    } catch (e) {
      print('[Error] Failed to connect to server at ' + serverUrl + ' : ' + e.toString());
    }
  }
}

class AgentCommand extends Command {
  @override
  final name = 'agent';
  @override
  final description = 'Agent execution commands.';

  AgentCommand() {
    addSubcommand(AgentRunCommand());
  }
}

void mainWrapper(List<String> arguments) async {
  final runner = CommandRunner('duckbill', 'Duckbill CLI for AI orchestration.')
    ..addCommand(AuthCommand())
    ..addCommand(ServerCommand())
    ..addCommand(AgentCommand());
    
  try {
    await runner.run(arguments);
  } catch (e) {
    print(e);
    exit(1);
  }
}
