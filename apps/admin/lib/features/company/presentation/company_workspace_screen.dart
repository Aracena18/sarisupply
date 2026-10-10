import 'package:firebase_core/firebase_core.dart';
import 'package:sarisupply_company/sarisupply_company.dart';
import 'package:flutter/material.dart';
import 'package:sarisupply_design_system/sarisupply_design_system.dart';
import 'package:sarisupply_firebase/sarisupply_firebase.dart';
import 'package:sarisupply_models/sarisupply_models.dart';
import 'package:uuid/uuid.dart';
import '../../merchant_review/presentation/merchant_review_list_screen.dart';

class CompanyWorkspaceScreen extends StatefulWidget {
  const CompanyWorkspaceScreen({
    super.key,
    required this.workspace,
    required this.authorization,
    required this.onSignOut,
    this.onSwitchContext,
    this.accountLabel,
    this.onNavigate,
  });

  final AuthorizationWorkspace workspace;
  final AuthorizationWorkspaceFunctions authorization;
  final Future<void> Function() onSignOut;
  final VoidCallback? onSwitchContext;
  final String? accountLabel;
  final ValueChanged<int>? onNavigate;

  @override
  State<CompanyWorkspaceScreen> createState() => _CompanyWorkspaceScreenState();
}

class _CompanyWorkspaceScreenState extends State<CompanyWorkspaceScreen> {
  static const _uuid = Uuid();
  final Map<String, String> _operationIds = {};
  bool _busy = true;
  bool _saving = false;
  String? _error;
  CompanyWorkspace? _verified;
  List<CompanyWarehouse> _warehouses = const [];
  List<CompanyInvitation> _invitations = const [];
  List<CompanyStaffMember> _staff = const [];
  CompanyRole? _teamRoleFilter;
  final _teamSearchController = TextEditingController();

  bool get _isOwner => widget.workspace.role == CompanyRole.companyOwner;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  @override
  void dispose() {
    _teamSearchController.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final verified =
          await widget.authorization.getCompanyWorkspace(widget.workspace);
      final pages = await Future.wait<Object?>([
        widget.authorization.listWarehouses(widget.workspace),
        if (_isOwner)
          widget.authorization.listInvitations(widget.workspace.companyId),
        if (_isOwner)
          widget.authorization.listStaff(widget.workspace.companyId),
      ]);
      final warehouses = pages[0] as CompanyWarehousePage;
      final invitations = _isOwner ? pages[1] as CompanyInvitationPage : null;
      final staff = _isOwner ? pages[2] as CompanyStaffPage : null;
      if (!mounted) return;
      setState(() {
        _verified = verified;
        _warehouses = warehouses.warehouses;
        _invitations = invitations?.invitations ?? const [];
        _staff = staff?.members ?? const [];
      });
    } catch (error) {
      if (error is FirebaseException &&
          ['permission-denied', 'unauthenticated'].contains(error.code)) {
        _verified = null;
        _warehouses = const [];
        _invitations = const [];
        _staff = const [];
      }
      if (mounted) setState(() => _error = operationErrorMessage(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _createWarehouse() async {
    final values = await _warehouseDialog();
    if (values == null || !mounted) return;
    final key = 'warehouse:${values.$1}|${values.$2}|${values.$3}';
    await _mutate(
        key,
        (operationId) => widget.authorization.createWarehouse(
              companyId: widget.workspace.companyId,
              name: values.$1,
              code: values.$2,
              address: values.$3,
              operationId: operationId,
            ));
  }

  Future<(String, String, String)?> _warehouseDialog() async {
    final name = TextEditingController();
    final code = TextEditingController();
    final address = TextEditingController();
    final formKey = GlobalKey<FormState>();
    final result = await showSariSupplyForm<(String, String, String)>(
      context: context,
      builder: (context) => SariSupplyFormSurface(
        title: 'Add warehouse',
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              if (!formKey.currentState!.validate()) return;
              Navigator.pop(
                context,
                (name.text.trim(), code.text.trim(), address.text.trim()),
              );
            },
            child: const Text('Save warehouse'),
          ),
        ],
        child: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: name,
                textCapitalization: TextCapitalization.words,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(labelText: 'Warehouse name'),
                validator: (value) => value == null || value.trim().isEmpty
                    ? 'Enter a warehouse name'
                    : null,
              ),
              const SizedBox(height: SariSupplySpacing.sm),
              TextFormField(
                controller: code,
                textCapitalization: TextCapitalization.characters,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(labelText: 'Warehouse code'),
                validator: (value) => value == null || value.trim().isEmpty
                    ? 'Enter a warehouse code'
                    : null,
              ),
              const SizedBox(height: SariSupplySpacing.sm),
              TextFormField(
                controller: address,
                textCapitalization: TextCapitalization.words,
                textInputAction: TextInputAction.done,
                decoration: const InputDecoration(
                  labelText: 'Address',
                  helperText: 'Optional',
                ),
              ),
            ],
          ),
        ),
      ),
    );
    name.dispose();
    code.dispose();
    address.dispose();
    return result;
  }

  Future<void> _paymentInstructions() async {
    final controller = TextEditingController();
    final value = await showSariSupplyForm<String>(
      context: context,
      builder: (context) => SariSupplyFormSurface(
        title: 'Company payment instructions',
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              if (controller.text.trim().isNotEmpty) {
                Navigator.pop(context, controller.text.trim());
              }
            },
            child: const Text('Save instructions'),
          ),
        ],
        child: TextField(
          controller: controller,
          maxLines: 5,
          maxLength: 600,
          decoration: const InputDecoration(
            labelText: 'Verified QR/account and reference instructions',
            helperText: 'Shown to stores when they prepare a payment.',
          ),
        ),
      ),
    );
    controller.dispose();
    if (value == null || !mounted) return;
    await _mutate('paymentInstructions:$value', (operationId) async {
      await CompanyOperationsFunctions.forDefaultApp().mutate(
          companyId: widget.workspace.companyId,
          context: widget.workspace.context,
          action: 'savePaymentInstructions',
          operationId: operationId,
          values: {'instructions': value});
    });
  }

  Future<void> _inviteStaff() async {
    if (_warehouses.isEmpty) {
      setState(() =>
          _error = 'Add an active company warehouse before inviting staff.');
      return;
    }
    final values = await _invitationDialog();
    if (values == null || !mounted) return;
    final warehouseIds = values.warehouseIds.toList()..sort();
    final key =
        'invitation:${values.email}|${values.role.wireValue}|${warehouseIds.join(',')}';
    await _mutate(
        key,
        (operationId) => widget.authorization.createInvitation(
              companyId: widget.workspace.companyId,
              email: values.email,
              role: values.role,
              warehouseIds: warehouseIds,
              operationId: operationId,
            ));
  }

  Future<_InvitationDraft?> _invitationDialog() async {
    final email = TextEditingController();
    final formKey = GlobalKey<FormState>();
    var role = CompanyRole.warehouseOperations;
    final selected = <String>{_warehouses.first.id};
    final result = await showSariSupplyForm<_InvitationDraft>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => SariSupplyFormSurface(
          title: 'Invite staff',
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                if (!formKey.currentState!.validate() || selected.isEmpty) {
                  setDialogState(() {});
                  return;
                }
                Navigator.pop(
                  context,
                  _InvitationDraft(email.text.trim(), role, selected.toList()),
                );
              },
              child: const Text('Send invitation'),
            ),
          ],
          child: Form(
            key: formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Invite a verified Google account to a company role and selected warehouses.',
                  style: SariSupplyTypography.body.copyWith(
                    color: SariSupplyColors.ink600,
                  ),
                ),
                const SizedBox(height: SariSupplySpacing.md),
                TextFormField(
                  controller: email,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  autocorrect: false,
                  enableSuggestions: false,
                  decoration: const InputDecoration(
                    labelText: 'Google account email',
                    hintText: 'name@example.com',
                  ),
                  validator: (value) {
                    final address = value?.trim() ?? '';
                    final valid =
                        RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(address);
                    return valid ? null : 'Enter a valid email address';
                  },
                ),
                const SizedBox(height: SariSupplySpacing.sm),
                DropdownButtonFormField<CompanyRole>(
                  initialValue: role,
                  decoration: const InputDecoration(labelText: 'Company role'),
                  items: const [
                    DropdownMenuItem(
                      value: CompanyRole.warehouseOperations,
                      child: Text('Warehouse Operations'),
                    ),
                    DropdownMenuItem(
                      value: CompanyRole.rider,
                      child: Text('Rider'),
                    ),
                  ],
                  onChanged: (value) =>
                      setDialogState(() => role = value ?? role),
                ),
                const SizedBox(height: SariSupplySpacing.md),
                Text('Warehouse access',
                    style: SariSupplyTypography.cardHeading),
                const SizedBox(height: SariSupplySpacing.xs),
                for (final warehouse in _warehouses)
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    value: selected.contains(warehouse.id),
                    title: Text(warehouse.name),
                    subtitle: Text(warehouse.code),
                    onChanged: (checked) => setDialogState(() {
                      if (checked == true) {
                        selected.add(warehouse.id);
                      } else if (selected.length > 1) {
                        selected.remove(warehouse.id);
                      }
                    }),
                  ),
                if (selected.isEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: SariSupplySpacing.xs),
                    child: Text(
                      'Select at least one warehouse.',
                      style: SariSupplyTypography.body.copyWith(
                        color: SariSupplyColors.error,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
    email.dispose();
    return result;
  }

  Future<void> _mutate(
      String key, Future<void> Function(String operationId) action) async {
    final operationId = _operationIds.putIfAbsent(key, () => _uuid.v4());
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await action(operationId);
      _operationIds.remove(key);
      await _refresh();
    } catch (error) {
      if (mounted) setState(() => _error = operationErrorMessage(error));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<bool> _confirmAccessChange({
    required String title,
    required String message,
    required String actionLabel,
  }) async =>
      await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(title),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton.tonal(
              onPressed: () => Navigator.pop(context, true),
              child: Text(actionLabel),
            ),
          ],
        ),
      ) ??
      false;

  Widget _locationsTab(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(SariSupplySpacing.md),
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Warehouses (${_warehouses.length})',
                style: SariSupplyTypography.cardHeading
                    .copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: SariSupplySpacing.xs),
              Text(
                  _isOwner
                      ? 'Manage the locations that hold your company stock.'
                      : 'View the warehouses assigned to your workspace.',
                  style: SariSupplyTypography.body
                      .copyWith(color: SariSupplyColors.ink600)),
              const SizedBox(height: SariSupplySpacing.md),
              if (_isOwner)
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(0, 48),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 12),
                    textStyle: SariSupplyTypography.label,
                  ),
                  onPressed: _saving || _busy || _verified == null
                      ? null
                      : _createWarehouse,
                  icon: const Icon(Icons.add, size: 20),
                  label: const Text('Add warehouse'),
                ),
            ],
          ),
          const SizedBox(height: SariSupplySpacing.sm),
          if (_busy && _warehouses.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: SariSupplySpacing.xl),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_warehouses.isEmpty)
            _emptyState(
              icon: Icons.warehouse_outlined,
              title: 'No warehouses yet',
              message: _isOwner
                  ? 'Add a warehouse to organize company stock and assign staff.'
                  : 'No warehouses are assigned to your verified access yet.',
            )
          else
            for (final warehouse in _warehouses)
              Container(
                decoration: const BoxDecoration(
                  border: Border(
                    bottom: BorderSide(color: SariSupplyColors.divider),
                  ),
                ),
                child: _workspaceEntry(
                  onTap: () => showDialog<void>(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: Text(warehouse.name),
                      content: SelectableText(
                        'Warehouse code: ${warehouse.code}\n${warehouse.address.isEmpty ? 'No address added' : warehouse.address}',
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('Close'),
                        ),
                      ],
                    ),
                  ),
                  leading: Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: SariSupplyColors.ink50,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(
                      Icons.warehouse_outlined,
                      color: SariSupplyColors.ink600,
                    ),
                  ),
                  title: Text(warehouse.name),
                  subtitle: Text(
                    [warehouse.code, warehouse.address]
                        .where((value) => value.isNotEmpty)
                        .join(' · '),
                  ),
                  trailing: Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: SariSupplySpacing.xs,
                    children: [
                      _statusChip(
                        widget.workspace.scope.allowsWarehouse(warehouse.id)
                            ? 'In your scope'
                            : 'Outside scope',
                        success: widget.workspace.scope
                            .allowsWarehouse(warehouse.id),
                      ),
                      const SizedBox(width: SariSupplySpacing.xs),
                      const Icon(Icons.chevron_right),
                    ],
                  ),
                ),
              ),
        ],
      ),
    );
  }

  Widget _teamTab(BuildContext context) {
    if (!_isOwner) {
      return ListView(
        padding: const EdgeInsets.all(SariSupplySpacing.md),
        children: [
          Text('Team', style: SariSupplyTypography.cardHeading),
          const SizedBox(height: SariSupplySpacing.md),
          const SariSupplyStatus(
            message:
                'Team management is available in the Company Owner workspace. Warehouse Operations cannot invite staff or change team access.',
            icon: Icons.lock_outline,
          ),
          const SizedBox(height: SariSupplySpacing.md),
          if (widget.onSwitchContext != null)
            FilledButton.icon(
              onPressed: widget.onSwitchContext,
              icon: const Icon(Icons.swap_horiz),
              label: const Text('Switch workspace'),
            )
          else
            Text(
              'Sign in with the company owner account to manage staff and riders.',
              style: SariSupplyTypography.body.copyWith(
                color: SariSupplyColors.ink600,
              ),
            ),
        ],
      );
    }
    final pending = _invitations.where((invite) => invite.status == 'pending');
    final history = _invitations.where((invite) => invite.status != 'pending');
    final query = _teamSearchController.text.trim().toLowerCase();
    final staff = _staff
        .where((member) =>
            (_teamRoleFilter == null || member.role == _teamRoleFilter) &&
            (query.isEmpty ||
                member.email.toLowerCase().contains(query) ||
                _warehouseNames(member.warehouseIds)
                    .toLowerCase()
                    .contains(query)))
        .toList();
    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(SariSupplySpacing.md),
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'People and access',
                style: SariSupplyTypography.cardHeading
                    .copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: SariSupplySpacing.xs),
              Text('Assign warehouse staff and riders to the right locations.',
                  style: SariSupplyTypography.body
                      .copyWith(color: SariSupplyColors.ink600)),
              const SizedBox(height: SariSupplySpacing.md),
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  minimumSize: const Size(0, 48),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  textStyle: SariSupplyTypography.label,
                ),
                onPressed:
                    _saving || _busy || _verified == null || _warehouses.isEmpty
                        ? null
                        : _inviteStaff,
                icon: const Icon(Icons.add, size: 20),
                label: const Text('Invite staff'),
              ),
            ],
          ),
          if (_warehouses.isEmpty) ...[
            const SizedBox(height: SariSupplySpacing.sm),
            const SariSupplyStatus(
              message: 'Add an active warehouse before inviting staff.',
              icon: Icons.info_outline,
            ),
          ],
          const SizedBox(height: SariSupplySpacing.sm),
          const SizedBox(height: SariSupplySpacing.lg),
          Text('Members (${staff.length})',
              style: SariSupplyTypography.cardHeading
                  .copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: SariSupplySpacing.sm),
          TextField(
            controller: _teamSearchController,
            onChanged: (_) => setState(() {}),
            textInputAction: TextInputAction.search,
            decoration: const InputDecoration(
              labelText: 'Search members',
              hintText: 'Email or warehouse name',
              prefixIcon: Icon(Icons.search),
            ),
          ),
          const SizedBox(height: SariSupplySpacing.sm),
          Wrap(
            spacing: SariSupplySpacing.xs,
            runSpacing: SariSupplySpacing.xs,
            children: [
              for (final role in <CompanyRole?>[
                null,
                CompanyRole.warehouseOperations,
                CompanyRole.rider
              ])
                ChoiceChip(
                  selected: _teamRoleFilter == role,
                  label: Text(role == null ? 'All roles' : _roleName(role)),
                  padding:
                      const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                  onSelected: (_) => setState(() => _teamRoleFilter = role),
                ),
            ],
          ),
          const SizedBox(height: SariSupplySpacing.xs),
          if (_busy && _staff.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: SariSupplySpacing.md),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (staff.isEmpty)
            _emptyState(
              icon: Icons.groups_2_outlined,
              title: query.isEmpty && _teamRoleFilter == null
                  ? 'No active members yet'
                  : 'No matching members',
              message: query.isEmpty && _teamRoleFilter == null
                  ? 'Invite staff to give them access to your warehouses.'
                  : 'Clear the search or choose All roles to see more members.',
              boxed: false,
              centered: true,
            )
          else
            for (final member in staff)
              Container(
                decoration: const BoxDecoration(
                  border: Border(
                    bottom: BorderSide(color: SariSupplyColors.divider),
                  ),
                ),
                child: _workspaceEntry(
                  leading: _initialAvatar(member.email),
                  title: Text(member.email),
                  subtitle: Text(
                    '${_roleName(member.role)}\n${_warehouseNames(member.warehouseIds)}',
                  ),
                  trailing: Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: SariSupplySpacing.xs,
                    children: [
                      _statusChip('Active', success: true),
                      PopupMenuButton<String>(
                        enabled: !_saving && !_busy && _verified != null,
                        tooltip: 'Member actions',
                        onSelected: (action) async {
                          if (action == 'remove') {
                            final confirmed = await _confirmAccessChange(
                              title: 'Remove this role?',
                              message:
                                  'This member will lose the ${_roleName(member.role)} role for the assigned warehouses.',
                              actionLabel: 'Remove access',
                            );
                            if (!confirmed || !mounted) return;
                            await _mutate(
                              'remove:${member.memberId}:${member.role.wireValue}',
                              (operationId) =>
                                  widget.authorization.removeMemberRole(
                                companyId: widget.workspace.companyId,
                                member: member,
                                operationId: operationId,
                              ),
                            );
                          }
                        },
                        itemBuilder: (context) => const [
                          PopupMenuItem(
                            value: 'remove',
                            child: Text('Remove access'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
          const SizedBox(height: SariSupplySpacing.lg),
          Text('Pending invitations (${pending.length})',
              style: SariSupplyTypography.cardHeading
                  .copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: SariSupplySpacing.sm),
          if (_busy && _invitations.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: SariSupplySpacing.lg),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (pending.isEmpty)
            _emptyState(
              icon: Icons.mark_email_unread_outlined,
              title: 'No pending invitations',
              message: _warehouses.isEmpty
                  ? 'A warehouse is required before you can invite team members.'
                  : 'Invited riders and warehouse staff will appear here.',
            )
          else
            for (final invite in pending)
              Container(
                decoration: const BoxDecoration(
                  border: Border(
                    bottom: BorderSide(color: SariSupplyColors.divider),
                  ),
                ),
                child: _workspaceEntry(
                  leading: _initialAvatar(invite.email ?? 'S'),
                  title: Text(
                    invite.email ?? 'Verified company account',
                    style: SariSupplyTypography.body
                        .copyWith(fontWeight: FontWeight.w500),
                  ),
                  subtitle: Text(
                    '${_roleName(invite.role)}\n${_warehouseNames(invite.warehouseIds)}${_invitationExpiry(invite)}',
                    style: SariSupplyTypography.caption
                        .copyWith(color: SariSupplyColors.ink600),
                  ),
                  trailing: Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: SariSupplySpacing.xs,
                    children: [
                      _statusChip(
                          invite.expiresAt?.isBefore(DateTime.now()) == true
                              ? 'Expired'
                              : 'Pending'),
                      PopupMenuButton<String>(
                        enabled: !_saving && !_busy && _verified != null,
                        tooltip: 'Invitation actions',
                        onSelected: (action) async {
                          if (action == 'revoke') {
                            final confirmed = await _confirmAccessChange(
                              title: 'Revoke this invitation?',
                              message:
                                  'This person will no longer be able to accept the invitation. You can invite them again later.',
                              actionLabel: 'Revoke invitation',
                            );
                            if (!confirmed || !mounted) return;
                            await _mutate(
                              'revoke:${invite.id}',
                              (operationId) =>
                                  widget.authorization.revokeInvitation(
                                companyId: widget.workspace.companyId,
                                invitation: invite,
                                operationId: operationId,
                              ),
                            );
                          }
                        },
                        itemBuilder: (context) => const [
                          PopupMenuItem(
                            value: 'revoke',
                            child: Text('Revoke invitation'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
          if (history.isNotEmpty) ...[
            const SizedBox(height: SariSupplySpacing.md),
            ExpansionTile(
              key: const PageStorageKey('company-invitation-history'),
              tilePadding: EdgeInsets.zero,
              title: Text('Invitation history (${history.length})'),
              children: [
                for (final invite in history)
                  _workspaceEntry(
                    leading: const Icon(Icons.mail_outline),
                    title: Text(invite.email ?? 'Verified company account'),
                    subtitle: Text(
                        '${_roleName(invite.role)}\n${_warehouseNames(invite.warehouseIds)}'),
                    trailing: _statusChip(invite.status),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  String _warehouseNames(List<String> ids) => ids.map((id) {
        final matches = _warehouses.where((warehouse) => warehouse.id == id);
        return matches.isEmpty ? 'Unavailable warehouse' : matches.first.name;
      }).join(', ');

  String _invitationExpiry(CompanyInvitation invite) {
    final expiry = invite.expiresAt?.toLocal();
    if (expiry == null) return '';
    final date = MaterialLocalizations.of(context).formatMediumDate(expiry);
    return '\n${expiry.isBefore(DateTime.now()) ? 'Expired' : 'Expires'} $date';
  }

  Widget _workspaceEntry({
    required Widget title,
    Widget? subtitle,
    Widget? leading,
    Widget? trailing,
    VoidCallback? onTap,
  }) =>
      Padding(
        padding: const EdgeInsets.symmetric(vertical: SariSupplySpacing.xs),
        child: Material(
          color: SariSupplyColors.card,
          borderRadius: BorderRadius.circular(16),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.all(SariSupplySpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    if (leading != null) ...[
                      leading,
                      const SizedBox(width: SariSupplySpacing.sm),
                    ],
                    Expanded(
                        child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        DefaultTextStyle.merge(
                          style: SariSupplyTypography.bodyLarge
                              .copyWith(fontWeight: FontWeight.w600),
                          child: title,
                        ),
                        if (subtitle != null) ...[
                          const SizedBox(height: SariSupplySpacing.xs),
                          DefaultTextStyle.merge(
                            style: SariSupplyTypography.body
                                .copyWith(color: SariSupplyColors.ink600),
                            child: subtitle,
                          ),
                        ],
                      ],
                    )),
                  ]),
                  if (trailing != null) ...[
                    const SizedBox(height: SariSupplySpacing.sm),
                    trailing,
                  ],
                ],
              ),
            ),
          ),
        ),
      );

  Widget _emptyState({
    required IconData icon,
    required String title,
    required String message,
    bool boxed = true,
    bool centered = false,
    Widget? action,
  }) {
    final content = Padding(
      padding: const EdgeInsets.all(SariSupplySpacing.lg),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: centered ? 36 : 32, color: SariSupplyColors.ink300),
          const SizedBox(height: SariSupplySpacing.sm),
          if (title.isNotEmpty)
            Text(title,
                style: centered
                    ? SariSupplyTypography.bodyLarge
                        .copyWith(color: SariSupplyColors.ink600)
                    : SariSupplyTypography.cardHeading),
          if (message.isNotEmpty) ...[
            if (title.isNotEmpty) const SizedBox(height: SariSupplySpacing.xxs),
            Text(
              message,
              textAlign: TextAlign.center,
              style: SariSupplyTypography.body.copyWith(
                color: SariSupplyColors.ink600,
              ),
            ),
          ],
          if (action != null) ...[
            const SizedBox(height: SariSupplySpacing.md),
            action,
          ],
        ],
      ),
    );
    final surface = boxed ? Card(child: content) : content;
    return centered ? Center(child: surface) : surface;
  }

  Widget _initialAvatar(String value) => CircleAvatar(
        backgroundColor: SariSupplyColors.ink50,
        foregroundColor: SariSupplyColors.ink600,
        child: Text(value.trim().isEmpty
            ? '?'
            : value.trim().characters.first.toUpperCase()),
      );

  Widget _statusChip(String label, {bool success = false}) => Chip(
        label: Text(label),
        backgroundColor: success
            ? SariSupplyColors.success.withValues(alpha: .1)
            : SariSupplyColors.orange50,
        labelStyle: TextStyle(
          color:
              success ? SariSupplyColors.success : SariSupplyColors.orange700,
          fontWeight: FontWeight.w600,
        ),
        side: BorderSide.none,
        visualDensity: VisualDensity.compact,
      );

  @override
  Widget build(BuildContext context) {
    final workspace = widget.workspace;
    return DefaultTabController(
      length: _isOwner ? 3 : 2,
      child: Scaffold(
        backgroundColor: SariSupplyColors.paper,
        appBar: AppBar(
          automaticallyImplyLeading: Navigator.of(context).canPop(),
          toolbarHeight:
              MediaQuery.textScalerOf(context).scale(56).clamp(56, 168),
          backgroundColor: SariSupplyColors.paper,
          surfaceTintColor: Colors.transparent,
          title: const Row(children: [
            SariSupplySymbol(size: 28),
            SizedBox(width: SariSupplySpacing.sm),
            Flexible(child: Text('Company')),
          ]),
          actions: [
            IconButton(
              tooltip: 'Refresh company',
              onPressed: _busy || _saving ? null : _refresh,
              icon: const Icon(Icons.refresh),
            ),
            PopupMenuButton<String>(
              tooltip: 'Account and workspace actions',
              onSelected: (action) async {
                if (action == 'switch') widget.onSwitchContext?.call();
                if (action == 'signOut') await widget.onSignOut();
                if (action == 'payments') await _paymentInstructions();
              },
              itemBuilder: (context) => [
                if (_isOwner)
                  const PopupMenuItem(
                    value: 'payments',
                    child: ListTile(
                      leading: Icon(Icons.account_balance_outlined),
                      title: Text('Payment instructions'),
                    ),
                  ),
                if (widget.onSwitchContext != null)
                  const PopupMenuItem(
                    value: 'switch',
                    child: ListTile(
                      leading: Icon(Icons.swap_horiz),
                      title: Text('Switch workspace'),
                    ),
                  ),
                const PopupMenuItem(
                  value: 'signOut',
                  child: ListTile(
                    leading: Icon(Icons.logout),
                    title: Text('Sign out'),
                  ),
                ),
              ],
              child: Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: SariSupplySpacing.md),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircleAvatar(
                      radius: 20,
                      backgroundColor: SariSupplyColors.ink150,
                      foregroundColor: SariSupplyColors.ink900,
                      child: widget.accountLabel?.trim().isNotEmpty == true
                          ? Text(widget.accountLabel!
                              .trim()
                              .characters
                              .first
                              .toUpperCase())
                          : const Icon(Icons.person_outline),
                    ),
                    const SizedBox(width: SariSupplySpacing.xxs),
                    const Icon(Icons.keyboard_arrow_down,
                        color: SariSupplyColors.ink600),
                  ],
                ),
              ),
            ),
          ],
        ),
        bottomNavigationBar: widget.onNavigate == null
            ? null
            : CompanyNavigationBar(
                selectedIndex: 3,
                onDestinationSelected: (index) {
                  if (index != 3) widget.onNavigate!(index);
                },
              ),
        body: SafeArea(
          top: false,
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1000),
              child: SizedBox(
                width: double.infinity,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(
                        SariSupplySpacing.md,
                        SariSupplySpacing.md,
                        SariSupplySpacing.md,
                        SariSupplySpacing.sm,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(workspace.displayName,
                              style: SariSupplyTypography.cardHeading
                                  .copyWith(fontWeight: FontWeight.w700)),
                          const SizedBox(height: SariSupplySpacing.xxs),
                          Wrap(
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              Text(
                                _verified == null
                                    ? '${_roleName(workspace.role)} · Checking access'
                                    : _roleName(workspace.role),
                                style: SariSupplyTypography.body.copyWith(
                                  color: SariSupplyColors.ink600,
                                ),
                              ),
                              const SizedBox(width: SariSupplySpacing.xs),
                              if (_verified != null)
                                const Icon(
                                  Icons.check_circle,
                                  size: 18,
                                  color: SariSupplyColors.success,
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    if (_error != null)
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: SariSupplySpacing.md,
                        ),
                        child: SariSupplyStatus(message: _error!, error: true),
                      ),
                    if (_busy || _saving)
                      const LinearProgressIndicator(minHeight: 2),
                    Builder(builder: (context) {
                      final tabs = DefaultTabController.of(context);
                      final labels = [
                        'Warehouses',
                        'Team',
                        if (_isOwner) 'Applications'
                      ];
                      return AnimatedBuilder(
                        animation: tabs,
                        builder: (context, _) => Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: SariSupplySpacing.md),
                          child: CompanyQueueTabs(tabs: [
                            for (var index = 0; index < labels.length; index++)
                              CompanyQueueTab(
                                label: labels[index],
                                selected: tabs.index == index,
                                onTap: () => tabs.animateTo(index),
                              ),
                          ]),
                        ),
                      );
                    }),
                    Expanded(
                      child: TabBarView(
                        children: [
                          _locationsTab(context),
                          _teamTab(context),
                          if (_isOwner)
                            _CompanyApplicationReviewTab(
                              companyId: workspace.companyId,
                              onSignOut: widget.onSignOut,
                            ),
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
}

class _CompanyApplicationReviewTab extends StatefulWidget {
  const _CompanyApplicationReviewTab({
    required this.companyId,
    required this.onSignOut,
  });

  final String companyId;
  final Future<void> Function() onSignOut;

  @override
  State<_CompanyApplicationReviewTab> createState() =>
      _CompanyApplicationReviewTabState();
}

class _CompanyApplicationReviewTabState
    extends State<_CompanyApplicationReviewTab> {
  late final CompanyMerchantApplicationFunctions _reviews;

  @override
  void initState() {
    super.initState();
    _reviews = CompanyMerchantApplicationFunctions.forCompany(widget.companyId);
  }

  @override
  Widget build(BuildContext context) => MerchantReviewListScreen(
        reviews: _reviews,
        onSignOut: widget.onSignOut,
        embedded: true,
      );
}

String _roleName(CompanyRole role) => switch (role) {
      CompanyRole.companyOwner => 'Company Owner',
      CompanyRole.warehouseOperations => 'Warehouse Operations',
      CompanyRole.rider => 'Rider',
    };

final class _InvitationDraft {
  const _InvitationDraft(this.email, this.role, this.warehouseIds);
  final String email;
  final CompanyRole role;
  final List<String> warehouseIds;
}
