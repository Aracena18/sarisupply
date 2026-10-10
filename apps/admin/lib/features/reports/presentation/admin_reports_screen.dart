import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sarisupply_design_system/sarisupply_design_system.dart';
import 'package:sarisupply_inventory/sarisupply_inventory.dart';
import 'package:sarisupply_models/sarisupply_models.dart';
import 'package:sarisupply_firebase/sarisupply_firebase.dart';

class AdminReportsScreen extends StatefulWidget {
  const AdminReportsScreen({super.key, this.gateway});
  final OperationsFunctions? gateway;

  @override
  State<AdminReportsScreen> createState() => _AdminReportsScreenState();
}

class _AdminReportsScreenState extends State<AdminReportsScreen> {
  List<DailySalesSummary> _branchSummaries = [];
  List<Map<String, Object?>> _merchants = [];
  String? _merchantId, _loadError;
  DateTime _date = DateTime.now().toUtc().add(const Duration(hours: 8));
  bool _loading = true;
  int _request = 0;

  String get _dateKey =>
      '${_date.year.toString().padLeft(4, '0')}-${_date.month.toString().padLeft(2, '0')}-${_date.day.toString().padLeft(2, '0')}';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final request = ++_request;
    setState(() {
      _loading = true;
      _loadError = null;
      _branchSummaries = [];
    });
    try {
      final gateway = widget.gateway ?? OperationsFunctions.forAdmin();
      final merchants = await gateway.merchants();
      if (!mounted || request != _request) return;
      _merchants = merchants;
      if (!_merchants.any((m) => m['id'] == _merchantId)) {
        _merchantId =
            _merchants.length == 1 ? _merchants.single['id'] as String : null;
      }
      final merchantId = _merchantId;
      final summaries = merchantId == null
          ? <DailySalesSummary>[]
          : await gateway.reports(merchantId, _dateKey);
      if (!mounted || request != _request) return;
      setState(() {
        _branchSummaries = summaries;
        _loading = false;
      });
    } catch (error) {
      if (mounted && request == _request) {
        setState(() {
          _loading = false;
          _loadError = operationErrorMessage(error);
        });
      }
    }
  }

  final _archiveJsonController = TextEditingController();
  final _auditPasswordController = TextEditingController();
  String? _auditResult;
  bool _auditing = false;

  @override
  void dispose() {
    _archiveJsonController.dispose();
    _auditPasswordController.dispose();
    super.dispose();
  }

  String _formatPhp(int centavos) => '₱${(centavos / 100).toStringAsFixed(2)}';

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: sariSupplyTaskAppBar(
          context,
          title: 'Admin Reports & Analytics',
        ),
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1000),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const TabBar(
                      isScrollable: true,
                      tabs: [
                        Tab(
                            icon: Icon(Icons.point_of_sale),
                            text: 'Consolidated Sales'),
                        Tab(
                            icon: Icon(Icons.analytics),
                            text: 'Network Valuation'),
                        Tab(
                            icon: Icon(Icons.verified_user),
                            text: 'Backup Auditor'),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Expanded(
                      child: TabBarView(
                        children: [
                          _buildSalesTab(),
                          _buildValuationTab(),
                          _buildAuditorTab(),
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

  Widget _buildSalesTab() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_loadError != null) {
      return Column(children: [
        SariSupplyStatus(message: _loadError!, error: true),
        TextButton(onPressed: _load, child: const Text('Retry'))
      ]);
    }
    final totalGross =
        _branchSummaries.fold(0, (sum, s) => sum + s.grossSalesCentavos);
    final totalNet =
        _branchSummaries.fold(0, (sum, s) => sum + s.netSalesCentavos);
    final totalTx =
        _branchSummaries.fold(0, (sum, s) => sum + s.transactionCount);
    final totalRefunds =
        _branchSummaries.fold(0, (sum, s) => sum + s.refundsCentavos);

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DropdownButtonFormField<String>(
            key: ValueKey(_merchantId),
            isExpanded: true,
            itemHeight: null,
            initialValue: _merchantId,
            decoration: const InputDecoration(labelText: 'Store'),
            items: _merchants
                .map((m) => DropdownMenuItem(
                    value: m['id'] as String, child: Text(m['name'] as String)))
                .toList(),
            onChanged: (value) {
              _merchantId = value;
              _load();
            },
          ),
          TextButton.icon(
              icon: const Icon(Icons.calendar_today),
              label: Text(_dateKey),
              onPressed: () async {
                final picked = await showDatePicker(
                    context: context,
                    initialDate: _date,
                    firstDate: DateTime(2020),
                    lastDate: DateTime(2100));
                if (picked != null && mounted) {
                  _date = picked;
                  _load();
                }
              }),
          if (_merchantId == null)
            const SariSupplyStatus(message: 'Select a store to view reports.'),
          if (_merchantId != null && _branchSummaries.isEmpty)
            const SariSupplyStatus(
                message:
                    'No accepted report data for this date. Sync POS transactions first.'),
          const SariSupplyStatus(
              message:
                  'Synced transactions only. POS work appears after synchronization. Earlier dates without report data are unavailable.'),
          LayoutBuilder(builder: (context, constraints) {
            final width = constraints.maxWidth < 600
                ? constraints.maxWidth
                : (constraints.maxWidth - 12) / 2;
            return Wrap(spacing: 12, runSpacing: 12, children: [
              SizedBox(
                  width: width,
                  child: _buildMetricCard(
                      title: 'Consolidated Net Sales',
                      value: _formatPhp(totalNet),
                      color: SariSupplyColors.success,
                      icon: Icons.payments)),
              SizedBox(
                  width: width,
                  child: _buildMetricCard(
                      title: 'Total Gross Sales',
                      value: _formatPhp(totalGross),
                      color: SariSupplyColors.info,
                      icon: Icons.receipt_long)),
              SizedBox(
                  width: width,
                  child: _buildMetricCard(
                      title: 'Total Transactions',
                      value: '$totalTx',
                      color: SariSupplyColors.info,
                      icon: Icons.shopping_cart)),
              SizedBox(
                  width: width,
                  child: _buildMetricCard(
                      title: 'Total Refunds',
                      value: '-${_formatPhp(totalRefunds)}',
                      color: SariSupplyColors.warning,
                      icon: Icons.assignment_return)),
            ]);
          }),
          const SizedBox(height: 24),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              Text(
                'Branch Sales Breakdown (${_branchSummaries.length} Branches)',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              OutlinedButton.icon(
                icon: const Icon(Icons.file_download, size: 16),
                label: const Text('Export Sales CSV'),
                onPressed: _branchSummaries.isEmpty
                    ? null
                    : () {
                        final csv = BackupArchiveService.exportSalesCsv(
                            _branchSummaries);
                        Clipboard.setData(ClipboardData(text: csv));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                                'Consolidated Sales CSV copied to clipboard'),
                          ),
                        );
                      },
              ),
            ],
          ),
          const SizedBox(height: 12),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _branchSummaries.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, i) {
              final b = _branchSummaries[i];
              return Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(SariSupplyRadii.md),
                  side: BorderSide(color: SariSupplyColors.divider),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Wrap(
                        spacing: 12,
                        runSpacing: 8,
                        children: [
                          Text(
                            b.branchId,
                            style: const TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 15),
                          ),
                          Text(
                            _formatPhp(b.netSalesCentavos),
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: SariSupplyColors.success,
                            ),
                          ),
                        ],
                      ),
                      const Divider(height: 16),
                      Wrap(
                        spacing: 12,
                        runSpacing: 8,
                        children: [
                          Text('${b.transactionCount} transactions',
                              style: const TextStyle(fontSize: 12)),
                          Text(
                            'Cash: ${_formatPhp(b.tenders.cashCentavos)} · QR: ${_formatPhp(b.tenders.qrCentavos)} · Credit: ${_formatPhp(b.tenders.creditCentavos)}',
                            style: TextStyle(
                                fontSize: 12, color: SariSupplyColors.ink600),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildValuationTab() => const SariSupplyStatus(
      message:
          'Inventory cost valuation is unavailable until recorded purchase costs are connected.');

  Widget _buildAuditorTab() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(SariSupplyRadii.md),
              side: BorderSide(color: SariSupplyColors.divider),
            ),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.security,
                          color: SariSupplyColors.info, size: 28),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Offline Backup Manifest Auditor',
                              style: Theme.of(context)
                                  .textTheme
                                  .titleSmall
                                  ?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                            ),
                            Text(
                              'Paste an encrypted backup export JSON to audit its SHA-256 integrity manifest and decrypt data.',
                              style: TextStyle(
                                  fontSize: 12, color: SariSupplyColors.ink600),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 24),
                  TextField(
                    controller: _archiveJsonController,
                    maxLines: 4,
                    decoration: const InputDecoration(
                      labelText: 'Encrypted Backup JSON',
                      hintText:
                          'Paste {"manifest":{...},"ciphertextBase64":...}',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _auditPasswordController,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'Decryption Passphrase',
                      prefixIcon: Icon(Icons.password),
                    ),
                  ),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    icon: const Icon(Icons.verified),
                    label: Text(
                        _auditing ? 'Auditing…' : 'Verify & Audit Manifest'),
                    onPressed: _auditing ? null : _runAudit,
                  ),
                ],
              ),
            ),
          ),
          if (_auditResult != null) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: _auditResult!.startsWith('SUCCESS')
                    ? SariSupplyColors.success.withValues(alpha: 0.1)
                    : SariSupplyColors.error.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(SariSupplyRadii.md),
                border: Border.all(
                  color: _auditResult!.startsWith('SUCCESS')
                      ? SariSupplyColors.success.withValues(alpha: 0.5)
                      : SariSupplyColors.error.withValues(alpha: 0.5),
                ),
              ),
              child: Text(
                _auditResult!,
                style: TextStyle(
                  color: _auditResult!.startsWith('SUCCESS')
                      ? SariSupplyColors.success
                      : SariSupplyColors.error,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
          const SizedBox(height: 20),
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(SariSupplyRadii.md),
              side: BorderSide(color: SariSupplyColors.divider),
            ),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.cloud_done,
                          color: SariSupplyColors.orange500, size: 24),
                      const SizedBox(width: 10),
                      Text(
                        'Cloud usage and archive status',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                    ],
                  ),
                  const Divider(height: 24),
                  _buildQuotaRow(
                    'Firestore reads',
                    'Usage unavailable',
                    'Live metering is not connected',
                    SariSupplyColors.ink300,
                  ),
                  const SizedBox(height: 10),
                  _buildQuotaRow(
                    'Firestore writes',
                    'Usage unavailable',
                    'Live metering is not connected',
                    SariSupplyColors.ink300,
                  ),
                  const SizedBox(height: 10),
                  _buildQuotaRow(
                    'Hosting usage',
                    'Usage unavailable',
                    'Live metering is not connected',
                    SariSupplyColors.info,
                  ),
                  const SizedBox(height: 10),
                  _buildQuotaRow(
                    'Local Disaster Recovery',
                    'PBKDF2 + AES-256-GCM',
                    'Inspect a supplied archive to verify its integrity',
                    SariSupplyColors.info,
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

  Widget _buildQuotaRow(
      String title, String limit, String note, Color badgeColor) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 13)),
              Text(note,
                  style:
                      TextStyle(fontSize: 12, color: SariSupplyColors.ink600)),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: badgeColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(SariSupplyRadii.sm),
          ),
          child: Text(
            limit,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: badgeColor,
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _runAudit() async {
    final rawJson = _archiveJsonController.text.trim();
    if (rawJson.isEmpty) {
      setState(() => _auditResult = 'ERROR: Paste backup JSON first.');
      return;
    }

    setState(() {
      _auditing = true;
      _auditResult = null;
    });

    try {
      final map = jsonDecode(rawJson) as Map<String, dynamic>;
      final archive = EncryptedBackupArchive.fromMap(map);
      final decrypted = await BackupArchiveService.verifyBackupArchive(
        archive: archive,
        password: _auditPasswordController.text,
      );

      final tables = (decrypted['tables'] as Map?) ?? decrypted;
      final salesCount = (tables['checkout_sales'] as List<dynamic>?)?.length ??
          (tables['sales'] as List<dynamic>?)?.length ??
          0;
      final shiftCount =
          (tables['checkout_shifts'] as List<dynamic>?)?.length ?? 0;
      final ledgerCount =
          (tables['stock_ledger'] as List<dynamic>?)?.length ?? 0;

      setState(() {
        _auditResult = 'SUCCESS: Backup archive validated!\n\n'
            '• Merchant: ${archive.manifest.merchantId}\n'
            '• Branch: ${archive.manifest.branchId}\n'
            '• Created At: ${archive.manifest.createdAt}\n'
            '• Manifest SHA-256: ${archive.manifest.sha256Hash}\n'
            '• Cryptographic Hash Verified: TRUE (Unmodified ciphertext)\n'
            '• Decrypted: $salesCount sales, $shiftCount shifts, $ledgerCount stock movements';
        _auditing = false;
      });
    } catch (e) {
      setState(() {
        _auditResult = 'VERIFICATION FAILED: $e';
        _auditing = false;
      });
    }
  }

  Widget _buildMetricCard({
    required String title,
    required String value,
    required Color color,
    required IconData icon,
  }) =>
      SsMetricCard(
        label: title,
        value: value,
        trailing: Icon(icon, size: 20, color: SariSupplyColors.ink600),
      );
}
