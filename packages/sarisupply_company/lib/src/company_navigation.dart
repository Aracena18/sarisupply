import 'package:flutter/material.dart';
import 'package:sarisupply_design_system/sarisupply_design_system.dart';

/// Persistent destinations shared by operations and company administration.
class CompanyNavigationBar extends StatelessWidget {
  const CompanyNavigationBar({
    super.key,
    required this.selectedIndex,
    required this.onDestinationSelected,
  });

  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: const BoxDecoration(
      border: Border(top: BorderSide(color: SariSupplyColors.divider)),
    ),
    child: NavigationBar(
      selectedIndex: selectedIndex,
      onDestinationSelected: onDestinationSelected,
      elevation: 0,
      indicatorColor: Colors.transparent,
      backgroundColor: SariSupplyColors.card,
      destinations: const [
        NavigationDestination(
          icon: SariSupplyIcon(
            SariSupplyIconName.orders,
            color: SariSupplyColors.ink600,
          ),
          selectedIcon: SariSupplyIcon(
            SariSupplyIconName.orders,
            color: SariSupplyColors.orange500,
          ),
          label: 'Orders',
        ),
        NavigationDestination(
          icon: SariSupplyIcon(
            SariSupplyIconName.inventory,
            color: SariSupplyColors.ink600,
          ),
          selectedIcon: SariSupplyIcon(
            SariSupplyIconName.inventory,
            color: SariSupplyColors.orange500,
          ),
          label: 'Stock',
        ),
        NavigationDestination(
          icon: SariSupplyIcon(
            SariSupplyIconName.driver,
            color: SariSupplyColors.ink600,
          ),
          selectedIcon: SariSupplyIcon(
            SariSupplyIconName.driver,
            color: SariSupplyColors.orange500,
          ),
          label: 'Deliveries',
        ),
        NavigationDestination(
          icon: SariSupplyIcon(
            SariSupplyIconName.branches,
            color: SariSupplyColors.ink600,
          ),
          selectedIcon: SariSupplyIcon(
            SariSupplyIconName.branches,
            color: SariSupplyColors.orange500,
          ),
          label: 'Company',
        ),
      ],
    ),
  );
}

/// Secondary queues use an underline, visually distinct from global navigation.
class CompanyQueueTab extends StatelessWidget {
  const CompanyQueueTab({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.count,
  });

  final String label;
  final int? count;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    selected: selected,
    button: true,
    child: InkWell(
      onTap: onTap,
      child: Container(
        constraints: const BoxConstraints(minHeight: 48),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: selected ? SariSupplyColors.orange600 : Colors.transparent,
              width: 3,
            ),
          ),
        ),
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              textAlign: TextAlign.center,
              style: SariSupplyTypography.label.copyWith(
                fontSize: 12,
                color: selected
                    ? SariSupplyColors.orange700
                    : SariSupplyColors.ink600,
              ),
            ),
            if (count != null) ...[
              const SizedBox(height: 2),
              Text(
                '$count',
                style: SariSupplyTypography.caption.copyWith(
                  color: selected
                      ? SariSupplyColors.orange700
                      : SariSupplyColors.ink600,
                ),
              ),
            ],
          ],
        ),
      ),
    ),
  );
}

class CompanyQueueTabs extends StatelessWidget {
  const CompanyQueueTabs({super.key, required this.tabs, this.trailing});

  final List<Widget> tabs;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      // Enlarged labels remain readable through horizontal scrolling.
      final enlarged =
          MediaQuery.textScalerOf(context).scale(12) > 18 ||
          constraints.maxWidth < tabs.length * 70;
      final queues = enlarged
          ? SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(children: [for (final tab in tabs) tab]),
            )
          : Row(children: [for (final tab in tabs) Expanded(child: tab)]);
      return Row(
        children: [
          Expanded(child: queues),
          if (trailing != null) trailing!,
        ],
      );
    },
  );
}
