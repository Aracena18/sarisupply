import 'package:flutter_test/flutter_test.dart';
import 'package:sarisupply_driver/bootstrap/driver_bootstrap.dart';

void main() {
  test('Driver selects the matching Firebase app for each environment', () {
    expect(
      selectDriverFirebaseOptions('dev').appId,
      '1:594903185972:android:035ca91c2f446c559b6861',
    );
    expect(
      selectDriverFirebaseOptions('prod').appId,
      '1:110781011916:android:7209f0d6375487552bef69',
    );
  });

  test('Driver rejects an unspecified environment', () {
    expect(() => selectDriverFirebaseOptions(''), throwsArgumentError);
  });
}
