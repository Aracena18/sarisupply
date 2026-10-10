import 'package:flutter/material.dart';
import 'package:sarisupply_auth/sarisupply_auth.dart';
import 'package:sarisupply_design_system/sarisupply_design_system.dart';
import 'package:sarisupply_firebase/sarisupply_firebase.dart';
import 'package:sarisupply_inventory/sarisupply_inventory.dart';
import 'package:sarisupply_models/sarisupply_models.dart';
import '../../catalog/inventory_database.dart';

typedef OpenOwnerBranch = Future<void> Function(
  MerchantMembership membership,
  Branch branch, {
  required bool openReports,
});

typedef LoadStoreOverviewData = Future<StoreOverviewData> Function(
    String merchantId, String branchId);

class StoreOverviewData {
  const StoreOverviewData({required this.sales, required this.lowStock});

  final DailySalesSummary sales;
  final List<InventoryRow> lowStock;
}

class StoreOverviewScreen extends StatefulWidget {
  const StoreOverviewScreen({
    super.key,
    required this.membership,
    required this.membershipRepository,
    required this.onOpenBranch,
    this.loadData,
  });

  final MerchantMembership membership;
  final MembershipRepository membershipRepository;
  final OpenOwnerBranch? onOpenBranch;
  final LoadStoreOverviewData? loadData;

  @override
  State<StoreOverviewScreen> createState() => _StoreOverviewScreenState();
}

class _StoreOverviewScreenState extends State<StoreOverviewScreen> {
  List<Branch> _branches = const [];
  Branch? _branch;
  DailySalesSummary? _sales;
  List<InventoryRow> _lowStock = const [];
  bool _loading = true;
  String? _error;
  int _loadGeneration = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final generation = ++_loadGeneration;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final branches = (await widget.membershipRepository
              .listAccessibleBranches(widget.membership))
          .where((branch) => branch.status == BranchStatus.active)
          .toList();
      if (!mounted || generation != _loadGeneration) return;
      final branch =
          branches.where((item) => item.id == _branch?.id).firstOrNull ??
              (branches.length == 1 ? branches.single : null);
      setState(() => _branches = branches);
      if (branch == null) {
        setState(() {
          _branch = null;
          _sales = null;
          _lowStock = const [];
        });
        return;
      }

      final data = await (widget.loadData ?? _loadLocalData)(
          widget.membership.merchantId, branch.id);
      if (mounted && generation == _loadGeneration) {
        setState(() {
          _branch = branch;
          _sales = data.sales;
          _lowStock = data.lowStock;
        });
      }
    } catch (error) {
      if (mounted && generation == _loadGeneration) {
        setState(() => _error = operationErrorMessage(error));
      }
    } finally {
      if (mounted && generation == _loadGeneration) {
        setState(() => _loading = false);
      }
    }
  }

  Future<StoreOverviewData> _loadLocalData(
      String merchantId, String branchId) async {
    final store = await openInventory(merchantId, branchId);
    try {
      final sales = await store.checkout.generateDailySalesSummary();
      final lowStock = (await store.search(''))
          .where((row) => row.quantity <= 10)
          .toList()
        ..sort((a, b) => a.quantity.compareTo(b.quantity));
      return StoreOverviewData(sales: sales, lowStock: lowStock);
    } finally {
      await store.close();
    }
  }

  Future<void> _openBranch({required bool reports}) async {
    final branch = _branch;
    final open = widget.onOpenBranch;
    if (branch == null || open == null) return;
    try {
      await open(widget.membership, branch, openReports: reports);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(operationErrorMessage(error))),
        );
      }
    }
  }

  String _php(int centavos) => '₱${(centavos / 100).toStringAsFixed(2)}';

  @override
  Widget build(BuildContext context) {
    final horizontalPadding =
        MediaQuery.sizeOf(context).width < 600 ? 16.0 : 24.0;
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding:
            EdgeInsets.fromLTRB(horizontalPadding, 8, horizontalPadding, 24),
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(widget.membership.merchantName,
                        style: Theme.of(context).textTheme.titleLarge),
                    if (_branch != null) ...[
                      const SizedBox(height: 4),
                      Text(_branch!.name,
                          style: Theme.of(context)
                              .textTheme
                              .bodyMedium
                              ?.copyWith(color: SariSupplyColors.ink600)),
                    ],
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Refresh overview',
                onPressed: _loading ? null : _load,
                icon: const Icon(Icons.refresh),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (_branches.length > 1)
            DropdownButtonFormField<Branch>(
              initialValue: _branch,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Branch'),
              items: _branches
                  .map((branch) =>
                      DropdownMenuItem(value: branch, child: Text(branch.name)))
                  .toList(),
              onChanged: _loading
                  ? null
                  : (branch) {
                      if (branch == null) return;
                      setState(() {
                        _branch = branch;
                        _sales = null;
                        _lowStock = const [];
                      });
                      _load();
                    },
            ),
          if (_error != null)
            SariSupplyStatus(
              message: 'Store overview could not be loaded: $_error',
              error: true,
              actions: [
                TextButton(onPressed: _load, child: const Text('Retry')),
              ],
            )
          else if (_loading && _sales == null)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 36),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_branch == null)
            SariSupplyStatus(
                message: _branches.isEmpty
                    ? 'No active branches yet. Add a branch to see its activity.'
                    : 'Choose a branch to see its activity.',
                icon: Icons.store_outlined)
          else ...[
            if (_loading) const LinearProgressIndicator(),
            SsCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('Today’s net sales',
                      style: Theme.of(context)
                          .textTheme
                          .bodyMedium
                          ?.copyWith(color: SariSupplyColors.ink600)),
                  const SizedBox(height: 8),
                  // Keep monetary digits together and honor larger system text.
                  // Very long values remain readable by scrolling horizontally.
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Text(_php(_sales?.netSalesCentavos ?? 0),
                        softWrap: false,
                        style: SariSupplyTypography.moneyLarge),
                  ),
                  const SizedBox(height: 16),
                  const Divider(height: 1),
                  const SizedBox(height: 8),
                  LayoutBuilder(builder: (context, constraints) {
                    final transactions = Text(
                      '${_sales?.transactionCount ?? 0} '
                      '${_sales?.transactionCount == 1 ? 'transaction' : 'transactions'}',
                      style: Theme.of(context).textTheme.bodyMedium,
                    );
                    final report = TextButton.icon(
                      onPressed: widget.onOpenBranch == null
                          ? null
                          : () => _openBranch(reports: true),
                      icon: const Icon(Icons.arrow_forward, size: 18),
                      iconAlignment: IconAlignment.end,
                      label: const Text('Sales report'),
                    );
                    if (constraints.maxWidth < 280 ||
                        MediaQuery.textScalerOf(context).scale(14) > 20) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [transactions, report],
                      );
                    }
                    return Row(children: [
                      Expanded(child: transactions),
                      report,
                    ]);
                  }),
                ],
              ),
            ),
            const SizedBox(height: 8),
            ExpansionTile(
              tilePadding: EdgeInsets.zero,
              childrenPadding: const EdgeInsets.only(bottom: 16),
              shape: const Border(),
              collapsedShape: const Border(),
              leading: const Icon(Icons.phone_android_outlined, size: 20),
              title: Text('Sales from this device only',
                  style: Theme.of(context).textTheme.bodySmall),
              children: [
                Text(
                  'Today’s figures use sales saved on this POS device for '
                  '${_branch!.name}. They may not include sales from other '
                  'devices or activity that has not synced.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: widget.onOpenBranch == null
                  ? null
                  : () => _openBranch(reports: false),
              icon: const Icon(Icons.inventory_2_outlined),
              label: const Text('Open inventory'),
            ),
            const SizedBox(height: 24),
            Text('Low stock', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 4),
            Text(
              '${_lowStock.length} '
              '${_lowStock.length == 1 ? 'item' : 'items'} · '
              '10 or fewer base units · Saved on this device',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 16),
            if (_lowStock.isEmpty)
              const SsCard(
                  child: Text('No low-stock products in the saved catalog.'))
            else
              SsCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (var index = 0;
                        index < _lowStock.take(5).length;
                        index++) ...[
                      if (index > 0) ...[
                        const SizedBox(height: 12),
                        const Divider(height: 1),
                        const SizedBox(height: 12),
                      ],
                      _stockRow(_lowStock[index]),
                    ],
                    if (_lowStock.length > 5) ...[
                      const SizedBox(height: 16),
                      Text('Showing 5 of ${_lowStock.length} items',
                          style: Theme.of(context).textTheme.bodySmall),
                    ],
                  ],
                ),
              ),
          ],
        ],
      ),
    );
  }

  Widget _stockRow(InventoryRow row) {
    final outOfStock = row.quantity <= 0;
    final color =
        outOfStock ? SariSupplyColors.error : SariSupplyColors.warning;
    final identity = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(row.product.name, style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 4),
        Text(row.product.sku, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
    final stock = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('${row.quantity} ${row.product.baseUnit}',
            style: Theme.of(context).textTheme.labelLarge),
        const SizedBox(height: 4),
        Text(outOfStock ? 'Out of stock' : 'Low stock',
            style:
                Theme.of(context).textTheme.bodySmall?.copyWith(color: color)),
      ],
    );
    return LayoutBuilder(builder: (context, constraints) {
      if (constraints.maxWidth < 280 ||
          MediaQuery.textScalerOf(context).scale(14) > 20) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [identity, const SizedBox(height: 8), stock],
        );
      }
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: identity),
          const SizedBox(width: 16),
          SizedBox(width: 104, child: stock),
        ],
      );
    });
  }
}
