import 'package:duckbill_storage/duckbill_storage.dart';

Future<void> main() async {
  final manager = JsonConfigManager('config.json');
  final value = await manager.load();
  print(value);
}
