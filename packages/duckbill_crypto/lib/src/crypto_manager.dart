import 'dart:convert';
import 'dart:io';
import 'package:cryptography/cryptography.dart';
import 'package:path/path.dart' as p;

class CryptoManager {
  final AesGcm algorithm;

  CryptoManager({AesGcm? algorithmOverride})
      : algorithm = algorithmOverride ?? AesGcm.with256bits();

  /// Encrypts plaintext using the provided key. The nonce is generated automatically
  /// and prepended to the ciphertext.
  Future<String> encrypt(String plaintext, SecretKey key) async {
    final secretBox = await algorithm.encrypt(
      utf8.encode(plaintext),
      secretKey: key,
    );
    
    // Combine nonce, mac and ciphertext to easily store them
    final result = <int>[
      ...secretBox.nonce,
      ...secretBox.mac.bytes,
      ...secretBox.cipherText,
    ];
    return base64Encode(result);
  }

  /// Decrypts a base64 encoded ciphertext that contains a nonce and mac.
  Future<String> decrypt(String base64Ciphertext, SecretKey key) async {
    final data = base64Decode(base64Ciphertext);
    
    // AesGcm uses a 12-byte nonce and 16-byte mac by default
    final nonceLength = 12;
    final macLength = 16;
    
    if (data.length < nonceLength + macLength) {
      throw Exception('Invalid ciphertext data.');
    }

    final nonce = data.sublist(0, nonceLength);
    final mac = Mac(data.sublist(nonceLength, nonceLength + macLength));
    final ciphertext = data.sublist(nonceLength + macLength);

    final secretBox = SecretBox(
      ciphertext,
      nonce: nonce,
      mac: mac,
    );

    final plaintext = await algorithm.decrypt(
      secretBox,
      secretKey: key,
    );

    return utf8.decode(plaintext);
  }

  /// Derives or retrieves a key from ~/.duckbill/keys/auth.json
  /// For this project, a PAT can be stored securely.
  static String? testKeysPathOverride;

  static String getDuckbillKeysPath([Map<String, String>? env]) {
    if (testKeysPathOverride != null) {
      return testKeysPathOverride!;
    }
    final environment = env ?? Platform.environment;
    final home = environment['HOME'] ?? environment['USERPROFILE'];
    if (home == null) throw Exception('Unable to locate home directory.');
    return p.join(home, '.duckbill', 'keys', 'auth.json');
  }

  static Future<void> saveEncryptedPat(String base64Pat) async {
    final file = File(getDuckbillKeysPath());
    if (!await file.parent.exists()) {
      await file.parent.create(recursive: true);
    }
    
    final content = jsonEncode({'pat': base64Pat});
    await file.writeAsString(content);
  }

  static Future<String?> getEncryptedPat() async {
    final file = File(getDuckbillKeysPath());
    if (!await file.exists()) {
      return null;
    }
    
    final content = await file.readAsString();
    final jsonPat = jsonDecode(content);
    return jsonPat['pat'] as String?;
  }
}

