import 'package:flutter/material.dart';
import 'package:sarisupply_design_system/sarisupply_design_system.dart';
import 'package:sarisupply_models/sarisupply_models.dart';

/// Signed-in workspace selection. Access and invitation mutations stay in the gate.
class DriverAccessView extends StatelessWidget {
  const DriverAccessView({
    super.key,
    required this.workspaces,
    required this.invitations,
    required this.legacyWorkspaces,
    required this.onWorkspace,
    required this.onLegacyWorkspace,
    required this.onAccept,
    required this.onRefresh,
    required this.onSignOut,
    this.loading = false,
    this.acceptingInvitation = false,
    this.error,
    this.companyError,
  });

  final List<AuthorizationWorkspace> workspaces;
  final List<CompanyInvitation> invitations;
  final List<Map<String, Object?>> legacyWorkspaces;
  final ValueChanged<AuthorizationWorkspace> onWorkspace;
  final ValueChanged<Map<String, Object?>> onLegacyWorkspace;
  final ValueChanged<CompanyInvitation> onAccept;
  final VoidCallback onRefresh, onSignOut;
  final bool loading, acceptingInvitation;
  final String? error, companyError;

  @override
  Widget build(BuildContext context) {
    final riders =
        workspaces.where((w) => w.role == CompanyRole.rider).toList();
    final otherRoles =
        workspaces.where((w) => w.role != CompanyRole.rider).toList();
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: ListView(
              padding: EdgeInsets.all(
                  MediaQuery.sizeOf(context).width < 600 ? 16 : 24),
              children: [
                const Row(
                  children: [
                    SariSupplySymbol(size: 32),
                    SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('SariSupply',
                              style: SariSupplyTypography.cardHeading),
                          Text('Driver', style: SariSupplyTypography.body),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 32),
                const Text('Your delivery workspace',
                    style: SariSupplyTypography.sectionHeading),
                const SizedBox(height: 8),
                Text('Choose where to open your assigned routes.',
                    style: SariSupplyTypography.body
                        .copyWith(color: SariSupplyColors.ink600)),
                const SizedBox(height: 24),
                if (loading) ...[
                  const LinearProgressIndicator(),
                  const SizedBox(height: 12),
                  const Text('Loading your assignments…'),
                  const SizedBox(height: 16),
                ],
                if (error != null)
                  SariSupplyStatus(message: error!, error: true),
                if (companyError != null) ...[
                  SariSupplyStatus(message: companyError!, error: true),
                  TextButton(
                      onPressed: loading ? null : onRefresh,
                      child: const Text('Retry company access')),
                  const SizedBox(height: 16),
                ],
                for (final workspace in riders) ...[
                  _workspaceCard(
                    title: workspace.displayName,
                    subtitle:
                        'Rider · ${workspace.scope.warehouseIds.length} assigned ${workspace.scope.warehouseIds.length == 1 ? 'warehouse' : 'warehouses'}',
                    onTap: loading ? null : () => onWorkspace(workspace),
                  ),
                  const SizedBox(height: 12),
                ],
                for (final workspace in legacyWorkspaces) ...[
                  _workspaceCard(
                    title: workspace['driverName'] as String,
                    subtitle: 'Assigned delivery workspace',
                    onTap: loading ? null : () => onLegacyWorkspace(workspace),
                  ),
                  const SizedBox(height: 12),
                ],
                if (!loading &&
                    riders.isEmpty &&
                    legacyWorkspaces.isEmpty &&
                    invitations.isEmpty) ...[
                  const Icon(Icons.route_outlined,
                      size: 40, color: SariSupplyColors.ink600),
                  const SizedBox(height: 16),
                  const Text('No rider assignment yet',
                      style: SariSupplyTypography.cardHeading),
                  const SizedBox(height: 8),
                  const Text(
                      'Ask your company owner to invite your verified Google account as a rider.'),
                  const SizedBox(height: 24),
                ],
                if (invitations.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  const Text('Pending invitations',
                      style: SariSupplyTypography.cardHeading),
                  const SizedBox(height: 12),
                  for (final invitation in invitations) ...[
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(invitation.companyName,
                                style: SariSupplyTypography.cardHeading),
                            const SizedBox(height: 4),
                            Text(
                                '${invitation.role == CompanyRole.rider ? 'Rider' : 'Warehouse Operations'} invitation'),
                            const SizedBox(height: 4),
                            Text(
                                'Expires ${invitation.expiresAt?.toLocal().toString().split('.').first ?? 'soon'}',
                                style: SariSupplyTypography.body
                                    .copyWith(color: SariSupplyColors.ink600)),
                            const SizedBox(height: 16),
                            FilledButton(
                              onPressed: loading || acceptingInvitation
                                  ? null
                                  : () => onAccept(invitation),
                              child: Text(acceptingInvitation
                                  ? 'Accepting…'
                                  : 'Accept invitation'),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                ],
                if (otherRoles.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  ExpansionTile(
                    tilePadding: EdgeInsets.zero,
                    title: const Text('Other company roles',
                        style: SariSupplyTypography.label),
                    childrenPadding: const EdgeInsets.only(bottom: 16),
                    children: [
                      for (final workspace in otherRoles)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Text(workspace.displayName,
                                  style: SariSupplyTypography.label),
                              const SizedBox(height: 4),
                              Text(
                                  '${workspace.role == CompanyRole.companyOwner ? 'Company Owner' : 'Warehouse Operations'} · open Admin to manage company operations',
                                  style: SariSupplyTypography.body.copyWith(
                                      color: SariSupplyColors.ink600)),
                            ],
                          ),
                        ),
                    ],
                  ),
                ],
                const SizedBox(height: 24),
                OutlinedButton.icon(
                  onPressed: loading ? null : onRefresh,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Refresh assignments'),
                ),
                const SizedBox(height: 8),
                TextButton(
                    onPressed:
                        loading || acceptingInvitation ? null : onSignOut,
                    child: const Text('Sign out')),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _workspaceCard(
          {required String title,
          required String subtitle,
          required VoidCallback? onTap}) =>
      Card(
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                      color: SariSupplyColors.orange50,
                      borderRadius: BorderRadius.circular(SariSupplyRadii.sm)),
                  child: const Icon(Icons.route_outlined,
                      color: SariSupplyColors.orange700),
                ),
                const SizedBox(width: 12),
                Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      Text(title, style: SariSupplyTypography.cardHeading),
                      const SizedBox(height: 4),
                      Text(subtitle,
                          style: SariSupplyTypography.body
                              .copyWith(color: SariSupplyColors.ink600)),
                    ])),
                const SizedBox(width: 8),
                const Icon(Icons.chevron_right, color: SariSupplyColors.ink600),
              ],
            ),
          ),
        ),
      );
}
