import 'package:duckbill_storage/duckbill_storage.dart';

void main() {
  final manager = JsonConfigManager('config.json');
  manager.load().then((value) => print(value));
}
