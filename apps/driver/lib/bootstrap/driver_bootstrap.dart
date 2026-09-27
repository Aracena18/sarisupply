import 'package:firebase_core/firebase_core.dart';
import 'package:sarisupply_firebase/sarisupply_firebase.dart';

import '../firebase_config_dev.dart' as dev;
import '../firebase_config_prod.dart' as prod;

FirebaseOptions selectDriverFirebaseOptions(String environment) {
  return switch (parseSariSupplyEnvironment(environment)) {
    SariSupplyEnvironment.dev => dev.DefaultFirebaseOptions.android,
    SariSupplyEnvironment.prod => prod.DefaultFirebaseOptions.android,
  };
}
