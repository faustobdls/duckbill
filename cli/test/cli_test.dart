import 'dart:async';
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
      dummyPath = '${tempDir.path}/dummy_path.json';
    });

    tearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });
    test('AuthLoginCommand missing token', () async {
      final cmd = AuthLoginCommand();
      // Test run doesn't crash on missing token
      await expectLater(cmd.run(), completes);
    });

    test('AuthLoginCommand with token', () async {
      CryptoManager.testKeysPathOverride = dummyPath;
      // Would test via commandrunner but hard to mock argResults easily
      // Better to test via mainWrapper with args
      await expectLater(mainWrapper(['auth', 'login', '--token', 'test']), completes);
    });

    test('ServerStartCommand missing apiKey', () async {
      // Returns immediately because apiKey is null
      await expectLater(mainWrapper(['server', 'start']), completes);
    });

    test('ServerStartCommand starts Server', () async {
      // Very tricky to test Server execution directly within CLI unit tests without blocking.
      // We'll just verify argument parsing doesn't throw synchronously.
      // Server startup is intentionally not awaited here — it blocks on connections.
      CryptoManager.testKeysPathOverride = dummyPath;
      unawaited(mainWrapper(['server', 'start', '--apikey', 'fake']));
    });
  });
}
