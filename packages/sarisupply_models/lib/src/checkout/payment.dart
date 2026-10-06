part of 'checkout.dart';

final class Tender {
  const Tender.cash(this.receivedCentavos)
      : kind = 'cash',
        reference = '',
        confirmed = false,
        creditGrantId = '';
  const Tender.qr(this.reference, {required this.confirmed})
      : kind = 'qr',
        receivedCentavos = 0,
        creditGrantId = '';
  const Tender.credit(this.reference,
      {this.confirmed = true, this.creditGrantId = ''})
      : kind = 'credit',
        receivedCentavos = 0;
  final String kind, reference, creditGrantId;
  final int receivedCentavos;
  final bool confirmed;
  void validate(int total) {
    checkoutAmount(total);
    if (kind == 'cash') {
      checkoutAmount(receivedCentavos);
      if (receivedCentavos < total) {
        throw ArgumentError('Cash received is short');
      }
    } else if (kind == 'qr') {
      checkoutText(reference, 80);
      if (!confirmed || total == 0) {
        throw ArgumentError('Confirm payment in the bank or wallet app');
      }
    } else if (kind == 'credit') {
      checkoutId(reference);
      if (total <= 0) {
        throw ArgumentError('Credit total must be positive');
      }
    }
  }

  Map<String, Object?> toMap() => {
        'kind': kind,
        'receivedCentavos': receivedCentavos,
        'reference': reference,
        'confirmed': confirmed,
        if (kind == 'credit') 'creditGrantId': creditGrantId
      };
  factory Tender.fromMap(Map<String, Object?> m) {
    if (m['kind'] == 'cash') return Tender.cash(m['receivedCentavos'] as int);
    if (m['kind'] == 'qr') {
      return Tender.qr(m['reference'] as String,
          confirmed: m['confirmed'] as bool);
    }
    if (m['kind'] == 'credit') {
      return Tender.credit(m['reference'] as String,
          confirmed: m['confirmed'] as bool? ?? true,
          creditGrantId: m['creditGrantId'] as String? ?? '');
    }
    throw const FormatException('Invalid tender');
  }
}
