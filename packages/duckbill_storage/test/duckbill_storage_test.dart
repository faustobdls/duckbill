import 'dart:io';
import 'package:duckbill_storage/duckbill_storage.dart';
import 'package:test/test.dart';

void main() {
  group('JsonConfigManager', () {
    late Directory tempDir;
    late String testPath;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('json_config_test');
      testPath = '${tempDir.path}/test_config.json';
    });

    tearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('loads empty map if file does not exist', () async {
      final manager = JsonConfigManager(testPath);
      final config = await manager.load();
      expect(config, isEmpty);
    });

    test('creates and saves new config file', () async {
      final manager = JsonConfigManager(testPath);
      await manager.save({'hello': 'world'});
      
      expect(await File(testPath).exists(), isTrue);
      
      final loaded = await manager.load();
      expect(loaded['hello'], equals('world'));
    });

    test('loads empty map if file is empty string', () async {
      final manager = JsonConfigManager(testPath);
      await File(testPath).writeAsString('   \\n');
      final config = await manager.load();
      expect(config, isEmpty);
    });
    test('creates and saves new config file in non-existent directory', () async {
      final subDirPath = '${tempDir.path}/subdir/test_config.json';
      final manager = JsonConfigManager(subDirPath);
      await manager.save({'hello': 'world'});
      
      expect(await File(subDirPath).exists(), isTrue);
    });

    test('returns empty map on invalid json', () async {
      final manager = JsonConfigManager(testPath);
      await File(testPath).writeAsString('invalid json');
      final config = await manager.load();
      expect(config, isEmpty);
    });
  });

  group('SqliteDbManager', () {
    late Directory tempDir;
    late String dbPath;
    
    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('sqlite_test');
      dbPath = '${tempDir.path}/test_db.sqlite';
    });

    tearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('initializes and creates directory if needed', () {
      final nestedDbPath = '${tempDir.path}/nested/test_db.sqlite';
      final manager = SqliteDbManager.init(nestedDbPath);
      expect(File(nestedDbPath).existsSync(), isTrue);
      manager.dispose();
    });

    test('initializes and executes with WAL', () {
      final manager = SqliteDbManager.init(dbPath);
      
      // Should create database file
      expect(File(dbPath).existsSync(), isTrue);
      
      // Test basic execution
      manager.execute('CREATE TABLE IF NOT EXISTS foo (id INTEGER PRIMARY KEY, name TEXT)');
      manager.execute('DELETE FROM foo');
      manager.execute('INSERT INTO foo (name) VALUES (?)', ['bar']);
      
      // Test select
      final results = manager.select('SELECT * FROM foo');
      expect(results.length, equals(1));
      expect(results.first['name'], equals('bar'));
      
      // Verify journal_mode
      final journalResult = manager.select('PRAGMA journal_mode;');
      expect(journalResult.first.values.first.toString().toUpperCase(), equals('WAL'));

      manager.dispose();
    });
  });
}
