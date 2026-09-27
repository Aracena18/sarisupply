import 'package:flutter_test/flutter_test.dart';
import 'package:sarisupply_admin/bootstrap/admin_bootstrap.dart';

void main() {
  test('Admin selects the matching Firebase app for each environment', () {
    expect(
      selectAdminFirebaseOptions('dev').appId,
      '1:594903185972:web:e372a71146e37d499b6861',
    );
    expect(
      selectAdminFirebaseOptions('prod').appId,
      '1:110781011916:web:2a7d6a21a23582672bef69',
    );
  });

  test('Admin rejects an unspecified environment', () {
    expect(() => selectAdminFirebaseOptions(''), throwsArgumentError);
  });
}
