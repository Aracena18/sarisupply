import 'dart:convert';
import '../inventory/catalog.dart';
part 'cart.dart';
part 'payment.dart';
part 'shift.dart';
part 'checkout_intent.dart';
part 'cashier_grant.dart';
part 'refund.dart';

const checkoutLimit = 1000000000;
void checkoutId(String value) {
  if (!RegExp(r'^[A-Za-z0-9._-]{1,128}$').hasMatch(value)) {
    throw ArgumentError('Invalid identifier');
  }
}

void checkoutAmount(int value, {int minimum = 0}) {
  if (value < minimum || value > checkoutLimit) {
    throw ArgumentError('Invalid amount');
  }
}

void checkoutText(String value, int max) {
  if (value.trim().isEmpty || value.length > max) {
    throw ArgumentError('Invalid text');
  }
}

Map<String, Object?> checkoutMap(Object? value) =>
    Map<String, Object?>.from(value as Map);
Object? _freezeCheckout(Object? value) {
  if (value is Map) {
    return Map<String, Object?>.unmodifiable(
        value.map((k, v) => MapEntry(k as String, _freezeCheckout(v))));
  }
  if (value is List) {
    return List<Object?>.unmodifiable(value.map(_freezeCheckout));
  }
  return value;
}

int parsePhpCentavos(String value) {
  final text = value.trim();
  if (!RegExp(r'^\d{1,8}(\.\d{1,2})?$').hasMatch(text)) {
    throw const FormatException('Enter a valid PHP amount');
  }
  final parts = text.split('.');
  final amount = int.parse(parts[0]) * 100 +
      (parts.length == 1 ? 0 : int.parse(parts[1].padRight(2, '0')));
  if (amount > checkoutLimit) {
    throw const FormatException('Amount is too large');
  }
  return amount;
}

String formatPhp(int centavos) =>
    '${centavos < 0 ? '-' : ''}₱${centavos.abs() ~/ 100}.${(centavos.abs() % 100).toString().padLeft(2, '0')}';
