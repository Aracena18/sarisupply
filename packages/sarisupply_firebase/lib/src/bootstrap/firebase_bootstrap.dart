import 'package:firebase_core/firebase_core.dart';

/// Keeps human and device Auth sessions on separate Firebase app instances.
final class FirebaseBootstrap {
  static const deviceAppName = 'sarisupply-device';

  static Future<FirebaseApp> initializeHuman(FirebaseOptions options) {
    return _initialize(defaultFirebaseAppName, options);
  }

  static Future<FirebaseApp> initializeDevice(FirebaseOptions options) {
    return _initialize(deviceAppName, options);
  }

  static Future<FirebaseApp> _initialize(
    String name,
    FirebaseOptions options,
  ) async {
    for (final app in Firebase.apps) {
      if (app.name == name) {
        requireMatchingOptions(app.options, options);
        return app;
      }
    }

    if (name == defaultFirebaseAppName) {
      return Firebase.initializeApp(options: options);
    }
    return Firebase.initializeApp(name: name, options: options);
  }

  static void requireMatchingOptions(
    FirebaseOptions existing,
    FirebaseOptions requested,
  ) {
    if (existing.projectId != requested.projectId ||
        existing.appId != requested.appId ||
        existing.messagingSenderId != requested.messagingSenderId ||
        existing.apiKey != requested.apiKey) {
      throw StateError('Firebase app is already configured for another app');
    }
  }
}
