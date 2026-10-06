import 'dart:typed_data';
import 'package:sarisupply_models/sarisupply_models.dart';
import 'esc_pos_builder.dart';

class ReceiptCartLine {
  const ReceiptCartLine({
    required this.name,
    required this.unit,
    required this.quantity,
    required this.unitPriceCentavos,
    required this.totalCentavos,
  });

  final String name;
  final String unit;
  final int quantity;
  final int unitPriceCentavos;
  final int totalCentavos;

  factory ReceiptCartLine.fromCartLine(CartLine line) => ReceiptCartLine(
        name: line.name,
        unit: line.unit,
        quantity: line.quantity,
        unitPriceCentavos: line.priceCentavos,
        totalCentavos: line.totalCentavos,
      );
}

class ReceiptDocument {
  const ReceiptDocument({
    required this.bytes,
    required this.plaintext,
    required this.paperSize,
  });

  final Uint8List bytes;
  final String plaintext;
  final EscPosPaperSize paperSize;
}

class ReceiptFormatter {
  static String _formatPhp(int centavos) =>
      'PHP ${(centavos / 100).toStringAsFixed(2)}';

  static String _padTwo(String left, String right, int width) {
    final available = width - right.length - 1;
    String cleanLeft = left;
    if (cleanLeft.length > available && available > 0) {
      cleanLeft = '${cleanLeft.substring(0, available - 1)}…';
    }
    final spaces = width - (cleanLeft.length + right.length);
    return '$cleanLeft${spaces > 0 ? ' ' * spaces : ' '}$right';
  }

  /// Formats a complete customer sales receipt from individual properties.
  static ReceiptDocument formatSalesReceipt({
    required String merchantName,
    required String branchName,
    required String saleId,
    required String shiftId,
    required String cashierName,
    required DateTime occurredAt,
    required List<ReceiptCartLine> lines,
    required int grossSalesCentavos,
    int discountsCentavos = 0,
    required int netSalesCentavos,
    required String tenderKind,
    required int amountReceivedCentavos,
    required int changeCentavos,
    EscPosPaperSize paperSize = EscPosPaperSize.mm58,
    String? footerNote,
  }) {
    final builder = EscPosBuilder(paperSize: paperSize);
    final textBuffer = StringBuffer();
    final width = paperSize.columns;
    final hrLine = '-' * width;
    final dblHrLine = '=' * width;

    void addLine(String line) {
      textBuffer.writeln(line);
    }

    void addTwo(String left, String right, {bool bold = false}) {
      builder.twoColumns(left, right, bold: bold);
      addLine(_padTwo(left, right, width));
    }

    void addCentered(String line,
        {bool bold = false, bool doubleHeight = false}) {
      builder.textLine(line,
          alignment: EscPosAlign.center,
          bold: bold,
          doubleHeight: doubleHeight);
      final pad = (width - line.length) ~/ 2;
      addLine('${pad > 0 ? ' ' * pad : ''}$line');
    }

    // Header
    addCentered(merchantName.toUpperCase(), bold: true, doubleHeight: true);
    addCentered(branchName);
    addLine(hrLine);
    builder.hr();

    // Metadata
    addTwo('Date:', occurredAt.toLocal().toString().split('.').first);
    addTwo('Sale ID:', saleId.length > 12 ? saleId.substring(0, 12) : saleId);
    addTwo('Shift / Cashier:', '$shiftId / $cashierName');
    addLine(dblHrLine);
    builder.textLine(dblHrLine);

    // Items
    for (final item in lines) {
      final itemTotal = _formatPhp(item.totalCentavos);
      addTwo(item.name, itemTotal, bold: true);
      final detail =
          '  ${item.quantity} ${item.unit} @ ${_formatPhp(item.unitPriceCentavos)}';
      builder.textLine(detail);
      addLine(detail);
    }

    addLine(hrLine);
    builder.hr();

    // Totals
    addTwo('GROSS TOTAL:', _formatPhp(grossSalesCentavos));
    if (discountsCentavos > 0) {
      addTwo('DISCOUNT:', '-${_formatPhp(discountsCentavos)}');
    }
    addTwo('NET AMOUNT:', _formatPhp(netSalesCentavos), bold: true);
    addTwo('Tender ($tenderKind):', _formatPhp(amountReceivedCentavos));
    addTwo('CHANGE:', _formatPhp(changeCentavos), bold: true);

    addLine(dblHrLine);
    builder.textLine(dblHrLine);

    // Footer
    addCentered(
        footerNote ?? 'THANK YOU FOR SHOPPING!\nSariSupply Offline Retail OS');
    addLine('');
    builder.feed(2);
    builder.cut();

    return ReceiptDocument(
      bytes: builder.toBytes(),
      plaintext: textBuffer.toString(),
      paperSize: paperSize,
    );
  }

  /// Convenience wrapper to format a [CheckoutSale] domain object.
  static ReceiptDocument formatCheckoutSale({
    required String merchantName,
    required String branchName,
    required CheckoutSale sale,
    String cashierName = 'Cashier',
    EscPosPaperSize paperSize = EscPosPaperSize.mm58,
  }) {
    final lines = sale.lines.map(ReceiptCartLine.fromCartLine).toList();
    final gross =
        lines.fold(0, (sum, l) => sum + (l.unitPriceCentavos * l.quantity));
    final net = sale.totalCentavos;
    final discount = (gross - net).clamp(0, gross);

    final String tenderKind;
    final int received;
    final int change = sale.changeCentavos;

    if (sale.tender.kind == 'cash') {
      tenderKind = 'Cash';
      received = sale.tender.receivedCentavos;
    } else if (sale.tender.kind == 'qr') {
      tenderKind = 'QR/E-Wallet';
      received = net;
    } else if (sale.tender.kind == 'credit') {
      tenderKind = 'Store Credit';
      received = net;
    } else {
      tenderKind = sale.tender.kind;
      received = net;
    }

    return formatSalesReceipt(
      merchantName: merchantName,
      branchName: branchName,
      saleId: sale.id,
      shiftId: sale.shiftId,
      cashierName: cashierName,
      occurredAt: sale.occurredAt,
      lines: lines,
      grossSalesCentavos: gross,
      discountsCentavos: discount,
      netSalesCentavos: net,
      tenderKind: tenderKind,
      amountReceivedCentavos: received,
      changeCentavos: change,
      paperSize: paperSize,
    );
  }

  /// Formats a Z-Reading shift closing document.
  static ReceiptDocument formatZReadingReceipt({
    required String merchantName,
    required String branchName,
    required ZReading zReading,
    EscPosPaperSize paperSize = EscPosPaperSize.mm58,
  }) {
    final builder = EscPosBuilder(paperSize: paperSize);
    final textBuffer = StringBuffer();
    final width = paperSize.columns;
    final hrLine = '-' * width;
    final dblHrLine = '=' * width;

    void addLine(String line) => textBuffer.writeln(line);

    void addTwo(String left, String right, {bool bold = false}) {
      builder.twoColumns(left, right, bold: bold);
      addLine(_padTwo(left, right, width));
    }

    void addCentered(String line,
        {bool bold = false, bool doubleHeight = false}) {
      builder.textLine(line,
          alignment: EscPosAlign.center,
          bold: bold,
          doubleHeight: doubleHeight);
      final pad = (width - line.length) ~/ 2;
      addLine('${pad > 0 ? ' ' * pad : ''}$line');
    }

    addCentered(merchantName.toUpperCase(), bold: true, doubleHeight: true);
    addCentered(branchName);
    addCentered('*** OFFICIAL Z-READING ***', bold: true);
    addLine(hrLine);
    builder.hr();

    addTwo('Z-Report ID:', zReading.id);
    addTwo('Shift ID:', zReading.shiftId);
    addTwo('Cashier:', '${zReading.cashierId} (${zReading.cashierName})');
    addTwo(
        'Closed At:', zReading.closedAt.toLocal().toString().split('.').first);
    addLine(dblHrLine);
    builder.textLine(dblHrLine);

    // Sales Summary
    addTwo('Gross Sales:', _formatPhp(zReading.grossSalesCentavos));
    addTwo('Refunds:', '-${_formatPhp(zReading.refundsCentavos)}');
    addTwo('Voids:', '-${_formatPhp(zReading.voidsCentavos)}');
    addTwo('NET SALES:', _formatPhp(zReading.netSalesCentavos), bold: true);
    addTwo('Transactions:', '${zReading.transactionCount}');
    addLine(hrLine);
    builder.hr();

    // Tender Breakdown
    addCentered('-- TENDER BREAKDOWN --');
    addTwo('Cash:', _formatPhp(zReading.tenders.cashCentavos));
    addTwo('QR / Digital:', _formatPhp(zReading.tenders.qrCentavos));
    addTwo('Credit / Utang:', _formatPhp(zReading.tenders.creditCentavos));
    addLine(hrLine);
    builder.hr();

    // Cash Reconciliation
    addCentered('-- CASH DRAWER RECONCILIATION --');
    addTwo('Opening Float:', _formatPhp(zReading.openingFloatCentavos));
    addTwo('Cash Sales:', _formatPhp(zReading.tenders.cashCentavos));
    addTwo('Cash In (+):', _formatPhp(zReading.cashInCentavos));
    addTwo('Cash Out (-):', '-${_formatPhp(zReading.cashOutCentavos)}');
    addTwo('Expected In Drawer:', _formatPhp(zReading.expectedCashCentavos),
        bold: true);
    addTwo('Counted In Drawer:', _formatPhp(zReading.countedCashCentavos),
        bold: true);

    final overShort = zReading.varianceCentavos;
    final overShortLabel = overShort >= 0
        ? '+${_formatPhp(overShort)} (OVER)'
        : '-${_formatPhp(overShort.abs())} (SHORT)';
    addTwo('OVER / (SHORT):', overShortLabel, bold: true);

    addLine(dblHrLine);
    builder.textLine(dblHrLine);
    addCentered('END OF Z-READING\nStore Manager Signature: _________');
    builder.feed(3);
    builder.cut();

    return ReceiptDocument(
      bytes: builder.toBytes(),
      plaintext: textBuffer.toString(),
      paperSize: paperSize,
    );
  }

  /// Formats delivery proof receipt for driver deliveries.
  static ReceiptDocument formatDeliveryReceipt({
    required String merchantName,
    required String runId,
    required DeliveryStop stop,
    EscPosPaperSize paperSize = EscPosPaperSize.mm58,
  }) {
    final builder = EscPosBuilder(paperSize: paperSize);
    final textBuffer = StringBuffer();
    final width = paperSize.columns;
    final hrLine = '-' * width;
    final dblHrLine = '=' * width;

    void addLine(String line) => textBuffer.writeln(line);

    void addTwo(String left, String right, {bool bold = false}) {
      builder.twoColumns(left, right, bold: bold);
      addLine(_padTwo(left, right, width));
    }

    void addCentered(String line,
        {bool bold = false, bool doubleHeight = false}) {
      builder.textLine(line,
          alignment: EscPosAlign.center,
          bold: bold,
          doubleHeight: doubleHeight);
      final pad = (width - line.length) ~/ 2;
      addLine('${pad > 0 ? ' ' * pad : ''}$line');
    }

    addCentered(merchantName.toUpperCase(), bold: true);
    addCentered('DELIVERY RECEIPT');
    addLine(hrLine);
    builder.hr();

    addTwo('Run ID:', runId);
    addTwo('Stop #:', '${stop.sequence}');
    addTwo('Customer:', stop.destinationName);
    addTwo('Phone:', stop.contactPhone);
    addTwo('Status:', stop.status.name.toUpperCase(), bold: true);
    addLine(dblHrLine);
    builder.textLine(dblHrLine);

    for (final item in stop.items) {
      addTwo(item.productName,
          '${item.quantityDelivered}/${item.quantityOrdered} ${item.unitName}');
      if (item.quantityReturned > 0) {
        addTwo('  Returned:',
            '${item.quantityReturned} (${item.returnReason ?? ''})');
      }
    }

    addLine(hrLine);
    builder.hr();

    if (stop.proof != null) {
      addTwo('Recipient:', stop.proof!.recipientName);
      addTwo('Role:', stop.proof!.recipientRole);
      addTwo('Cash Collected:', _formatPhp(stop.proof!.cashCollectedCentavos));
      addTwo('Signed At:',
          stop.proof!.deliveredAt.toLocal().toString().split('.').first);
    }

    addLine(dblHrLine);
    builder.textLine(dblHrLine);
    addCentered('SariSupply Distribution Network');
    builder.feed(2);
    builder.cut();

    return ReceiptDocument(
      bytes: builder.toBytes(),
      plaintext: textBuffer.toString(),
      paperSize: paperSize,
    );
  }
}
