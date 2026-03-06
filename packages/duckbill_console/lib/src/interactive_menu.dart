import 'ansi_styles.dart';

/// A single item in an [InteractiveMenu].
class MenuItem {
  final String label;
  final String? description;
  final String key;

  const MenuItem({
    required this.key,
    required this.label,
    this.description,
  });
}

/// Result of a menu interaction.
class MenuResult {
  /// The [MenuItem.key] of the chosen item, or null if the user exited.
  final String? selectedKey;

  const MenuResult(this.selectedKey);

  bool get wasExited => selectedKey == null;
}

/// Renders a numbered selection menu to the terminal.
///
/// Presentation layer only — no business logic.
///
/// Uses injectable [printer] and [reader] for testability (DIP).
class InteractiveMenu {
  final String title;
  final List<MenuItem> items;
  final void Function(String) printer;
  final String Function() reader;

  const InteractiveMenu({
    required this.title,
    required this.items,
    required this.printer,
    required this.reader,
  });

  /// Renders the menu and blocks until the user makes a valid selection.
  ///
  /// Returns [MenuResult] with null key if user types 'q'/'exit'.
  MenuResult show() {
    _render();
    while (true) {
      printer('');
      printer('${Ansi.dim}Enter number or q to quit${Ansi.reset} → ');
      final input = reader().trim().toLowerCase();

      if (input == 'q' || input == 'quit' || input == 'exit') {
        return const MenuResult(null);
      }

      final index = int.tryParse(input);
      if (index != null && index >= 1 && index <= items.length) {
        return MenuResult(items[index - 1].key);
      }

      // Also support direct key input
      final byKey = items.where((i) => i.key == input).firstOrNull;
      if (byKey != null) return MenuResult(byKey.key);

      printer(DuckbillTheme.warning('  Invalid selection. Try again.'));
    }
  }

  void _render() {
    printer('');
    printer(DuckbillTheme.separator());
    printer(DuckbillTheme.header('  $title'));
    printer(DuckbillTheme.separator());
    for (var i = 0; i < items.length; i++) {
      final item = items[i];
      final num = DuckbillTheme.muted('  [${i + 1}]');
      final label = ' ${item.label}';
      final desc = item.description != null
          ? '  ${DuckbillTheme.muted(item.description!)}'
          : '';
      printer('$num$label$desc');
    }
    printer(DuckbillTheme.separator());
  }
}

/// Continuously loops a menu until the user exits.
class MenuLoop {
  final InteractiveMenu menu;
  final Future<void> Function(String key) onSelected;
  final void Function(String) printer;

  const MenuLoop({
    required this.menu,
    required this.onSelected,
    required this.printer,
  });

  Future<void> run() async {
    while (true) {
      final result = menu.show();
      if (result.wasExited) {
        printer(DuckbillTheme.muted('  Goodbye! 🦆'));
        return;
      }
      await onSelected(result.selectedKey!);
    }
  }
}
