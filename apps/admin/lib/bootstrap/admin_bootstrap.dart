import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:sarisupply_firebase/sarisupply_firebase.dart';

import '../firebase_config_dev.dart' as dev;
import '../firebase_config_prod.dart' as prod;

FirebaseOptions selectAdminFirebaseOptions(String environment) {
  final isDev =
      parseSariSupplyEnvironment(environment) == SariSupplyEnvironment.dev;
  if (kIsWeb) {
    return isDev
        ? dev.DefaultFirebaseOptions.web
        : prod.DefaultFirebaseOptions.web;
  }
  return isDev
      ? dev.DefaultFirebaseOptions.currentPlatform
      : prod.DefaultFirebaseOptions.currentPlatform;
}
