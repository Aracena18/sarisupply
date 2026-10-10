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
  bool _verificationPassed = false;
  bool _creatingBackup = false;
  bool _verifyingBackup = false;

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
              tooltip: 'Refresh reports',
              onPressed: _loading ? null : _loadAll,
            ),
          ],
        ),
        body: SafeArea(
          child: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 900),
              child: Padding(
                padding: EdgeInsets.symmetric(
                    horizontal:
                        MediaQuery.sizeOf(context).width < 600 ? 16 : 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(top: 8, bottom: 12),
                      child: Wrap(spacing: 8, runSpacing: 4, children: [
                        Text(widget.branchName,
                            style: Theme.of(context).textTheme.titleSmall),
                        Text('Local records · This device',
                            style: Theme.of(context).textTheme.bodySmall),
                      ]),
                    ),
                    TabBar(
                      isScrollable:
                          MediaQuery.textScalerOf(context).scale(14) > 20,
                      tabAlignment:
                          MediaQuery.textScalerOf(context).scale(14) > 20
                              ? TabAlignment.start
                              : TabAlignment.fill,
                      labelPadding: const EdgeInsets.symmetric(horizontal: 8),
                      tabs: const [
                        Tab(text: 'Sales'),
                        Tab(text: 'Stock'),
                        Tab(text: 'Backup'),
                        Tab(text: 'Printer'),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Expanded(
                      child: _loading
                          ? const Center(child: CircularProgressIndicator())
                          : _error != null
                              ? SingleChildScrollView(
                                  child: SariSupplyStatus(
                                    message:
                                        'Unable to generate reports: $_error',
                                    error: true,
                                    actions: [
                                      TextButton(
                                        onPressed: _loadAll,
                                        child: const Text('Retry'),
                                      ),
                                    ],
                                  ),
                                )
                              : TabBarView(
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
    final summary = _salesSummary ??
        DailySalesSummary(
          date: _selectedDate.toIso8601String().split('T').first,
          branchId: widget.store.branchId,
        );
    return _reportScroll('sales', [
      Wrap(
        spacing: 12,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Text('Daily sales', style: Theme.of(context).textTheme.titleLarge),
          OutlinedButton.icon(
            icon: const Icon(Icons.calendar_today_outlined, size: 18),
            label: Text(MaterialLocalizations.of(context)
                .formatCompactDate(_selectedDate)),
            onPressed: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: _selectedDate,
                firstDate: DateTime(2020),
                lastDate: DateTime.now().add(const Duration(days: 1)),
              );
              if (!mounted || picked == null) return;
              setState(() => _selectedDate = picked);
              _loadAll();
            },
          ),
        ],
      ),
      const SizedBox(height: 16),
      _valueCard('Net sales', _formatPhp(summary.netSalesCentavos), details: [
        _buildRow('Transactions', '${summary.transactionCount}'),
      ]),
      _scopeNotice(
        title: 'Sales from this device only',
        message:
            'Sales saved here for ${widget.branchName} on ${summary.date}. '
            'Other devices and activity that has not synced may be missing.',
      ),
      _actions([
        FilledButton.icon(
          icon: const Icon(Icons.receipt_long_outlined),
          label: const Text('Preview daily report'),
          onPressed: () => _showZReadingPreview(summary),
        ),
        OutlinedButton.icon(
          icon: const Icon(Icons.copy_outlined),
          label: const Text('Copy sales CSV'),
          onPressed: () => _copyText(
              BackupArchiveService.exportSalesCsv([summary]),
              'Sales CSV copied to clipboard'),
        ),
      ]),
      const SizedBox(height: 24),
      _sectionCard('Sales breakdown', [
        _buildRow('Gross sales', _formatPhp(summary.grossSalesCentavos)),
        _buildRow('Discounts', _deduction(summary.discountsCentavos)),
        _buildRow('Refunds / returns', _deduction(summary.refundsCentavos)),
        _buildRow('Voided sales', _deduction(summary.voidsCentavos)),
        const Divider(height: 24),
        _buildRow('Net sales', _formatPhp(summary.netSalesCentavos),
            bold: true),
      ]),
      const SizedBox(height: 16),
      _sectionCard('Payment methods', [
        _buildRow('Cash', _formatPhp(summary.tenders.cashCentavos)),
        _buildRow('QR / digital', _formatPhp(summary.tenders.qrCentavos)),
        _buildRow(
            'Store credit (utang)', _formatPhp(summary.tenders.creditCentavos)),
        if (summary.tenders.otherCentavos != 0)
          _buildRow('Other', _formatPhp(summary.tenders.otherCentavos)),
        const Divider(height: 24),
        _buildRow('Total by payment method',
            _formatPhp(summary.tenders.totalCentavos),
            bold: true),
        Text('Includes store credit; this is not all cash collected.',
            style: Theme.of(context).textTheme.bodySmall),
      ]),
      const SizedBox(height: 16),
      _sectionCard('Cash drawer', [
        _buildRow('Opening float', _formatPhp(summary.openingFloatCentavos)),
        _buildRow('Cash in', _formatPhp(summary.cashInCentavos)),
        _buildRow('Cash out', _deduction(summary.cashOutCentavos)),
        const Divider(height: 24),
        _buildRow('Expected cash', _formatPhp(summary.expectedCashCentavos),
            bold: true),
        Text('Expected balance, not a physical cash count.',
            style: Theme.of(context).textTheme.bodySmall),
      ]),
    ]);
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
        title: 'Daily report preview',
        notice:
            'Daily totals preview. Shift identity and counted-cash details are placeholders; this is not a recorded shift close.',
      ),
    );
  }

  Widget _buildValuationTab() {
    final valuation = _valuation;
    if (valuation == null) {
      return const SariSupplyStatus(
          message: 'Stock value is unavailable. Refresh to try again.');
    }
    final movements = valuation.movementSummary;
    return _reportScroll('valuation', [
      Text('Inventory value', style: Theme.of(context).textTheme.titleLarge),
      const SizedBox(height: 16),
      _valueCard(
          'Retail stock value', _formatPhp(valuation.totalRetailValueCentavos),
          details: [
            _buildRow(
                'Purchase cost',
                valuation.totalCostValueCentavos == null
                    ? 'Unavailable'
                    : _formatPhp(valuation.totalCostValueCentavos!)),
            _buildRow(
                'Potential profit',
                valuation.totalPotentialProfitCentavos == null
                    ? 'Unavailable'
                    : _formatPhp(valuation.totalPotentialProfitCentavos!)),
          ]),
      _scopeNotice(
        title: 'Local stock · Includes pending movements',
        message: 'Saved stock for ${widget.branchName}, generated '
            '${MaterialLocalizations.of(context).formatMediumDate(valuation.generatedAt)} '
            'at ${MaterialLocalizations.of(context).formatTimeOfDay(TimeOfDay.fromDateTime(valuation.generatedAt))}. '
            'Retail value uses selling prices. Purchase cost and profit are '
            'unavailable until branch cost records are connected.',
      ),
      OutlinedButton.icon(
        icon: const Icon(Icons.copy_outlined),
        label: const Text('Copy stock CSV'),
        onPressed: () => _copyText(
            BackupArchiveService.exportInventoryCsv(valuation),
            'Stock CSV copied to clipboard'),
      ),
      const SizedBox(height: 24),
      _sectionCard('Stock status', [
        _buildRow('Products', '${valuation.totalSkus}'),
        _buildRow('Low stock · 1–10 base units', '${valuation.lowStockCount}',
            valueColor:
                valuation.lowStockCount > 0 ? SariSupplyColors.warning : null),
        _buildRow('Out of stock', '${valuation.outOfStockCount}',
            valueColor:
                valuation.outOfStockCount > 0 ? SariSupplyColors.error : null),
      ]),
      if (movements != null) ...[
        const SizedBox(height: 16),
        SsCard(
          padding: EdgeInsets.zero,
          child: Material(
            color: Colors.transparent,
            child: ExpansionTile(
              key: const PageStorageKey('stock-movements'),
              title: const Text('Stock movements'),
              childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              shape: const Border(),
              collapsedShape: const Border(),
              children: [
                _buildRow('Received', '${movements.receivedQuantity} units'),
                _buildRow('Sold', '${movements.soldQuantity} units'),
                _buildRow('Customer returns',
                    '${movements.returnedCustomerQuantity} units'),
                _buildRow('Transfers out',
                    '${movements.transferredOutQuantity} units'),
                _buildRow(
                    'Transfers in', '${movements.transferredInQuantity} units'),
                _buildRow('Adjustments / counts',
                    '${movements.adjustedQuantity} units'),
              ],
            ),
          ),
        ),
      ],
      const SizedBox(height: 24),
      Text('Products · ${valuation.products.length}',
          style: Theme.of(context).textTheme.titleLarge),
      const SizedBox(height: 12),
      if (valuation.products.isEmpty)
        const SsCard(child: Text('No products in this device’s saved catalog.'))
      else
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: valuation.products.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final product = valuation.products[index];
            return SsCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(product.name,
                      style: Theme.of(context).textTheme.titleSmall),
                  const SizedBox(height: 4),
                  Text(product.sku,
                      style: Theme.of(context).textTheme.bodySmall),
                  const SizedBox(height: 12),
                  _buildRow('Stock',
                      '${product.physicalQuantity} ${product.unitName}'),
                  _buildRow('Retail value',
                      _formatPhp(product.totalRetailValueCentavos),
                      bold: true),
                  _buildRow(
                      'Purchase cost',
                      product.totalCostValueCentavos == null
                          ? 'Unavailable'
                          : _formatPhp(product.totalCostValueCentavos!)),
                ],
              ),
            );
          },
        ),
    ]);
  }

  Widget _buildBackupTab() {
    final archive = _latestBackup;
    final busy = _creatingBackup || _verifyingBackup;
    return _reportScroll('backup', [
      Text('Backup & archival', style: Theme.of(context).textTheme.titleLarge),
      const SizedBox(height: 8),
      Text('Create a password-protected copy of this branch’s local records.',
          style: Theme.of(context).textTheme.bodyMedium),
      const SizedBox(height: 16),
      _sectionCard('1. Create a backup', [
        Text(
            'Keep the password safe. You will need it to verify or restore the backup.',
            style: Theme.of(context).textTheme.bodyMedium),
        const SizedBox(height: 16),
        TextField(
          controller: _backupPasswordController,
          obscureText: true,
          enabled: !busy,
          autocorrect: false,
          enableSuggestions: false,
          decoration: const InputDecoration(
            labelText: 'Backup password',
            helperText: 'At least 6 characters',
            helperMaxLines: 2,
            prefixIcon: Icon(Icons.lock_outline),
          ),
        ),
        const SizedBox(height: 16),
        FilledButton.icon(
          icon: const Icon(Icons.archive_outlined),
          label: Text(
              _creatingBackup ? 'Creating backup…' : 'Create encrypted backup'),
          onPressed: busy ? null : _createBackup,
        ),
        const SizedBox(height: 12),
        Text(
            'Creation does not save a file. Copy the generated backup below and save it somewhere you control.',
            style: Theme.of(context).textTheme.bodySmall),
      ]),
      if (archive != null) ...[
        const SizedBox(height: 16),
        _sectionCard('2. Copy & verify', [
          _buildRow('Records', '${archive.manifest.recordCount}'),
          _buildRow('Created', archive.manifest.createdAt),
          const SizedBox(height: 12),
          _actions([
            FilledButton.icon(
              icon: const Icon(Icons.copy_outlined),
              label: const Text('Copy backup JSON'),
              onPressed: busy
                  ? null
                  : () => _copyText(jsonEncode(archive.toMap()),
                      'Encrypted backup JSON copied to clipboard'),
            ),
            OutlinedButton.icon(
              icon: const Icon(Icons.verified_user_outlined),
              label: Text(_verifyingBackup ? 'Verifying…' : 'Verify backup'),
              onPressed: busy ? null : _verifyBackup,
            ),
          ]),
          if (_verificationResult != null) ...[
            const SizedBox(height: 12),
            SariSupplyStatus(
              message: _verificationResult!,
              error: !_verificationPassed,
              icon: _verificationPassed
                  ? Icons.check_circle_outline
                  : Icons.error_outline,
            ),
          ],
          ExpansionTile(
            key: const PageStorageKey('backup-details'),
            title: Text('Backup details',
                style: Theme.of(context).textTheme.bodyMedium),
            tilePadding: EdgeInsets.zero,
            childrenPadding: const EdgeInsets.only(bottom: 8),
            shape: const Border(),
            collapsedShape: const Border(),
            children: [
              _buildRow('SHA-256',
                  '${archive.manifest.sha256Hash.substring(0, 16)}…'),
              Text(
                  'Encrypted with AES-256-GCM. Verification checks the password and archive integrity.',
                  style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
        ]),
      ],
      const SizedBox(height: 24),
      _sectionCard('Keep your records safe', [
        Text(
            'Keep two verified backup copies in places you control. '
            'Business records are not automatically deleted.',
            style: Theme.of(context).textTheme.bodyMedium),
        const SizedBox(height: 12),
        Text(
            'The generated copy stays here only while this page is open. '
            'Verification here does not confirm that an external copy was saved.',
            style: Theme.of(context).textTheme.bodySmall),
      ]),
      const SizedBox(height: 16),
      OutlinedButton.icon(
        icon: const Icon(Icons.health_and_safety_outlined),
        label: const Text('Open diagnostics & recovery'),
        onPressed: busy
            ? null
            : () {
                Navigator.of(context).push(MaterialPageRoute<void>(
                  builder: (_) => DiagnosticRecoveryScreen(store: widget.store),
                ));
              },
      ),
    ]);
  }

  Future<void> _createBackup() async {
    if (_creatingBackup || _verifyingBackup) return;
    setState(() => _creatingBackup = true);
    try {
      final archive = await widget.store.exportBackupArchive(
        password: _backupPasswordController.text,
      );
      if (!mounted) return;
      setState(() {
        _latestBackup = archive;
        _verificationResult = null;
        _verificationPassed = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(
            'Backup created · ${archive.manifest.recordCount} records. Copy it to save it.'),
      ));
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Backup could not be created: $error')));
      }
    } finally {
      if (mounted) setState(() => _creatingBackup = false);
    }
  }

  Future<void> _verifyBackup() async {
    if (_creatingBackup || _verifyingBackup) return;
    final archive = _latestBackup;
    if (archive == null) return;
    setState(() {
      _verifyingBackup = true;
      _verificationResult = null;
    });
    try {
      await BackupArchiveService.verifyBackupArchive(
        archive: archive,
        password: _backupPasswordController.text,
      );
      if (!mounted) return;
      setState(() {
        _verificationPassed = true;
        _verificationResult =
            'Backup verified. Password and integrity checks passed.';
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _verificationPassed = false;
          _verificationResult =
              'Backup could not be verified. Check the password and try again.';
        });
      }
    } finally {
      if (mounted) setState(() => _verifyingBackup = false);
    }
  }

  Widget _buildPrinterTab() {
    return _reportScroll('printer', [
      Text('Receipt layout', style: Theme.of(context).textTheme.titleLarge),
      const SizedBox(height: 8),
      Text('Choose a paper width for receipt previews.',
          style: Theme.of(context).textTheme.bodyMedium),
      const SizedBox(height: 16),
      _sectionCard('Paper width', [
        RadioGroup<EscPosPaperSize>(
          groupValue: _printerPaperSize,
          onChanged: (value) {
            if (value != null) setState(() => _printerPaperSize = value);
          },
          child: Column(children: const [
            RadioListTile<EscPosPaperSize>(
              contentPadding: EdgeInsets.zero,
              value: EscPosPaperSize.mm58,
              title: Text('58 mm'),
              subtitle: Text('32 characters per line'),
            ),
            Divider(height: 1),
            RadioListTile<EscPosPaperSize>(
              contentPadding: EdgeInsets.zero,
              value: EscPosPaperSize.mm80,
              title: Text('80 mm'),
              subtitle: Text('42 characters per line'),
            ),
          ]),
        ),
        const SizedBox(height: 16),
        FilledButton.icon(
          icon: const Icon(Icons.receipt_long_outlined),
          label: const Text('Preview test receipt'),
          onPressed: _showTestReceiptPreview,
        ),
      ]),
      const SizedBox(height: 16),
      _sectionCard('Printer connection', [
        Text(
            'Printing and cash drawer control are unavailable in this app. '
            'Previewing a receipt does not send it to a printer.',
            style: Theme.of(context).textTheme.bodyMedium),
        const SizedBox(height: 8),
        Text('Paper width applies to this page’s previews while it is open.',
            style: Theme.of(context).textTheme.bodySmall),
      ]),
    ]);
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
      footerNote: 'SAMPLE RECEIPT\nPreview only - not printed',
    );

    showDialog<void>(
      context: context,
      builder: (_) => ReceiptPreviewDialog(
        document: doc,
        title: 'Test receipt preview',
        notice:
            'Sample products and payments. No sale is recorded and nothing is printed.',
      ),
    );
  }

  String _deduction(int centavos) =>
      centavos == 0 ? _formatPhp(0) : '-${_formatPhp(centavos)}';

  Future<void> _copyText(String text, String message) async {
    try {
      await Clipboard.setData(ClipboardData(text: text));
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(message)));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Could not copy. Try again.')));
      }
    }
  }

  Widget _reportScroll(String key, List<Widget> children) =>
      SingleChildScrollView(
        key: PageStorageKey(key),
        padding: const EdgeInsets.only(bottom: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: children,
        ),
      );

  Widget _valueCard(String label, String value,
          {List<Widget> details = const []}) =>
      SsCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(label,
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(color: SariSupplyColors.ink600)),
            const SizedBox(height: 8),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Text(value,
                  softWrap: false, style: SariSupplyTypography.moneyLarge),
            ),
            if (details.isNotEmpty) ...[
              const Divider(height: 32),
              ...details,
            ],
          ],
        ),
      );

  Widget _sectionCard(String title, List<Widget> children) => SsCard(
        child: Material(
          color: Colors.transparent,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(title, style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 12),
              ...children,
            ],
          ),
        ),
      );

  Widget _scopeNotice({required String title, required String message}) =>
      ExpansionTile(
        key: PageStorageKey('scope-$title'),
        tilePadding: EdgeInsets.zero,
        childrenPadding: const EdgeInsets.only(bottom: 16),
        shape: const Border(),
        collapsedShape: const Border(),
        leading: const Icon(Icons.info_outline, size: 20),
        title: Text(title, style: Theme.of(context).textTheme.bodySmall),
        children: [
          Text(message, style: Theme.of(context).textTheme.bodyMedium)
        ],
      );

  Widget _actions(List<Widget> actions) => LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth < 600 ||
              MediaQuery.textScalerOf(context).scale(14) > 20) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var i = 0; i < actions.length; i++) ...[
                  if (i > 0) const SizedBox(height: 8),
                  actions[i],
                ],
              ],
            );
          }
          return Row(children: [
            for (var i = 0; i < actions.length; i++) ...[
              if (i > 0) const SizedBox(width: 12),
              Expanded(child: actions[i]),
            ],
          ]);
        },
      );

  Widget _buildRow(String label, String value,
      {bool bold = false, Color? valueColor}) {
    final style = Theme.of(context)
        .textTheme
        .bodyMedium
        ?.copyWith(fontWeight: bold ? FontWeight.w600 : FontWeight.w400);
    final labelText = Text(label, style: style);
    final valueText = Text(value, style: style?.copyWith(color: valueColor));
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: LayoutBuilder(builder: (context, constraints) {
        if (constraints.maxWidth < 280 ||
            MediaQuery.textScalerOf(context).scale(14) > 20) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [labelText, const SizedBox(height: 4), valueText],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: labelText),
            const SizedBox(width: 16),
            Flexible(
                child:
                    Align(alignment: Alignment.centerRight, child: valueText)),
          ],
        );
      }),
    );
  }
}
