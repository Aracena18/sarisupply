import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sarisupply_admin/bootstrap/admin_bootstrap.dart';

void main() {
  test('Admin selects the matching Firebase app for each environment', () {
    expect(selectAdminFirebaseOptions('dev').projectId,
        'sarisupply-dev-aracena18');
    expect(selectAdminFirebaseOptions('prod').projectId,
        'sarisupply-prod-aracena18');
    expect(
      selectAdminFirebaseOptions('dev').appId,
      kIsWeb
          ? '1:594903185972:web:e372a71146e37d499b6861'
          : '1:594903185972:android:234147b6f37526ba9b6861',
    );
    if (kIsWeb) {
      expect(selectAdminFirebaseOptions('prod').appId,
          '1:110781011916:web:2a7d6a21a23582672bef69');
    }
  });

  test('Admin rejects an unspecified environment', () {
    expect(() => selectAdminFirebaseOptions(''), throwsArgumentError);
  });
}
