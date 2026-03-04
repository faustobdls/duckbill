import 'dart:convert';
import 'dart:io';
import 'package:cryptography/cryptography.dart';
import 'package:duckbill_crypto/duckbill_crypto.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  group('CryptoManager', () {
    late CryptoManager manager;
    late SecretKey key;

    setUp(() async {
      manager = CryptoManager(algorithmOverride: AesGcm.with256bits());
      key = await manager.algorithm.newSecretKey();
    });

    test('can encrypt and decrypt a string', () async {
      final plaintext = 'super_secret_pat_value';
      final encrypted = await manager.encrypt(plaintext, key);
      
      expect(encrypted, isNot(contains(plaintext)));
      
      final decrypted = await manager.decrypt(encrypted, key);
      expect(decrypted, equals(plaintext));
    });

    test('initializes with default algorithm', () {
      final defaultManager = CryptoManager();
      expect(defaultManager.algorithm, isA<AesGcm>());
    });

    test('throws when ciphertext is too short', () async {
      // Create an invalid ciphertext
      final invalidCiphertext = base64Encode([1, 2, 3]);
      
      expect(
        () async => await manager.decrypt(invalidCiphertext, key),
        throwsException,
      );
    });
  });

  group('CryptoManager PAT Storage', () {
    test('getDuckbillKeysPath resolves accurately', () {
      final path = CryptoManager.getDuckbillKeysPath();
      expect(path, isA<String>());
      expect(path, contains('.duckbill'));
    });

    test('throws when no home directory is found', () {
      CryptoManager.testKeysPathOverride = null;
      expect(
        () => CryptoManager.getDuckbillKeysPath({'NO_HOME': 'true'}),
        throwsException,
      );
    });

    test('saves and gets encrypted PAT', () async {
      final testHome = Directory(Platform.script.resolve('.test_home').toFilePath());
      if (await testHome.exists()) {
        await testHome.delete(recursive: true);
      }
      
      final testPath = p.join(testHome.path, '.duckbill', 'keys', 'auth.json');
      CryptoManager.testKeysPathOverride = testPath;

      try {
        // Initially no PAT
        final noPat = await CryptoManager.getEncryptedPat();
        expect(noPat, isNull);

        // Save PAT
        final dummyPat = base64Encode([10, 20, 30]);
        await CryptoManager.saveEncryptedPat(dummyPat);

        // Retrieve PAT
        final retrieved = await CryptoManager.getEncryptedPat();
        expect(retrieved, equals(dummyPat));
      } finally {
        CryptoManager.testKeysPathOverride = null;
        if (await testHome.exists()) {
          await testHome.delete(recursive: true);
        }
      }
    });
  });
}

