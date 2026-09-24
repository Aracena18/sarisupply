import 'package:flutter_test/flutter_test.dart';
import 'package:sarisupply_models/sarisupply_models.dart';

void main() {
  group('Money', () {
    test('adds values using integer centavos', () {
      const left = Money(1050);
      const right = Money(250);

      expect(left + right, const Money(1300));
    });

    test('rejects a negative amount when nonNegative is requested', () {
      expect(
        () => Money.nonNegative(-1),
        throwsArgumentError,
      );
    });
  });
}
