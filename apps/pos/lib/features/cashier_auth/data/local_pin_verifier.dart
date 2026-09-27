import 'dart:math';

import 'package:cryptography/cryptography.dart';

abstract final class LocalPinVerifier {
  static const saltLength = 16;
  static const verifierLength = 32;
  static final _pinPattern = RegExp(r'^[0-9]{4,6}$');
  static final _kdf = Pbkdf2.hmacSha256(iterations: 210000, bits: 256);

  static List<int> generateSalt() {
    final random = Random.secure();
    return List<int>.generate(saltLength, (_) => random.nextInt(256));
  }

  static Future<List<int>> derive(String pin, List<int> salt) async {
    if (!_pinPattern.hasMatch(pin)) {
      throw ArgumentError.value(pin, 'pin', 'must be 4–6 numeric digits');
    }
    if (salt.length != saltLength) {
      throw ArgumentError.value(salt.length, 'salt.length', 'must be 16');
    }

    final key = await _kdf.deriveKeyFromPassword(password: pin, nonce: salt);
    return key.extractBytes();
  }

  static Future<bool> matches(
    String pin,
    List<int> salt,
    List<int> expectedVerifier,
  ) async {
    if (expectedVerifier.length != verifierLength) return false;

    final actualVerifier = await derive(pin, salt);
    var difference = 0;
    for (var index = 0; index < verifierLength; index++) {
      difference |= actualVerifier[index] ^ expectedVerifier[index];
    }
    return difference == 0;
  }
}
