import 'package:flutter_test/flutter_test.dart';
import 'package:sarisupply_core/sarisupply_core.dart';

void main() {
  test('exposes stable application names', () {
    expect(AppIdentity.posName, 'SariSupply POS');
    expect(AppIdentity.driverName, 'SariSupply Driver');
    expect(AppIdentity.adminName, 'SariSupply Admin');
  });
}
