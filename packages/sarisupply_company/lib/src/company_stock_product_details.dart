import 'package:flutter/material.dart';
import 'package:sarisupply_design_system/sarisupply_design_system.dart';
import 'package:sarisupply_models/sarisupply_models.dart';

class CompanyStockProductDetails extends StatelessWidget {
  const CompanyStockProductDetails({
    super.key,
    required this.product,
    required this.warehouseName,
    required this.owner,
    required this.actionsEnabled,
    required this.onAction,
    required this.onClose,
    this.cached = false,
  });

  final CompanyRecord product;
  final String warehouseName;
  final bool owner, actionsEnabled, cached;
  final ValueChanged<String> onAction;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final raw = product.data['warehouseStock'];
    final stock = raw is Map ? raw : const {};
    int quantity(String key) => (stock[key] as num?)?.toInt() ?? 0;
    final difference = quantity('physical') - quantity('reserved');
    final available = difference < 0 ? 0 : difference;
    final transit = quantity('inTransit');
    final quarantine = quantity('quarantined');
    final unit = product.string('unit');
    final name = product.string('name');
    return SafeArea(
      top: false,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * .85,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 8, 12),
              child: Row(
                children: [
                  ProductThumbnail(
                    imageUrl: product.imageUrl.isEmpty
                        ? null
                        : product.imageUrl,
                    productName: name.isEmpty ? 'Product' : name,
                    size: 48,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(name, style: SariSupplyTypography.sectionHeading),
                        Text(
                          'SKU ${product.string('sku')}',
                          style: SariSupplyTypography.caption,
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: onClose,
                    tooltip: 'Close product details',
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),
            Flexible(
              fit: FlexFit.loose,
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Warehouse · $warehouseName',
                      style: SariSupplyTypography.caption,
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        const Text(
                          'Wholesale price',
                          style: SariSupplyTypography.body,
                        ),
                        Text(
                          '₱${(product.number('priceCentavos') / 100).toStringAsFixed(2)} / $unit',
                          style: SariSupplyTypography.cardHeading,
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: SariSupplyColors.card,
                        borderRadius: BorderRadius.circular(SariSupplyRadii.md),
                        border: Border.all(color: SariSupplyColors.divider),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Wrap(
                            alignment: WrapAlignment.spaceBetween,
                            spacing: 12,
                            runSpacing: 8,
                            children: [
                              const Text(
                                'Available',
                                style: SariSupplyTypography.label,
                              ),
                              SsStatusChip(
                                label: available == 0
                                    ? 'Out of stock'
                                    : 'In stock',
                                status: available == 0
                                    ? SsStatus.warning
                                    : SsStatus.success,
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '$available $unit',
                            style: SariSupplyTypography.display,
                          ),
                          const Divider(height: 24),
                          _balance('Reserved', quantity('reserved'), unit),
                          _balance('In transit', transit, unit),
                          _balance('Quarantined', quarantine, unit),
                        ],
                      ),
                    ),
                    if (cached)
                      const Padding(
                        padding: EdgeInsets.only(top: 12),
                        child: Text(
                          'Saved stock snapshot. Refresh online before making changes.',
                        ),
                      ),
                    if (owner) ...[
                      const SizedBox(height: 20),
                      const Text(
                        'Product details',
                        style: SariSupplyTypography.label,
                      ),
                      _action(
                        'Edit price',
                        'Update the wholesale selling price',
                        Icons.edit_outlined,
                        'editPrice',
                      ),
                      _action(
                        'Edit details & photo',
                        'Name and product image',
                        Icons.photo_camera_outlined,
                        'editProduct',
                      ),
                      const Divider(height: 16),
                      ExpansionTile(
                        tilePadding: EdgeInsets.zero,
                        childrenPadding: EdgeInsets.zero,
                        title: const Text(
                          'Stock corrections',
                          style: SariSupplyTypography.label,
                        ),
                        subtitle: const Text('Adjustments require a reference'),
                        children: [
                          _action(
                            'Correct physical stock',
                            'Record a counted quantity adjustment',
                            Icons.tune,
                            'correctStock',
                          ),
                          if (quarantine > 0)
                            _action(
                              'Release inspected stock',
                              'Return inspected units to available stock',
                              Icons.verified_outlined,
                              'releaseQuarantine',
                            ),
                          if (transit > 0)
                            _action(
                              'Write off missing transit stock',
                              'Record lost units in transit',
                              Icons.remove_circle_outline,
                              'writeOffTransit',
                              destructive: true,
                            ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
            if (owner)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: const BoxDecoration(
                  color: SariSupplyColors.paper,
                  border: Border(
                    top: BorderSide(color: SariSupplyColors.divider),
                  ),
                ),
                child: FilledButton.icon(
                  onPressed: actionsEnabled
                      ? () => onAction('receiveStock')
                      : null,
                  icon: const Icon(Icons.inventory_2_outlined),
                  label: const Text('Receive stock'),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _balance(String label, int quantity, String unit) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Wrap(
      alignment: WrapAlignment.spaceBetween,
      spacing: 16,
      runSpacing: 4,
      children: [
        Text(label, style: SariSupplyTypography.body),
        Text('$quantity $unit', style: SariSupplyTypography.label),
      ],
    ),
  );

  Widget _action(
    String label,
    String description,
    IconData icon,
    String action, {
    bool destructive = false,
  }) => ListTile(
    contentPadding: EdgeInsets.zero,
    leading: Icon(
      icon,
      color: destructive ? SariSupplyColors.error : SariSupplyColors.ink600,
    ),
    title: Text(
      label,
      style: SariSupplyTypography.body.copyWith(
        color: destructive ? SariSupplyColors.error : SariSupplyColors.ink950,
      ),
    ),
    subtitle: Text(description, style: SariSupplyTypography.caption),
    trailing: const Icon(Icons.chevron_right, size: 20),
    enabled: actionsEnabled,
    onTap: actionsEnabled ? () => onAction(action) : null,
  );
}
