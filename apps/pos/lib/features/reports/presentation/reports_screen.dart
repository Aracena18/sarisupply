import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sarisupply_core/sarisupply_core.dart';
import 'package:sarisupply_design_system/sarisupply_design_system.dart';
import 'package:sarisupply_inventory/sarisupply_inventory.dart';
import 'package:sarisupply_models/sarisupply_models.dart';
import 'receipt_preview_dialog.dart';
import '../../diagnostics/presentation/diagnostic_recovery_screen.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({
    super.key,
    required this.store,
    required this.branchName,
    this.isOwner = true,
    this.initialTabIndex = 0,
  });

  final InventoryStore store;
  final String branchName;
  final bool isOwner;
  final int initialTabIndex;

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  bool _loading = true;
  String? _error;

  DailySalesSummary? _salesSummary;
  InventoryValuationReport? _valuation;
  EncryptedBackupArchive? _latestBackup;
  String? _verificationResult;

  DateTime _selectedDate = DateTime.now();
  final _backupPasswordController = TextEditingController();
  EscPosPaperSize _printerPaperSize = EscPosPaperSize.mm58;

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  @override
  void dispose() {
    _backupPasswordController.dispose();
    super.dispose();
  }

  Future<void> _loadAll() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final summary = await widget.store.checkout
          .generateDailySalesSummary(date: _selectedDate);
      final valuation = await widget.store.generateInventoryValuation();

      if (mounted) {
        setState(() {
          _salesSummary = summary;
          _valuation = valuation;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _loading = false;
        });
      }
    }
  }

  String _formatPhp(int centavos) => '₱${(centavos / 100).toStringAsFixed(2)}';

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      initialIndex: widget.initialTabIndex,
      length: 4,
      child: Scaffold(
        appBar: sariSupplyTaskAppBar(
          context,
          title: 'Reports & Archival',
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh),
              tooltip: 'Refresh Reports',
              onPressed: _loadAll,
            ),
          ],
        ),
        body: SafeArea(
          child: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 900),
              child: Padding(
                padding: EdgeInsets.all(
                    MediaQuery.sizeOf(context).width < 600 ? 16 : 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TabBar(
                      isScrollable: true,
                      tabs: const [
                        Tab(
                            icon: Icon(Icons.point_of_sale),
                            text: 'Daily Sales'),
                        Tab(icon: Icon(Icons.assessment), text: 'Valuation'),
                        Tab(
                            icon: Icon(Icons.lock_clock),
                            text: 'Backup & Archival'),
                        Tab(icon: Icon(Icons.print), text: 'Printer Settings'),
                      ],
                    ),
                    const SizedBox(height: 16),
                    if (_loading)
                      const Center(
                        child: Padding(
                          padding: EdgeInsets.all(48),
                          child: CircularProgressIndicator(),
                        ),
                      )
                    else if (_error != null)
                      SariSupplyStatus(
                        message: 'Unable to generate reports: $_error',
                        error: true,
                        actions: [
                          TextButton(
                            onPressed: _loadAll,
                            child: const Text('Retry'),
                          ),
                        ],
                      )
                    else
                      Expanded(
                        child: TabBarView(
                          children: [
                            _buildDailySalesTab(),
                            _buildValuationTab(),
                            _buildBackupTab(),
                            _buildPrinterTab(),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDailySalesTab() {
    final s = _salesSummary ??
        DailySalesSummary(
          date: _selectedDate.toIso8601String().split('T').first,
          branchId: widget.store.branchId,
        );

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            spacing: 12,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                'Date: ${s.date}',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              OutlinedButton.icon(
                icon: const Icon(Icons.calendar_today, size: 16),
                label: const Text('Change Date'),
                onPressed: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: _selectedDate,
                    firstDate: DateTime(2020),
                    lastDate: DateTime.now().add(const Duration(days: 1)),
                  );
                  if (picked != null) {
                    setState(() => _selectedDate = picked);
                    _loadAll();
                  }
                },
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Metric Cards
          _metricGroup(
            children: [
              _buildMetricCard(
                title: 'Net Sales',
                value: _formatPhp(s.netSalesCentavos),
                color: Colors.green.shade700,
                icon: Icons.payments,
              ),
              _buildMetricCard(
                title: 'Gross Sales',
                value: _formatPhp(s.grossSalesCentavos),
                color: Colors.blue.shade700,
                icon: Icons.receipt,
              ),
              _buildMetricCard(
                title: 'Transactions',
                value: '${s.transactionCount}',
                color: Colors.purple.shade700,
                icon: Icons.shopping_bag,
              ),
            ],
          ),
          const SizedBox(height: 12),
          _metricGroup(
            children: [
              _buildMetricCard(
                title: 'Refunds / Returns',
                value: '-${_formatPhp(s.refundsCentavos)}',
                color: Colors.amber.shade900,
                icon: Icons.assignment_return,
              ),
              _buildMetricCard(
                title: 'Voided Sales',
                value: '-${_formatPhp(s.voidsCentavos)}',
                color: Colors.red.shade700,
                icon: Icons.cancel,
              ),
              _buildMetricCard(
                title: 'Discounts',
                value: '-${_formatPhp(s.discountsCentavos)}',
                color: Colors.indigo.shade700,
                icon: Icons.local_offer,
              ),
            ],
          ),
          const SizedBox(height: 20),
          // Tender breakdown card
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: Colors.grey.shade300),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Payment Methods / Tenders',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const Divider(height: 20),
                  _buildRow('Cash Sales', _formatPhp(s.tenders.cashCentavos)),
                  _buildRow('QR / Digital Payments',
                      _formatPhp(s.tenders.qrCentavos)),
                  _buildRow('Store Credit (Utang)',
                      _formatPhp(s.tenders.creditCentavos)),
                  const Divider(),
                  _buildRow(
                    'Total Collected',
                    _formatPhp(s.tenders.totalCentavos),
                    bold: true,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          // Cash drawer card
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: Colors.grey.shade300),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Cash Drawer Activity',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const Divider(height: 20),
                  _buildRow(
                      'Opening Float', _formatPhp(s.openingFloatCentavos)),
                  _buildRow('Cash In (+)', _formatPhp(s.cashInCentavos)),
                  _buildRow(
                      'Cash Out (-)', '-${_formatPhp(s.cashOutCentavos)}'),
                  _buildRow(
                    'Expected Cash in Drawer',
                    _formatPhp(s.expectedCashCentavos),
                    bold: true,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          // Action buttons
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.file_download),
                  label: const Text('Export CSV'),
                  onPressed: () {
                    final csv = BackupArchiveService.exportSalesCsv([s]);
                    Clipboard.setData(ClipboardData(text: csv));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                            'Sales CSV copied to clipboard (Ready for Excel/Sheets)'),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton.icon(
                  icon: const Icon(Icons.receipt_long),
                  label: const Text('Z-Reading Preview'),
                  onPressed: () => _showZReadingPreview(s),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  void _showZReadingPreview(DailySalesSummary s) {
    final z = ZReading(
      id: 'Z-${s.date.replaceAll('-', '')}-001',
      readingNumber: 1,
      shiftId: 'SHIFT-TODAY',
      branchId: widget.store.branchId,
      deviceId: 'POS-01',
      cashierId: 'CASHIER-ACTIVE',
      cashierName: 'Active Cashier',
      openedAt: _selectedDate,
      closedAt: DateTime.now(),
      openingFloatCentavos: s.openingFloatCentavos,
      grossSalesCentavos: s.grossSalesCentavos,
      netSalesCentavos: s.netSalesCentavos,
      refundsCentavos: s.refundsCentavos,
      voidsCentavos: s.voidsCentavos,
      transactionCount: s.transactionCount,
      tenders: s.tenders,
      cashInCentavos: s.cashInCentavos,
      cashOutCentavos: s.cashOutCentavos,
      expectedCashCentavos: s.expectedCashCentavos,
      countedCashCentavos: s.expectedCashCentavos,
      varianceCentavos: 0,
    );

    final doc = ReceiptFormatter.formatZReadingReceipt(
      merchantName: 'SariSupply Store',
      branchName: widget.branchName,
      zReading: z,
      paperSize: _printerPaperSize,
    );

    showDialog<void>(
      context: context,
      builder: (_) => ReceiptPreviewDialog(
        document: doc,
        title: 'Shift report Document',
      ),
    );
  }

  Widget _buildValuationTab() {
    final val = _valuation;
    if (val == null) return const SizedBox.shrink();

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SariSupplyStatus(
              message:
                  'Local stock including pending movements. Purchase cost and profit are unavailable until branch cost records are connected.'),
          const SizedBox(height: 12),

          _metricGroup(
            children: [
              _buildMetricCard(
                title: 'Retail Inventory Value',
                value: _formatPhp(val.totalRetailValueCentavos),
                color: Colors.teal.shade700,
                icon: Icons.storefront,
              ),
              _buildMetricCard(
                title: 'Total Cost Value',
                value: (val.totalCostValueCentavos == null
                    ? 'Unavailable'
                    : _formatPhp(val.totalCostValueCentavos!)),
                color: Colors.blueGrey.shade700,
                icon: Icons.inventory_2,
              ),
              _buildMetricCard(
                title: 'Potential Profit',
                value: (val.totalPotentialProfitCentavos == null
                    ? 'Unavailable'
                    : _formatPhp(val.totalPotentialProfitCentavos!)),
                color: Colors.green.shade800,
                icon: Icons.trending_up,
              ),
            ],
          ),
          const SizedBox(height: 12),
          _metricGroup(
            children: [
              _buildMetricCard(
                title: 'Active SKUs',
                value: '${val.totalSkus}',
                color: Colors.indigo.shade700,
                icon: Icons.category,
              ),
              _buildMetricCard(
                title: 'Low Stock (< 10)',
                value: '${val.lowStockCount}',
                color: Colors.amber.shade900,
                icon: Icons.warning_amber,
              ),
              _buildMetricCard(
                title: 'Out of Stock',
                value: '${val.outOfStockCount}',
                color: Colors.red.shade700,
                icon: Icons.remove_shopping_cart,
              ),
            ],
          ),
          const SizedBox(height: 20),
          // Stock movements card
          if (val.movementSummary != null) ...[
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: Colors.grey.shade300),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Aggregated Stock Movements',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const Divider(height: 20),
                    _buildRow('Received from POs (+)',
                        '${val.movementSummary!.receivedQuantity} units'),
                    _buildRow('Sold to Customers (-)',
                        '${val.movementSummary!.soldQuantity} units'),
                    _buildRow('Customer Returns (+)',
                        '${val.movementSummary!.returnedCustomerQuantity} units'),
                    _buildRow('Transfers Dispatched (-)',
                        '${val.movementSummary!.transferredOutQuantity} units'),
                    _buildRow('Transfers Received (+)',
                        '${val.movementSummary!.transferredInQuantity} units'),
                    _buildRow('Adjustments & Counts',
                        '${val.movementSummary!.adjustedQuantity} units'),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],
          // Valuation Item List
          Wrap(
            spacing: 12,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                'Product Valuation Table (${val.products.length})',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              TextButton.icon(
                icon: const Icon(Icons.file_download, size: 16),
                label: const Text('Export Valuation CSV'),
                onPressed: () {
                  final csv = BackupArchiveService.exportInventoryCsv(val);
                  Clipboard.setData(ClipboardData(text: csv));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Valuation CSV copied to clipboard'),
                    ),
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: 8),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: val.products.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, i) {
              final p = val.products[i];
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(p.name,
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                    Text(
                        'SKU: ${p.sku} · Qty: ${p.physicalQuantity} ${p.unitName}'),
                    Text(
                        'Retail value: ${_formatPhp(p.totalRetailValueCentavos)}'),
                    Text(
                        'Cost: ${p.totalCostValueCentavos == null ? 'Unavailable' : _formatPhp(p.totalCostValueCentavos!)}'),
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildBackupTab() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: Colors.grey.shade300),
            ),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.shield, color: Colors.indigo, size: 28),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Local Encrypted Database Backup',
                              style: Theme.of(context)
                                  .textTheme
                                  .titleSmall
                                  ?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                            ),
                            Text(
                              'AES-256-GCM encryption with PBKDF2 key derivation and tamper-evident SHA-256 hash manifest.',
                              style: TextStyle(
                                  fontSize: 12, color: Colors.grey.shade600),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 28),
                  TextField(
                    controller: _backupPasswordController,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'Archive Encryption Passphrase',
                      helperText:
                          'Minimum 6 characters. Required to decrypt backup.',
                      prefixIcon: Icon(Icons.password),
                    ),
                  ),
                  const SizedBox(height: 20),
                  FilledButton.icon(
                    icon: const Icon(Icons.archive),
                    label: const Text('Export Encrypted Backup Now'),
                    onPressed: () async {
                      try {
                        final archive = await widget.store.exportBackupArchive(
                          password: _backupPasswordController.text,
                        );
                        setState(() {
                          _latestBackup = archive;
                          _verificationResult = null;
                        });
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                'Encrypted archive generated: ${archive.manifest.recordCount} records',
                              ),
                              backgroundColor: Colors.green.shade800,
                            ),
                          );
                        }
                      } catch (e) {
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Backup failed: $e')),
                          );
                        }
                      }
                    },
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          if (_latestBackup != null) ...[
            Card(
              color: Colors.blue.shade50,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: Colors.blue.shade200),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Tamper-Evident Archive Manifest',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.blue.shade900,
                      ),
                    ),
                    const SizedBox(height: 8),
                    _buildRow(
                        'Records:', '${_latestBackup!.manifest.recordCount}'),
                    _buildRow('Created At:', _latestBackup!.manifest.createdAt),
                    _buildRow(
                      'SHA-256:',
                      '${_latestBackup!.manifest.sha256Hash.substring(0, 16)}…',
                    ),
                    const Divider(),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            icon: const Icon(Icons.copy, size: 16),
                            label: const Text('Copy JSON'),
                            onPressed: () {
                              Clipboard.setData(
                                ClipboardData(
                                  text: jsonEncode(_latestBackup!.toMap()),
                                ),
                              );
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content:
                                      Text('Archive JSON copied to clipboard'),
                                ),
                              );
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: FilledButton.icon(
                            icon: const Icon(Icons.verified_user, size: 16),
                            label: const Text('Test Verification'),
                            onPressed: () async {
                              try {
                                final res = await BackupArchiveService
                                    .verifyBackupArchive(
                                  archive: _latestBackup!,
                                  password: _backupPasswordController.text,
                                );
                                setState(() {
                                  _verificationResult =
                                      'VERIFIED OK: Decrypted ${res['sales']?.length ?? 0} sales. SHA-256 matched!';
                                });
                              } catch (e) {
                                setState(() {
                                  _verificationResult = 'FAILED: $e';
                                });
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                    if (_verificationResult != null) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: _verificationResult!.startsWith('VERIFIED')
                              ? Colors.green.shade100
                              : Colors.red.shade100,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          _verificationResult!,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                            color: _verificationResult!.startsWith('VERIFIED')
                                ? Colors.green.shade900
                                : Colors.red.shade900,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],
          // Retention notice
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.amber.shade50,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.amber.shade300),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline, color: Colors.amber.shade900),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Keep two verified owner-controlled backup copies. Business records are not automatically deleted.',
                    style:
                        TextStyle(fontSize: 12, color: Colors.amber.shade900),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            icon: const Icon(Icons.health_and_safety_outlined),
            label: const Text('Open System Diagnostics & Recovery'),
            onPressed: () {
              Navigator.of(context).push(MaterialPageRoute<void>(
                builder: (_) => DiagnosticRecoveryScreen(
                  store: widget.store,
                ),
              ));
            },
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildPrinterTab() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: Colors.grey.shade300),
            ),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Thermal Printer Settings (ESC/POS)',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Direct ESC/POS command generation for Bluetooth and USB receipt printers. Zero cloud print service fees.',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
                  const Divider(height: 28),
                  Text(
                    'Paper Roll Width',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.grey.shade800,
                    ),
                  ),
                  const SizedBox(height: 10),
                  SegmentedButton<EscPosPaperSize>(
                    segments: const [
                      ButtonSegment(
                        value: EscPosPaperSize.mm58,
                        label: Text('58mm (32 Columns)'),
                        icon: Icon(Icons.receipt),
                      ),
                      ButtonSegment(
                        value: EscPosPaperSize.mm80,
                        label: Text('80mm (42 Columns)'),
                        icon: Icon(Icons.receipt_long),
                      ),
                    ],
                    selected: {_printerPaperSize},
                    onSelectionChanged: (val) {
                      setState(() => _printerPaperSize = val.first);
                    },
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.meeting_room),
                          label: const Text('Cash Drawer Kick'),
                          onPressed: null,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: FilledButton.icon(
                          icon: const Icon(Icons.print),
                          label: const Text('Preview Test Receipt'),
                          onPressed: _showTestReceiptPreview,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  void _showTestReceiptPreview() {
    final doc = ReceiptFormatter.formatSalesReceipt(
      merchantName: 'Sample Sari Store',
      branchName: widget.branchName,
      saleId: 'TEST-1001',
      shiftId: 'SHIFT-01',
      cashierName: 'Cashier 1',
      occurredAt: DateTime.now(),
      lines: const [
        ReceiptCartLine(
          name: 'Mineral Water 500ml',
          unit: 'bottle',
          quantity: 2,
          unitPriceCentavos: 1500,
          totalCentavos: 3000,
        ),
        ReceiptCartLine(
          name: 'Chocolate Biscuit',
          unit: 'pack',
          quantity: 1,
          unitPriceCentavos: 1000,
          totalCentavos: 1000,
        ),
      ],
      grossSalesCentavos: 4000,
      netSalesCentavos: 4000,
      tenderKind: 'Cash',
      amountReceivedCentavos: 5000,
      changeCentavos: 1000,
      paperSize: _printerPaperSize,
      footerNote: 'TEST RECEIPT PRINT\nThermal Printer OK',
    );

    showDialog<void>(
      context: context,
      builder: (_) => ReceiptPreviewDialog(
        document: doc,
        title: 'Thermal Printer Test',
      ),
    );
  }

  Widget _metricGroup({required List<Widget> children}) => LayoutBuilder(
        builder: (context, constraints) {
          final scale = MediaQuery.textScalerOf(context).scale(16) / 16;
          final columns = scale > 1.5 || constraints.maxWidth < 600
              ? 1
              : constraints.maxWidth < 900
                  ? 2
                  : 3;
          final width = (constraints.maxWidth - 12 * (columns - 1)) / columns;
          return Wrap(spacing: 12, runSpacing: 12, children: [
            for (final child in children) SizedBox(width: width, child: child),
          ]);
        },
      );

  Widget _buildMetricCard({
    required String title,
    required String value,
    required Color color,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRow(String label, String value, {bool bold = false}) {
    final style = TextStyle(
        fontWeight: bold ? FontWeight.bold : FontWeight.normal, fontSize: 14);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Wrap(spacing: 12, runSpacing: 4, children: [
        Text(label, style: style),
        Text(value, style: style),
      ]),
    );
  }
}
