import 'package:sqlite3/sqlite3.dart';
import 'dart:io';

class SqliteDbManager {
  final Database db;

  SqliteDbManager._(this.db);

  /// Initializes the SQLite database at the specified path and enables WAL mode.
  static SqliteDbManager init(String path) {
    // Ensure directory exists
    final file = File(path);
    if (!file.parent.existsSync()) {
      file.parent.createSync(recursive: true);
    }

    final db = sqlite3.open(path);

    // Enable Write-Ahead Logging (WAL) for better concurrency and performance
    db.execute('PRAGMA journal_mode=WAL;');
    db.execute('PRAGMA synchronous=NORMAL;'); // Better performance with WAL

    return SqliteDbManager._(db);
  }

  void execute(String sql, [List<Object?> parameters = const []]) {
    db.execute(sql, parameters);
  }

  ResultSet select(String sql, [List<Object?> parameters = const []]) {
    return db.select(sql, parameters);
  }

  void dispose() {
    db.dispose();
  }
}
