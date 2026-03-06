import 'package:duckbill_console/duckbill_console.dart';
import 'package:test/test.dart';

void main() {
  // ─── AnsiStyles ────────────────────────────────────────────────────────────

  group('Ansi constants', () {
    test('reset is non-empty ANSI escape', () {
      expect(Ansi.reset, startsWith('\x1B['));
    });

    test('bold wraps text with reset', () {
      final result = Ansi.bold_(  'hi');
      expect(result, contains('hi'));
      expect(result, contains(Ansi.bold));
      expect(result, endsWith(Ansi.reset));
    });

    test('colorize wraps text with reset', () {
      final result = Ansi.colorize('text', Ansi.red);
      expect(result, contains('text'));
      expect(result, contains(Ansi.red));
      expect(result, endsWith(Ansi.reset));
    });

    test('dim_ wraps text with reset', () {
      final result = Ansi.dim_('dim text');
      expect(result, contains('dim text'));
      expect(result, endsWith(Ansi.reset));
    });
  });

  group('DuckbillTheme', () {
    test('header produces non-empty string containing text', () {
      final result = DuckbillTheme.header('Title');
      expect(result, contains('Title'));
    });

    test('success contains text', () {
      expect(DuckbillTheme.success('ok'), contains('ok'));
    });

    test('warning contains text', () {
      expect(DuckbillTheme.warning('warn'), contains('warn'));
    });

    test('error contains text', () {
      expect(DuckbillTheme.error('err'), contains('err'));
    });

    test('muted contains text', () {
      expect(DuckbillTheme.muted('quiet'), contains('quiet'));
    });

    test('highlight contains text', () {
      expect(DuckbillTheme.highlight('bright'), contains('bright'));
    });

    test('selected prefixes with arrow', () {
      expect(DuckbillTheme.selected('item'), contains('▶'));
      expect(DuckbillTheme.selected('item'), contains('item'));
    });

    test('normal prefixes with spaces', () {
      expect(DuckbillTheme.normal('item'), startsWith('  '));
      expect(DuckbillTheme.normal('item'), contains('item'));
    });

    test('aiMessage contains text', () {
      expect(DuckbillTheme.aiMessage('msg'), contains('msg'));
    });

    test('separator returns dashes', () {
      expect(DuckbillTheme.separator(), contains('─'));
    });

    test('separator with custom width', () {
      final sep = DuckbillTheme.separator(10);
      // Strip ANSI and count dashes
      final plain = sep.replaceAll(RegExp(r'\x1B\[[0-9;]*m'), '');
      expect(plain, hasLength(10));
    });
  });

  // ─── InteractiveMenu ───────────────────────────────────────────────────────

  group('InteractiveMenu', () {
    final items = const [
      MenuItem(key: 'a', label: 'Option A', description: 'desc a'),
      MenuItem(key: 'b', label: 'Option B'),
      MenuItem(key: 'c', label: 'Option C'),
    ];

    test('returns selected key by number', () {
      final printed = <String>[];
      final menu = InteractiveMenu(
        title: 'Test',
        items: items,
        printer: printed.add,
        reader: () => '1',
      );
      final result = menu.show();
      expect(result.selectedKey, 'a');
      expect(result.wasExited, isFalse);
    });

    test('returns selected key for second item', () {
      final menu = InteractiveMenu(
        title: 'Test',
        items: items,
        printer: (_) {},
        reader: () => '2',
      );
      expect(menu.show().selectedKey, 'b');
    });

    test('returns null on q', () {
      final menu = InteractiveMenu(
        title: 'Test',
        items: items,
        printer: (_) {},
        reader: () => 'q',
      );
      final result = menu.show();
      expect(result.wasExited, isTrue);
      expect(result.selectedKey, isNull);
    });

    test('returns null on quit', () {
      final menu = InteractiveMenu(
        title: 'Test',
        items: items,
        printer: (_) {},
        reader: () => 'quit',
      );
      expect(menu.show().wasExited, isTrue);
    });

    test('returns null on exit', () {
      final menu = InteractiveMenu(
        title: 'Test',
        items: items,
        printer: (_) {},
        reader: () => 'exit',
      );
      expect(menu.show().wasExited, isTrue);
    });

    test('accepts item key directly', () {
      final menu = InteractiveMenu(
        title: 'Test',
        items: items,
        printer: (_) {},
        reader: () => 'b',
      );
      expect(menu.show().selectedKey, 'b');
    });

    test('retries on invalid input then accepts valid', () {
      var callCount = 0;
      final menu = InteractiveMenu(
        title: 'Test',
        items: items,
        printer: (_) {},
        reader: () {
          callCount++;
          return callCount == 1 ? 'bad' : '3';
        },
      );
      final result = menu.show();
      expect(result.selectedKey, 'c');
      expect(callCount, 2);
    });

    test('renders title in output', () {
      final printed = <String>[];
      var called = false;
      final menu = InteractiveMenu(
        title: 'My Menu',
        items: items,
        printer: printed.add,
        reader: () {
          if (!called) {
            called = true;
            return 'q';
          }
          return 'q';
        },
      );
      menu.show();
      expect(printed.any((l) => l.contains('My Menu')), isTrue);
    });

    test('renders item labels in output', () {
      final printed = <String>[];
      final menu = InteractiveMenu(
        title: 'T',
        items: items,
        printer: printed.add,
        reader: () => 'q',
      );
      menu.show();
      expect(printed.any((l) => l.contains('Option A')), isTrue);
      expect(printed.any((l) => l.contains('desc a')), isTrue);
    });
  });

  // ─── ChatInterface ─────────────────────────────────────────────────────────

  group('ChatInterface', () {
    test('printHeader outputs content', () {
      final printed = <String>[];
      final chat = ChatInterface(printer: printed.add, reader: () => '');
      chat.printHeader();
      expect(printed, isNotEmpty);
    });

    test('readPrompt returns null on exit', () {
      final chat = ChatInterface(printer: (_) {}, reader: () => 'exit');
      expect(chat.readPrompt(), isNull);
    });

    test('readPrompt returns null on quit', () {
      final chat = ChatInterface(printer: (_) {}, reader: () => 'quit');
      expect(chat.readPrompt(), isNull);
    });

    test('readPrompt returns trimmed input', () {
      final chat = ChatInterface(printer: (_) {}, reader: () => '  hello  ');
      expect(chat.readPrompt(), 'hello');
    });

    test('readPrompt returns empty string on empty input', () {
      final chat = ChatInterface(printer: (_) {}, reader: () => '');
      expect(chat.readPrompt(), '');
    });

    test('readPrompt stores message in history', () {
      final chat = ChatInterface(printer: (_) {}, reader: () => 'hello');
      chat.readPrompt();
      expect(chat.history, hasLength(1));
      expect(chat.history.first.role, ChatRole.user);
      expect(chat.history.first.content, 'hello');
    });

    test('printAssistantMessage stores in history', () {
      final chat = ChatInterface(printer: (_) {}, reader: () => '');
      chat.printAssistantMessage('I am AI');
      expect(chat.history, hasLength(1));
      expect(chat.history.first.role, ChatRole.assistant);
      expect(chat.history.first.content, 'I am AI');
    });

    test('printAssistantMessage outputs to printer', () {
      final printed = <String>[];
      final chat = ChatInterface(printer: printed.add, reader: () => '');
      chat.printAssistantMessage('Response text');
      expect(printed.any((l) => l.contains('Response text')), isTrue);
    });

    test('printStatus outputs a status line', () {
      final printed = <String>[];
      final chat = ChatInterface(printer: printed.add, reader: () => '');
      chat.printStatus('Loading…');
      expect(printed.any((l) => l.contains('Loading…')), isTrue);
    });

    test('printSuggestion outputs kind and value', () {
      final printed = <String>[];
      final chat = ChatInterface(printer: printed.add, reader: () => '');
      chat.printSuggestion(kind: 'command', value: 'ls -la', explanation: 'list files');
      expect(printed.any((l) => l.contains('ls -la')), isTrue);
      expect(printed.any((l) => l.contains('list files')), isTrue);
    });

    test('printExecutionResult outputs stdout and exit code', () {
      final printed = <String>[];
      final chat = ChatInterface(printer: printed.add, reader: () => '');
      chat.printExecutionResult(
        exitCode: 0,
        stdout: 'total 42',
        stderr: '',
        elapsedMs: 50,
      );
      expect(printed.any((l) => l.contains('total 42')), isTrue);
      expect(printed.any((l) => l.contains('0')), isTrue);
    });

    test('printExecutionResult outputs stderr when present', () {
      final printed = <String>[];
      final chat = ChatInterface(printer: printed.add, reader: () => '');
      chat.printExecutionResult(
        exitCode: 1,
        stdout: '',
        stderr: 'some error',
        elapsedMs: 10,
      );
      expect(printed.any((l) => l.contains('some error')), isTrue);
    });

    test('printError outputs message', () {
      final printed = <String>[];
      final chat = ChatInterface(printer: printed.add, reader: () => '');
      chat.printError('something went wrong');
      expect(printed.any((l) => l.contains('something went wrong')), isTrue);
    });

    test('history is unmodifiable', () {
      final chat = ChatInterface(printer: (_) {}, reader: () => 'hi');
      chat.readPrompt();
      expect(() => (chat.history as dynamic).add(ChatMessage(role: ChatRole.user, content: 'x')),
          throwsUnsupportedError);
    });

    test('agentName appears in header', () {
      final printed = <String>[];
      final chat = ChatInterface(printer: printed.add, reader: () => '', agentName: 'MyBot');
      chat.printHeader();
      expect(printed.any((l) => l.contains('MyBot')), isTrue);
    });

    test('ChatMessage uses current time when no timestamp provided', () {
      final before = DateTime.now();
      final msg = ChatMessage(role: ChatRole.user, content: 'hi');
      final after = DateTime.now();
      expect(msg.timestamp.isAfter(before.subtract(const Duration(seconds: 1))), isTrue);
      expect(msg.timestamp.isBefore(after.add(const Duration(seconds: 1))), isTrue);
    });
  });

  // ─── MenuLoop ──────────────────────────────────────────────────────────────

  group('MenuLoop', () {
    test('calls onSelected with correct key and then exits on q', () async {
      final selected = <String>[];
      var readCount = 0;
      final menu = InteractiveMenu(
        title: 'Test',
        items: const [MenuItem(key: 'go', label: 'Go')],
        printer: (_) {},
        reader: () {
          readCount++;
          return readCount == 1 ? '1' : 'q';
        },
      );
      final loop = MenuLoop(
        menu: menu,
        onSelected: (key) async => selected.add(key),
        printer: (_) {},
      );
      await loop.run();
      expect(selected, ['go']);
    });

    test('exits immediately on q without calling onSelected', () async {
      final selected = <String>[];
      final menu = InteractiveMenu(
        title: 'Test',
        items: const [MenuItem(key: 'x', label: 'X')],
        printer: (_) {},
        reader: () => 'q',
      );
      final loop = MenuLoop(
        menu: menu,
        onSelected: (key) async => selected.add(key),
        printer: (_) {},
      );
      await loop.run();
      expect(selected, isEmpty);
    });
  });
}
