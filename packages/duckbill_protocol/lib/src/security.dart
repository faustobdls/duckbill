import 'dart:convert';
import 'package:crypto/crypto.dart';

class DuckbillSecurity {
  final String secretToken;
  static const int maxTtlSeconds = 180;

  DuckbillSecurity(this.secretToken);

  /// Generates HMAC signature for a given payload and timestamp
  String sign(String payload, int timestampMs) {
    var data = payload + ':' + timestampMs.toString();
    final hmac = Hmac(sha256, utf8.encode(secretToken));
    final digest = hmac.convert(utf8.encode(data));
    return digest.toString();
  }

  /// Verifies a signature and checks if the timestamp is within the TTL
  bool verify(String payload, int timestampMs, String signature, {int? currentTimestampMs}) {
    final now = currentTimestampMs ?? DateTime.now().millisecondsSinceEpoch;
    final diff = (now - timestampMs).abs() / 1000;
    
    if (diff > maxTtlSeconds) {
      return false; // Expired or too far in the future
    }

    final expectedSignature = sign(payload, timestampMs);
    
    // Constant time comparison to prevent timing attacks
    if (expectedSignature.length != signature.length) return false;
    
    bool isValid = true;
    for (var i = 0; i < expectedSignature.length; i++) {
        if (expectedSignature.codeUnitAt(i) != signature.codeUnitAt(i)) {
            isValid = false;
        }
    }
    
    return isValid;
  }
}
