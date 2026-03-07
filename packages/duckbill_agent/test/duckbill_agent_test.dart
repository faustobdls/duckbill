import 'dart:io';
import 'package:duckbill_agent/duckbill_agent.dart';
import 'package:test/test.dart';

// ─── AiSuggestion ────────────────────────────────────────────────────────────

void main() {
  group('AiSuggestion', () {
    test('command constructor sets fields correctly', () {
      const s = AiSuggestion.command('ls -la', explanation: 'list files');
      expect(s.kind, SuggestionKind.command);
      expect(s.value, 'ls -la');
      expect(s.explanation, 'list files');
      expect(s.secondaryValue, isNull);
    });

    test('fileWrite constructor sets fields correctly', () {
      const s = AiSuggestion.fileWrite('/tmp/a.txt', 'content', explanation: 'why');
      expect(s.kind, SuggestionKind.fileWrite);
      expect(s.value, '/tmp/a.txt');
      expect(s.secondaryValue, 'content');
      expect(s.explanation, 'why');
    });

    test('explanation constructor sets fields correctly', () {
      const s = AiSuggestion.explanation('just text');
      expect(s.kind, SuggestionKind.explanation);
      expect(s.value, 'just text');
      expect(s.secondaryValue, isNull);
    });

    group('fromJson', () {
      test('parses command', () {
        final s = AiSuggestion.fromJson({'command': 'echo hi', 'explanation': 'greet'});
        expect(s, isNotNull);
        expect(s!.kind, SuggestionKind.command);
        expect(s.value, 'echo hi');
        expect(s.explanation, 'greet');
      });

      test('parses file_write', () {
        final s = AiSuggestion.fromJson({
          'file_path': '/a.txt',
          'file_content': 'hello',
          'explanation': 'write it',
        });
        expect(s, isNotNull);
        expect(s!.kind, SuggestionKind.fileWrite);
        expect(s.value, '/a.txt');
        expect(s.secondaryValue, 'hello');
      });

      test('parses explanation', () {
        final s = AiSuggestion.fromJson({'explanation': 'just info'});
        expect(s, isNotNull);
        expect(s!.kind, SuggestionKind.explanation);
        expect(s.value, 'just info');
      });

      test('returns null for unrecognised shape', () {
        expect(AiSuggestion.fromJson({'unknown': true}), isNull);
      });

      test('returns null for empty map', () {
        expect(AiSuggestion.fromJson({}), isNull);
      });
    });

    group('toJson', () {
      test('command round-trips', () {
        const s = AiSuggestion.command('echo', explanation: 'e');
        final json = s.toJson();
        expect(json['kind'], 'command');
        expect(json['value'], 'echo');
        expect(json['explanation'], 'e');
      });

      test('fileWrite round-trips', () {
        const s = AiSuggestion.fileWrite('/x', 'data');
        final json = s.toJson();
        expect(json['kind'], 'file_write');
        expect(json['file_path'], '/x');
        expect(json['file_content'], 'data');
      });

      test('explanation round-trips', () {
        const s = AiSuggestion.explanation('text');
        final json = s.toJson();
        expect(json['kind'], 'explanation');
        expect(json['value'], 'text');
      });
    });

    test('equality and hashCode', () {
      const a = AiSuggestion.command('ls');
      const b = AiSuggestion.command('ls');
      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
    });

    test('toString includes kind and value', () {
      const s = AiSuggestion.command('pwd');
      expect(s.toString(), contains('command'));
      expect(s.toString(), contains('pwd'));
    });
  });

  // ─── SuggestionParser ──────────────────────────────────────────────────────

  group('SuggestionParser', () {
    test('parses markdown json block with single object', () {
      const text = '```json\n{"command": "ls"}\n```';
      final suggestions = SuggestionParser.parse(text);
      expect(suggestions, hasLength(1));
      expect(suggestions.first.kind, SuggestionKind.command);
    });

    test('parses markdown json block with array', () {
      const text = '```json\n[{"command": "ls"},{"explanation":"info"}]\n```';
      final suggestions = SuggestionParser.parse(text);
      expect(suggestions, hasLength(2));
    });

    test('parses raw json object without markdown', () {
      const text = '{"command": "pwd"}';
      final suggestions = SuggestionParser.parse(text);
      expect(suggestions, hasLength(1));
    });

    test('parses raw json array without markdown', () {
      const text = '[{"command": "pwd"}, {"command": "ls"}]';
      final suggestions = SuggestionParser.parse(text);
      expect(suggestions, hasLength(2));
    });

    test('returns empty list for plain text', () {
      expect(SuggestionParser.parse('no json here'), isEmpty);
    });

    test('returns empty list for invalid json', () {
      expect(SuggestionParser.parse('```json\n{bad}\n```'), isEmpty);
    });

    test('skips unrecognised objects in array', () {
      const text = '[{"command": "ls"}, {"unknown": true}]';
      final suggestions = SuggestionParser.parse(text);
      expect(suggestions, hasLength(1));
    });
  });

  // ─── ExecutionGate ─────────────────────────────────────────────────────────

  group('AutoApproveGate', () {
    test('always returns approved', () async {
      const gate = AutoApproveGate();
      const s = AiSuggestion.command('ls');
      final result = await gate.evaluate(s);
      expect(result.decision, GateDecision.approved);
      expect(result.isApproved, isTrue);
      expect(result.isCancelled, isFalse);
    });
  });

  group('DryRunGate', () {
    test('always returns skipped', () async {
      const gate = DryRunGate();
      const s = AiSuggestion.command('rm -rf /');
      final result = await gate.evaluate(s);
      expect(result.decision, GateDecision.skipped);
      expect(result.isApproved, isFalse);
    });
  });

  group('InteractiveGate', () {
    test('returns approved on y', () async {
      final gate = InteractiveGate(printer: (_) {}, reader: () => 'y');
      const s = AiSuggestion.command('ls');
      final result = await gate.evaluate(s);
      expect(result.decision, GateDecision.approved);
    });

    test('returns skipped on s', () async {
      final gate = InteractiveGate(printer: (_) {}, reader: () => 's');
      const s = AiSuggestion.command('ls');
      final result = await gate.evaluate(s);
      expect(result.decision, GateDecision.skipped);
    });

    test('returns cancelled on q', () async {
      final gate = InteractiveGate(printer: (_) {}, reader: () => 'q');
      const s = AiSuggestion.command('ls');
      final result = await gate.evaluate(s);
      expect(result.decision, GateDecision.cancelled);
      expect(result.isCancelled, isTrue);
    });

    test('returns cancelled on quit', () async {
      final gate = InteractiveGate(printer: (_) {}, reader: () => 'quit');
      const s = AiSuggestion.command('ls');
      final result = await gate.evaluate(s);
      expect(result.decision, GateDecision.cancelled);
    });

    test('returns skipped on unrecognised input', () async {
      final gate = InteractiveGate(printer: (_) {}, reader: () => 'nope');
      const s = AiSuggestion.command('ls');
      final result = await gate.evaluate(s);
      expect(result.decision, GateDecision.skipped);
    });

    test('prints suggestion details', () async {
      final printed = <String>[];
      final gate = InteractiveGate(printer: printed.add, reader: () => 'y');
      const s = AiSuggestion.command('ls', explanation: 'list files');
      await gate.evaluate(s);
      expect(printed.any((l) => l.contains('ls')), isTrue);
      expect(printed.any((l) => l.contains('list files')), isTrue);
    });
  });

  // ─── LocalExecutor ─────────────────────────────────────────────────────────

  group('HostLocalExecutor', () {
    late Directory tempDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('duck_exec_test');
    });

    tearDown(() async {
      await tempDir.delete(recursive: true);
    });

    test('executes a shell command and returns stdout', () async {
      final executor = HostLocalExecutor(
        processRunOverride: (cmd) async =>
            ProcessResult(0, 0, 'hello\n', ''),
      );
      const s = AiSuggestion.command('echo hello');
      final result = await executor.execute(s);
      expect(result.exitCode, 0);
      expect(result.stdout, contains('hello'));
      expect(result.isSuccess, isTrue);
    });

    test('captures non-zero exit code', () async {
      final executor = HostLocalExecutor(
        processRunOverride: (cmd) async => ProcessResult(0, 1, '', 'error!'),
      );
      const s = AiSuggestion.command('false');
      final result = await executor.execute(s);
      expect(result.exitCode, 1);
      expect(result.isSuccess, isFalse);
    });

    test('captures stderr', () async {
      final executor = HostLocalExecutor(
        processRunOverride: (cmd) async => ProcessResult(0, 0, '', 'some warning'),
      );
      const s = AiSuggestion.command('cmd');
      final result = await executor.execute(s);
      expect(result.stderr, contains('some warning'));
    });

    test('handles process exception', () async {
      final executor = HostLocalExecutor(
        processRunOverride: (cmd) async => throw Exception('no such process'),
      );
      const s = AiSuggestion.command('bad_cmd');
      final result = await executor.execute(s);
      expect(result.exitCode, -1);
      expect(result.stderr, contains('Exception'));
    });

    test('writes file for fileWrite suggestion', () async {
      final executor = const HostLocalExecutor();
      final path = '${tempDir.path}/test_write.txt';
      final s = AiSuggestion.fileWrite(path, 'hello file');
      final result = await executor.execute(s);
      expect(result.exitCode, 0);
      expect(await File(path).readAsString(), 'hello file');
    });

    test('returns explanation text for explanation suggestion', () async {
      final executor = const HostLocalExecutor();
      const s = AiSuggestion.explanation('Just informing you.');
      final result = await executor.execute(s);
      expect(result.exitCode, 0);
      expect(result.stdout, contains('Just informing you.'));
    });

    test('handles file write failure gracefully', () async {
      final executor = const HostLocalExecutor();
      // Invalid path
      final s = AiSuggestion.fileWrite('\x00bad\x00path', 'content');
      final result = await executor.execute(s);
      expect(result.exitCode, -1);
      expect(result.stderr, isNotEmpty);
    });

    test('elapsed is non-negative', () async {
      final executor = HostLocalExecutor(
        processRunOverride: (cmd) async => ProcessResult(0, 0, '', ''),
      );
      const s = AiSuggestion.command('echo');
      final result = await executor.execute(s);
      expect(result.elapsed.inMilliseconds, greaterThanOrEqualTo(0));
    });

    test('toString is descriptive', () async {
      final executor = HostLocalExecutor(
        processRunOverride: (cmd) async => ProcessResult(0, 0, 'out', ''),
      );
      const s = AiSuggestion.command('echo');
      final result = await executor.execute(s);
      expect(result.toString(), contains('exitCode'));
    });
  });

  // ─── GateResult ────────────────────────────────────────────────────────────

  group('GateResult', () {
    test('isApproved true only when approved', () {
      const s = AiSuggestion.command('x');
      expect(GateResult(decision: GateDecision.approved, suggestion: s).isApproved, isTrue);
      expect(GateResult(decision: GateDecision.skipped, suggestion: s).isApproved, isFalse);
      expect(GateResult(decision: GateDecision.cancelled, suggestion: s).isApproved, isFalse);
    });

    test('isCancelled true only when cancelled', () {
      const s = AiSuggestion.command('x');
      expect(GateResult(decision: GateDecision.cancelled, suggestion: s).isCancelled, isTrue);
      expect(GateResult(decision: GateDecision.approved, suggestion: s).isCancelled, isFalse);
    });
  });
}
