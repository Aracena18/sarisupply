import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sarisupply_firebase/sarisupply_firebase.dart';

void main() {
  const dev = FirebaseOptions(
    apiKey: 'dev-key',
    appId: 'dev-app',
    messagingSenderId: '1',
    projectId: 'sarisupply-dev',
  );
  const prod = FirebaseOptions(
    apiKey: 'prod-key',
    appId: 'prod-app',
    messagingSenderId: '2',
    projectId: 'sarisupply-prod',
  );

  test('reusing an app from another environment is rejected', () {
    expect(
      () => FirebaseBootstrap.requireMatchingOptions(dev, prod),
      throwsStateError,
    );
  });

  test('reusing the same Firebase app configuration is allowed', () {
    expect(() => FirebaseBootstrap.requireMatchingOptions(dev, dev),
        returnsNormally);
  });
}
