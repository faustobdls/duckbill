import 'package:duckbill_protocol/duckbill_protocol.dart';

void main() {
  final security = DuckbillSecurity('my_token');
  print(security.secretToken);
}
