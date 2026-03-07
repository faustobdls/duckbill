import 'package:duckbill_crypto/duckbill_crypto.dart';

Future<void> main() async {
  final manager = CryptoManager();
  final key = await manager.algorithm.newSecretKey();
  
  final encrypted = await manager.encrypt('my_secret', key);
  print(encrypted);
}
