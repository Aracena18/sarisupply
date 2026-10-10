const companyCashOnDelivery = 'cashOnDelivery';
const companyQrPayment = 'qr';

String companyDeliveryPaymentMethod(Map<String, Object?> stop) {
  final raw = stop['paymentMethod'];
  if (raw == null || raw.toString().trim().isEmpty) {
    // Older company delivery stops predate this field and defaulted to COD.
    return companyCashOnDelivery;
  }
  return raw.toString().trim();
}
