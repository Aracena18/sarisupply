import 'package:flutter_test/flutter_test.dart';
import 'package:sarisupply_pos/bootstrap/pos_bootstrap.dart';

void main() {
  test('POS selects the matching Firebase app for each environment', () {
    expect(
      selectPosFirebaseOptions('dev').appId,
      '1:594903185972:android:0344c52bad5280009b6861',
    );
    expect(
      selectPosFirebaseOptions('prod').appId,
      '1:110781011916:android:777cd24a1af275062bef69',
    );
  });

  test('POS rejects an unspecified environment', () {
    expect(() => selectPosFirebaseOptions(''), throwsArgumentError);
  });
}
