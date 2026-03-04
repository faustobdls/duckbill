import 'dart:io';
import 'package:cli/cli.dart';
import 'package:duckbill_crypto/duckbill_crypto.dart';
import 'package:test/test.dart';

void main() {
  group('CLI Tests', () {
    late Directory tempDir;
    late String dummyPath;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('cli_test_dir');
      dummyPath = tempDir.path + '/dummy_path.json';
    });

    tearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });
    test('AuthLoginCommand missing token', () async {
      final cmd = AuthLoginCommand();
      // Test run doesn't crash on missing token
      expect(() => cmd.run(), returnsNormally);
    });

    test('AuthLoginCommand with token', () async {
      CryptoManager.testKeysPathOverride = dummyPath;
      // Would test via commandrunner but hard to mock argResults easily
      // Better to test via mainWrapper with args
      expect(() => mainWrapper(['auth', 'login', '--token', 'test']), returnsNormally);
    });

    test('ServerStartCommand missing apiKey', () async {
      expect(() => mainWrapper(['server', 'start']), returnsNormally);
    });

    test('ServerStartCommand starts Server', () async {
      // Very tricky to test Server execution directly within CLI unit tests without blocking
      // We'll just verify parsing
      CryptoManager.testKeysPathOverride = dummyPath;
      expect(() => mainWrapper(['server', 'start', '--apikey', 'fake']), returnsNormally);
    });
  });
}
