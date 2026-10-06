import 'dart:async';
import 'package:flutter/material.dart';
import 'package:sarisupply_design_system/sarisupply_design_system.dart';
import 'package:sarisupply_firebase/sarisupply_firebase.dart';
import '../../reports/presentation/reports_screen.dart';
import 'package:flutter/services.dart';
import 'package:sarisupply_core/sarisupply_core.dart';
import 'package:sarisupply_inventory/sarisupply_inventory.dart';

class DiagnosticRecoveryScreen extends StatefulWidget {
  const DiagnosticRecoveryScreen({
    super.key,
    required this.store,
  });

  final InventoryStore store;

  @override
  State<DiagnosticRecoveryScreen> createState() =>
      _DiagnosticRecoveryScreenState();
}

class _DiagnosticRecoveryScreenState extends State<DiagnosticRecoveryScreen> {
  bool _loading = true;
  DatabaseIntegrityReport? _dbReport;
  SystemDiagnosticsReport? _sysReport;
  String? _error;

  final _archiveJsonController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _verifying = false;
  bool _restoring = false;
  String? _verifyResult;
  EncryptedBackupArchive? _parsedArchive;
  InventoryStore? _recoveredStore;
  String? _recoveryMessage;

  @override
  void initState() {
    super.initState();
    _loadDiagnostics();
  }

  @override
  void dispose() {
    _archiveJsonController.dispose();
    _passwordController.dispose();
    final recovered = _recoveredStore;
    if (recovered != null) unawaited(recovered.close());
    super.dispose();
  }

  Future<void> _loadDiagnostics() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final dbReport = await widget.store.checkIntegrity();
      final dbMetric = SystemDiagnosticsService.evaluateDatabaseIntegrity(
        isHealthy: dbReport.isHealthy,
        resultMessage: dbReport.integrityCheckResult,
        recordCount: dbReport.productCount +
            dbReport.stockCount +
            dbReport.salesCount +
            dbReport.ledgerCount,
      );

      final outboxMetric = SystemDiagnosticsService.evaluateOutboxHealth(
        dbReport.pendingOutboxCount,
        blockedCount: dbReport.blockedOutboxCount,
      );

      final sysReport = SystemDiagnosticsService.generateReport(
        metrics: [dbMetric, outboxMetric],
      );

      if (!mounted) return;
      setState(() {
        _dbReport = dbReport;
        _sysReport = sysReport;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _verifyArchive() async {
    final raw = _archiveJsonController.text.trim();
    final pwd = _passwordController.text;

    if (_verifying || _restoring) return;
    if (raw.isEmpty) {
      setState(() => _verifyResult = 'Please paste backup JSON first.');
      return;
    }
    if (pwd.length < 6) {
      setState(() => _verifyResult = 'Password must be at least 6 characters.');
      return;
    }

    setState(() {
      _verifying = true;
      _verifyResult = null;
    });

    try {
      final archive = EncryptedBackupArchive.fromJson(raw);
      final decrypted = await BackupArchiveService.verifyBackupArchive(
        archive: archive,
        password: pwd,
      );

      if (!mounted) return;
      setState(() {
        _parsedArchive = archive;
        _verifying = false;
        final tables = decrypted['tables'] as Map?;
        final sales =
            ((tables?['checkout_sales'] ?? decrypted['sales']) as List?)
                    ?.length ??
                0;
        final shifts =
            ((tables?['checkout_shifts'] ?? decrypted['shifts']) as List?)
                    ?.length ??
                0;
        final ledger =
            ((tables?['ledger'] ?? decrypted['ledger']) as List?)?.length ?? 0;
        _verifyResult = 'VALID BACKUP: Decrypted successfully.\n'
            'Branch: ${archive.manifest.branchId} | Created: ${archive.manifest.createdAt}\n'
            'Records: $sales sales, $shifts shifts, $ledger ledger entries.\n'
            'SHA-256 integrity manifest verified!';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _verifying = false;
        _parsedArchive = null;
        _verifyResult = 'VERIFICATION FAILED: $e';
      });
    }
  }

  Future<void> _confirmAndRestore() async {
    if (_parsedArchive == null || _restoring || _verifying) return;
    final archive = _parsedArchive!;
    final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
              title: const Text('Restore a recovery copy?'),
              content: Text(
                  'Restore ${archive.manifest.recordCount} records into a separate local workspace for inspection. '
                  'Your working records remain intact. Recovered operations will not upload automatically.'),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    child: const Text('Cancel')),
                FilledButton(
                    onPressed: () => Navigator.pop(ctx, true),
                    child: const Text('Restore copy'))
              ],
            ));
    if (confirmed != true || !mounted) return;
    setState(() => _restoring = true);
    try {
      final recovery = await widget.store.restoreRecoveryWorkspace(
          archive: archive, password: _passwordController.text);
      if (!mounted) {
        await recovery.store.close();
        return;
      }
      final previous = _recoveredStore;
      if (previous != null) await previous.close();
      if (!mounted) {
        await recovery.store.close();
        return;
      }
      _passwordController.clear();
      setState(() {
        _recoveredStore = recovery.store;
        _recoveryMessage =
            'Recovery copy saved: ${recovery.result.salesRestored} receipts, '
            '${recovery.result.shiftsRestored} shifts. Inspect reports before deciding how to reconcile it.';
        _restoring = false;
      });
    } catch (error) {
      if (!mounted) return;
      _passwordController.clear();
      setState(() {
        _restoring = false;
        _verifyResult = operationErrorMessage(error,
            fallback:
                'Recovery failed. Check the password, backup version, store and branch.');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Diagnostics & Recovery'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh Health Check',
            onPressed: _loading ? null : _loadDiagnostics,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text('Error: $_error'))
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Overall status banner
                      _buildOverallStatusBanner(),
                      const SizedBox(height: 16),
                      // Database health card
                      _buildDatabaseHealthCard(),
                      const SizedBox(height: 16),
                      // Outbox and monotonic clock metrics
                      _buildSystemMetricsCard(),
                      const SizedBox(height: 24),
                      // Disaster recovery & backup restore tool
                      _buildRestoreWizardCard(),
                      const SizedBox(height: 32),
                    ],
                  ),
                ),
    );
  }

  Widget _buildOverallStatusBanner() {
    final report = _sysReport!;
    final (bg, border, text, icon) = switch (report.overallLevel) {
      HealthLevel.healthy => (
          Colors.green.shade50,
          Colors.green.shade300,
          Colors.green.shade900,
          Icons.check_circle,
        ),
      HealthLevel.warning => (
          Colors.amber.shade50,
          Colors.amber.shade400,
          Colors.amber.shade900,
          Icons.warning,
        ),
      HealthLevel.critical => (
          Colors.red.shade50,
          Colors.red.shade300,
          Colors.red.shade900,
          Icons.error,
        ),
    };

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: border),
      ),
      child: Row(
        children: [
          Icon(icon, color: text, size: 36),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'System Health: ${report.overallLevel.name.toUpperCase()}',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: text,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  report.summary,
                  style: TextStyle(fontSize: 13, color: text),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDatabaseHealthCard() {
    final db = _dbReport!;
    return Card(
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
            Row(
              children: [
                Icon(
                  db.isHealthy ? Icons.storage : Icons.storage_outlined,
                  color: db.isHealthy
                      ? Colors.green.shade700
                      : Colors.red.shade700,
                ),
                const SizedBox(width: 8),
                Text(
                  'Local SQLite Database Health',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const Spacer(),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: db.isHealthy
                        ? Colors.green.shade100
                        : Colors.red.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    db.isHealthy ? 'INTEGRITY OK' : 'CHECK FAILED',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: db.isHealthy
                          ? Colors.green.shade900
                          : Colors.red.shade900,
                    ),
                  ),
                ),
              ],
            ),
            const Divider(height: 20),
            _buildRow('SQLite Integrity Check:', db.integrityCheckResult),
            _buildRow('Schema Version:', 'v${db.databaseVersion}'),
            _buildRow('Catalog Products:', '${db.productCount} SKUs'),
            _buildRow('Stock Records:', '${db.stockCount} tracked'),
            _buildRow('Checkout Sales:', '${db.salesCount} historical sales'),
            _buildRow('Financial Ledger Entries:',
                '${db.ledgerCount} immutable entries'),
          ],
        ),
      ),
    );
  }

  Widget _buildSystemMetricsCard() {
    final report = _sysReport!;
    return Card(
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
              'Offline Synchronization Health',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const Divider(height: 20),
            for (final m in report.metrics) ...[
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(m.name,
                              style:
                                  const TextStyle(fontWeight: FontWeight.w600)),
                          Text(m.detail,
                              style: TextStyle(
                                  fontSize: 11, color: Colors.grey.shade600)),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: _levelColor(m.level).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        m.value,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: _levelColor(m.level),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (m != report.metrics.last) const Divider(height: 12),
            ],
          ],
        ),
      ),
    );
  }

  Color _levelColor(HealthLevel level) {
    return switch (level) {
      HealthLevel.healthy => Colors.green.shade800,
      HealthLevel.warning => Colors.amber.shade900,
      HealthLevel.critical => Colors.red.shade800,
    };
  }

  Widget _buildRestoreWizardCard() {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.indigo.shade200),
      ),
      color: Colors.indigo.shade50.withValues(alpha: 0.3),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Icon(Icons.settings_backup_restore,
                    color: Colors.indigo, size: 24),
                const SizedBox(width: 8),
                Text(
                  'Encrypted Recovery Copy',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Colors.indigo.shade900,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'Restore a complete encrypted backup into a separate recovery workspace for the same store and branch. Inspect its records without replacing working data.',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
            ),
            const Divider(height: 20),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Backup Archive JSON:',
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey.shade800),
                  ),
                ),
                TextButton.icon(
                  icon: const Icon(Icons.paste, size: 14),
                  label: const Text('Paste from Clipboard',
                      style: TextStyle(fontSize: 12)),
                  onPressed: () async {
                    final data = await Clipboard.getData('text/plain');
                    if (data?.text != null) {
                      _archiveJsonController.text = data!.text!;
                    }
                  },
                ),
              ],
            ),
            TextField(
              controller: _archiveJsonController,
              enabled: !_verifying && !_restoring,
              onChanged: (_) => setState(() {
                _parsedArchive = null;
                _verifyResult = null;
              }),
              maxLines: 3,
              style: const TextStyle(fontSize: 12, fontFamily: 'monospace'),
              decoration: const InputDecoration(
                hintText: '{"manifest":{...},"ciphertextBase64":...}',
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _passwordController,
              enabled: !_verifying && !_restoring,
              onChanged: (_) => setState(() {
                _parsedArchive = null;
                _verifyResult = null;
              }),
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Decryption Password',
                prefixIcon: Icon(Icons.password),
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.verified),
                    label: Text(
                        _verifying ? 'Verifying…' : 'Inspect & Verify Backup'),
                    onPressed:
                        (_verifying || _restoring) ? null : _verifyArchive,
                  ),
                ),
                if (_parsedArchive != null) ...[
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton.icon(
                      icon: const Icon(Icons.download),
                      label: Text(_restoring ? 'Restoring…' : 'Restore copy'),
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.red.shade700,
                      ),
                      onPressed: (_restoring || _verifying)
                          ? null
                          : _confirmAndRestore,
                    ),
                  ),
                ],
              ],
            ),
            if (_recoveryMessage != null) ...[
              const SizedBox(height: 12),
              SariSupplyStatus(message: _recoveryMessage!),
              TextButton(
                  onPressed: _restoring
                      ? null
                      : () async {
                          final recovered = _recoveredStore;
                          if (recovered == null) return;
                          await Navigator.of(context).push(MaterialPageRoute<
                                  void>(
                              builder: (_) => ReportsScreen(
                                  store: recovered,
                                  branchName:
                                      'Recovery copy · ${recovered.branchId}',
                                  isOwner: false)));
                        },
                  child: const Text('Inspect recovered reports')),
              TextButton(
                  onPressed: () => Clipboard.setData(
                      ClipboardData(text: _recoveredStore!.db.path)),
                  child: const Text('Copy recovery file location')),
            ],
            if (_verifyResult != null) ...[
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _verifyResult!.startsWith('VALID')
                      ? Colors.green.shade50
                      : Colors.red.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: _verifyResult!.startsWith('VALID')
                        ? Colors.green.shade300
                        : Colors.red.shade300,
                  ),
                ),
                child: Text(
                  _verifyResult!,
                  style: TextStyle(
                    fontSize: 12,
                    fontFamily: 'monospace',
                    color: _verifyResult!.startsWith('VALID')
                        ? Colors.green.shade900
                        : Colors.red.shade900,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: TextStyle(fontSize: 13, color: Colors.grey.shade700)),
          Text(value,
              style:
                  const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}
