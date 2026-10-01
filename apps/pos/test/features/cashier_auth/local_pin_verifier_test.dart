import 'package:flutter_test/flutter_test.dart';
import 'package:sarisupply_pos/features/cashier_auth/data/local_pin_verifier.dart';

void main() {
  final salt = List<int>.generate(16, (index) => index);

  test('derives the expected 32-byte PBKDF2 verifier', () async {
    final result = await LocalPinVerifier.derive('1234', salt);

    expect(result.length, 32);
    expect(
      result.map((byte) => byte.toRadixString(16).padLeft(2, '0')).join(),
      '942eed8586f04aa8cc4b14537eb02bb601b671749b6f95c07a2d2261f83e75a7',
    );
  });

  test('wrong PIN does not match a saved verifier', () async {
    final verifier = await LocalPinVerifier.derive('1234', salt);

    expect(await LocalPinVerifier.matches('1234', salt, verifier), isTrue);
    expect(await LocalPinVerifier.matches('9999', salt, verifier), isFalse);
  });

  test('different salts derive different verifiers', () async {
    final first = await LocalPinVerifier.derive('1234', salt);
    final second = await LocalPinVerifier.derive('1234', List.filled(16, 7));

    expect(second, isNot(first));
  });

  test('rejects invalid PINs and salts', () async {
    expect(() => LocalPinVerifier.derive('123', salt), throwsArgumentError);
    expect(() => LocalPinVerifier.derive('12a4', salt), throwsArgumentError);
    expect(() => LocalPinVerifier.derive('1234567', salt), throwsArgumentError);
    expect(() => LocalPinVerifier.derive('1234', [1]), throwsArgumentError);
  });

  test('generates a 16-byte random salt', () {
    final first = LocalPinVerifier.generateSalt();
    final second = LocalPinVerifier.generateSalt();

    expect(first.length, 16);
    expect(second.length, 16);
    expect(first, isNot(second));
  });
}
