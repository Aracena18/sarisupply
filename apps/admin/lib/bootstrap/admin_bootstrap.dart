import 'package:firebase_core/firebase_core.dart';
import 'package:sarisupply_firebase/sarisupply_firebase.dart';

import '../firebase_config_dev.dart' as dev;
import '../firebase_config_prod.dart' as prod;

FirebaseOptions selectAdminFirebaseOptions(String environment) {
  return switch (parseSariSupplyEnvironment(environment)) {
    SariSupplyEnvironment.dev => dev.DefaultFirebaseOptions.web,
    SariSupplyEnvironment.prod => prod.DefaultFirebaseOptions.web,
  };
}
