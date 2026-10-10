import 'package:flutter/material.dart';
import 'company_navigation.dart';
import 'package:sarisupply_design_system/sarisupply_design_system.dart';

/// Stock controls used inside the workspace's vertically scrolling sliver.
class CompanyStockHeader extends StatelessWidget {
  const CompanyStockHeader({
    super.key,
    required this.owner,
    required this.searchController,
    required this.onSearch,
    required this.filters,
    required this.sortControl,
    this.loading = false,
    this.onAddProduct,
    this.onReceiveStock,
    this.onRefresh,
  });

  final bool owner, loading;
  final TextEditingController searchController;
  final ValueChanged<String> onSearch;
  final List<Widget> filters;
  final Widget sortControl;
  final VoidCallback? onAddProduct, onReceiveStock, onRefresh;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Row(
        children: [
          Expanded(
            child: Text('Stock', style: SariSupplyTypography.sectionHeading),
          ),
          IconButton(
            onPressed: onRefresh,
            tooltip: 'Refresh stock',
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      const SizedBox(height: SariSupplySpacing.sm),
      LayoutBuilder(
        builder: (context, constraints) {
          final controls = <Widget>[
            FilledButton.icon(
              onPressed: onReceiveStock,
              icon: const Icon(Icons.inventory_2_outlined),
              label: const Text('Receive stock'),
            ),
            if (owner)
              OutlinedButton.icon(
                onPressed: onAddProduct,
                icon: const Icon(Icons.add),
                label: const Text('Add product'),
              ),
          ];
          if (constraints.maxWidth < 350 ||
              MediaQuery.textScalerOf(context).scale(14) > 20) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var i = 0; i < controls.length; i++) ...[
                  if (i > 0) const SizedBox(height: SariSupplySpacing.xs),
                  controls[i],
                ],
              ],
            );
          }
          return Row(
            children: [
              for (var i = 0; i < controls.length; i++) ...[
                if (i > 0) const SizedBox(width: SariSupplySpacing.xs),
                Expanded(child: controls[i]),
              ],
            ],
          );
        },
      ),
      if (loading)
        const Padding(
          padding: EdgeInsets.only(top: SariSupplySpacing.xs),
          child: Text('Loading warehouse stock…'),
        ),
      const SizedBox(height: SariSupplySpacing.md),
      TextField(
        controller: searchController,
        textInputAction: TextInputAction.search,
        onChanged: onSearch,
        decoration: InputDecoration(
          hintText: 'Search name, SKU or barcode',
          hintStyle: SariSupplyTypography.bodyLarge.copyWith(
            color: SariSupplyColors.ink600,
          ),
          prefixIcon: const Icon(Icons.search),
          suffixIcon: searchController.text.isEmpty
              ? null
              : IconButton(
                  tooltip: 'Clear stock search',
                  onPressed: () {
                    searchController.clear();
                    onSearch('');
                  },
                  icon: const Icon(Icons.close),
                ),
        ),
      ),
      const SizedBox(height: SariSupplySpacing.sm),
      CompanyQueueTabs(tabs: filters, trailing: sortControl),
      const Divider(height: 1, color: SariSupplyColors.divider),
    ],
  );
}
