import 'package:flutter_test/flutter_test.dart';
import 'package:sarisupply_firebase/src/environment/sarisupply_environment.dart';

void main() {
  test('accepts only dev and prod', () {
    expect(
      parseSariSupplyEnvironment('dev'),
      SariSupplyEnvironment.dev,
    );
    expect(
      parseSariSupplyEnvironment('prod'),
      SariSupplyEnvironment.prod,
    );
    expect(
      () => parseSariSupplyEnvironment('staging'),
      throwsArgumentError,
    );
  });
}
