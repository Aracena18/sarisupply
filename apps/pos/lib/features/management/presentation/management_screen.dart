import 'package:firebase_core/firebase_core.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:sarisupply_auth/sarisupply_auth.dart';
import 'package:sarisupply_design_system/sarisupply_design_system.dart';
import 'package:sarisupply_firebase/sarisupply_firebase.dart';
import 'package:sarisupply_models/sarisupply_models.dart';
import 'management_form_dialog.dart';
import 'store_overview_screen.dart';

enum _ManagementSection { overview, branches, team, devices }

class ManagementScreen extends StatefulWidget {
  const ManagementScreen(
      {super.key,
      required this.memberships,
      required this.management,
      required this.membershipRepository,
      required this.cashiers,
      required this.devices,
      this.onCatalog,
      this.onOpenBranch,
      this.loadOverviewData,
      this.applicationPending = false});
  final List<MerchantMembership> memberships;
  final ManagementRepository management;
  final MembershipRepository membershipRepository;
  final CashierRepository cashiers;
  final DeviceRepository devices;
  final Future<void> Function()? onCatalog;
  final OpenOwnerBranch? onOpenBranch;
  final LoadStoreOverviewData? loadOverviewData;
  final bool applicationPending;
  @override
  State<ManagementScreen> createState() => _ManagementScreenState();
}

class _ManagementScreenState extends State<ManagementScreen>
    with WidgetsBindingObserver {
  MerchantMembership? _member;
  ManagementKind _kind = ManagementKind.cashiers;
  final _records = <ManagementRecord>[];
  final _search = TextEditingController();
  final Map<String, _ManagementPageState> _pages = {};
  int _request = 0;
  bool _loading = false, _denied = false;
  String? _cursor;
  String? _error;
  bool _busy = false;
  bool _pinVisible = false;
  bool _formVisible = false;
  late _ManagementSection _section;
  bool get _owner => _member?.role == MerchantRole.owner;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _member = widget.memberships.firstOrNull;
    _section = _owner ? _ManagementSection.overview : _ManagementSection.team;
    if (_member != null && _section != _ManagementSection.overview) _load();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed &&
        !_pinVisible &&
        !_formVisible &&
        _section != _ManagementSection.overview) {
      unawaited(_load(force: false));
    }
    if (state != AppLifecycleState.resumed && _pinVisible && mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  void didUpdateWidget(covariant ManagementScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    final current = _member;
    if (current == null) return;
    final candidates =
        widget.memberships.where((m) => m.merchantId == current.merchantId);
    if (candidates.isEmpty ||
        _pageKey(candidates.first, _kind) != _pageKey(current, _kind)) {
      _request++;
      _pages.clear();
      _search.clear();
      _records.clear();
      _cursor = null;
      _member = candidates.firstOrNull;
      if (_member != null) unawaited(_load(force: false));
    }
  }

  @override
  void dispose() {
    _search.dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  List<ManagementKind> get _kinds => ManagementKind.values
      .where((k) =>
          _owner ||
          ![ManagementKind.managers, ManagementKind.invitations].contains(k))
      .toList();
  String _label(ManagementKind k) =>
      '${k.name[0].toUpperCase()}${k.name.substring(1)}';
  void _choose(ManagementKind kind) {
    if (_busy) return;
    _search.clear();
    setState(() => _kind = kind);
    _load(force: false);
  }

  List<_ManagementSection> get _sections => [
        if (_owner) _ManagementSection.overview,
        _ManagementSection.branches,
        _ManagementSection.team,
        _ManagementSection.devices,
      ];

  String _sectionLabel(_ManagementSection section) => switch (section) {
        _ManagementSection.overview => 'Overview',
        _ManagementSection.branches => 'Branches',
        _ManagementSection.team => 'Team',
        _ManagementSection.devices => 'Devices',
      };

  IconData _sectionIcon(_ManagementSection section) => switch (section) {
        _ManagementSection.overview => Icons.dashboard_outlined,
        _ManagementSection.branches => Icons.store_outlined,
        _ManagementSection.team => Icons.people_outline,
        _ManagementSection.devices => Icons.point_of_sale_outlined,
      };

  void _selectSection(_ManagementSection section) {
    if (_busy) return;
    if (_section != section) _search.clear();
    setState(() {
      _section = section;
      switch (section) {
        case _ManagementSection.overview:
          break;
        case _ManagementSection.branches:
          _kind = ManagementKind.branches;
          break;
        case _ManagementSection.team:
          if (!_kinds.contains(_kind) ||
              ![
                ManagementKind.cashiers,
                ManagementKind.managers,
                ManagementKind.invitations
              ].contains(_kind)) {
            _kind = ManagementKind.cashiers;
          }
          break;
        case _ManagementSection.devices:
          _kind = ManagementKind.devices;
          break;
      }
    });
    if (section != _ManagementSection.overview) _load(force: false);
  }

  void _selectTeamKind(ManagementKind kind) {
    if (_busy || !_kinds.contains(kind)) return;
    _choose(kind);
  }

  void _selectStore(String? merchantId) {
    if (_busy || merchantId == null) return;
    final membership = widget.memberships
        .firstWhere((candidate) => candidate.merchantId == merchantId);
    setState(() {
      _request++;
      _records.clear();
      _cursor = null;
      _member = membership;
      _search.clear();
      _kind = switch (_section) {
        _ManagementSection.branches => ManagementKind.branches,
        _ManagementSection.devices => ManagementKind.devices,
        _ => _kinds.contains(_kind) ? _kind : ManagementKind.cashiers,
      };
      if (!_owner && _section == _ManagementSection.overview) {
        _section = _ManagementSection.team;
      }
    });
    if (_section != _ManagementSection.overview) _load();
  }

  String _pageKey(MerchantMembership member, ManagementKind kind) =>
      '${member.userId}:${member.merchantId}:${member.role.name}:'
      '${member.updatedAt.microsecondsSinceEpoch}:${member.allBranches}:'
      '${member.branchIds.join(',')}:${kind.name}';

  Future<void> _load({bool more = false, bool force = true}) async {
    if (_busy || _member == null || _denied) return;
    final member = _member!;
    final kind = _kind;
    final key = _pageKey(member, kind);
    final state = _pages.putIfAbsent(key, _ManagementPageState.new);
    final request = ++_request;
    setState(() {
      _records
        ..clear()
        ..addAll(state.records);
      _cursor = state.cursor;
      _error = null;
    });
    if (!more &&
        !force &&
        state.loadedAt != null &&
        DateTime.now().difference(state.loadedAt!) <
            const Duration(seconds: 30)) {
      setState(() => _loading = false);
      return;
    }
    if (more && state.cursor == null) return;
    setState(() => _loading = true);
    try {
      await (state.work ??= _fetchPage(member, kind, state, more));
      if (!mounted || request != _request || _denied) return;
      setState(() {
        _records
          ..clear()
          ..addAll(state.records);
        _cursor = state.cursor;
      });
    } catch (error) {
      if (!mounted) return;
      _invalidateDenied(error);
      if (request == _request || _denied) {
        setState(() => _error = operationErrorMessage(error));
      }
    } finally {
      state.work = null;
      if (mounted && request == _request) setState(() => _loading = false);
    }
  }

  Future<void> _fetchPage(MerchantMembership member, ManagementKind kind,
      _ManagementPageState state, bool more) async {
    final records = <String, ManagementRecord>{
      if (more)
        for (final r in state.records) r.id: r,
    };
    String? cursor = more ? state.cursor : null;
    final count = more ? 1 : state.pageCount;
    var pages = 0;
    do {
      final page =
          await widget.management.list(member.merchantId, kind, cursor: cursor);
      if (_denied || !mounted) return;
      for (final record in page.records) {
        records[record.id] = record;
      }
      cursor = page.nextCursor;
      pages++;
    } while (pages < count && cursor != null);
    state.records = records.values.toList();
    state.cursor = cursor;
    state.pageCount = more ? state.pageCount + 1 : pages;
    state.loadedAt = DateTime.now();
  }

  void _invalidateDenied(Object error) {
    if (error is FirebaseException &&
        ['permission-denied', 'unauthenticated'].contains(error.code)) {
      _denied = true;
      _pages.clear();
      _records.clear();
      _cursor = null;
    }
  }

  Future<void> _pin(IssuedCashierPin pin) async {
    setState(() => _pinVisible = true);
    try {
      await showDialog<void>(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
                  scrollable: true,
                  title: const Text('Temporary PIN'),
                  content: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(pin.temporaryPin,
                            style: Theme.of(context).textTheme.headlineMedium),
                        const SizedBox(height: 12),
                        const Text(
                            'Give this PIN to the cashier. They must change it at first sign-in.'),
                      ]),
                  actions: [
                    FilledButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Done'))
                  ]));
    } finally {
      if (mounted) setState(() => _pinVisible = false);
    }
  }

  Future<void> _form(ManagementAction action,
      [ManagementRecord? existing]) async {
    if (_busy || _denied || _member == null) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final branches =
          await widget.membershipRepository.listAccessibleBranches(_member!);
      if (!mounted) return;
      final merchantId = _member!.merchantId;
      setState(() => _formVisible = true);
      final pin = await showSariSupplyForm<IssuedCashierPin>(
          context: context,
          builder: (_) => ManagementFormDialog(
                action: action,
                branches: branches,
                existing: existing,
                onSubmit: (operationId, fields, ids, all) async {
                  switch (action) {
                    case ManagementAction.branch:
                      await widget.membershipRepository.createBranch(
                          merchantId: merchantId,
                          name: fields['name']!,
                          code: fields['code']!.toUpperCase(),
                          address: fields['address']!,
                          operationId: operationId);
                    case ManagementAction.cashier:
                      return widget.cashiers.createCashier(
                          merchantId: merchantId,
                          displayName: fields['name']!,
                          employeeCode: fields['code']!,
                          assignedBranchIds: ids,
                          operationId: operationId);
                    case ManagementAction.invitation:
                      await widget.membershipRepository.createManagerInvitation(
                          merchantId: merchantId,
                          email: fields['email']!,
                          allBranches: all,
                          branchIds: ids,
                          operationId: operationId);
                    case ManagementAction.access:
                      await widget.membershipRepository.updateManagerAccess(
                          merchantId: merchantId,
                          managerUid: existing!.id,
                          allBranches: all,
                          branchIds: ids);
                  }
                  return null;
                },
              ));
      if (mounted && pin != null) await _pin(pin);
    } catch (error) {
      _invalidateDenied(error);
      if (mounted) setState(() => _error = operationErrorMessage(error));
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
          _formVisible = false;
        });
      }
    }
    if (mounted && _error == null) await _load();
  }

  Future<void> _action(String label, ManagementRecord record,
      Future<IssuedCashierPin?> Function() action) async {
    if (_busy || _denied) return;
    final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
                title: Text('$label?'),
                scrollable: true,
                content: Text('${record.name}\n\n${switch (label) {
                  'Reset PIN' =>
                    'The current PIN stops working. Give the new temporary PIN to the cashier to change at sign-in.',
                  'Suspend' => 'This cashier will lose access to sign in.',
                  'Restore' =>
                    'This cashier can sign in again with their current branch assignments.',
                  'Revoke device' =>
                    'This device must be activated again. Saved inventory and pending counts remain on the device.',
                  'Deactivate branch' =>
                    'This branch will be unavailable for new device activation and branch assignments.',
                  'Remove manager' =>
                    'This manager will lose access to the store.',
                  'Revoke invitation' =>
                    'This invitation can no longer be accepted.',
                  _ => 'Confirm this change.',
                }}'),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('Cancel')),
                  FilledButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: Text(label)),
                ]));
    if (confirmed != true || !mounted || _busy || _denied) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final pin = await action();
      if (mounted && pin != null) await _pin(pin);
    } catch (error) {
      _invalidateDenied(error);
      if (mounted) setState(() => _error = operationErrorMessage(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
    if (mounted && _error == null) await _load();
  }

  Widget _actions(ManagementRecord r) {
    if ((_kind == ManagementKind.branches &&
            (!_owner || r.status != 'active')) ||
        ([
              ManagementKind.devices,
              ManagementKind.invitations,
              ManagementKind.managers
            ].contains(_kind) &&
            r.status != 'active')) {
      return const SizedBox.shrink();
    }
    final merchant = _member!.merchantId;
    return PopupMenuButton<String>(
        enabled: !_busy && !_denied,
        tooltip: 'Actions for ${r.name}',
        onSelected: (value) async {
          if (value == 'Edit access') {
            await _form(ManagementAction.access, r);
            return;
          }
          await _action(value, r, () async {
            switch (_kind) {
              case ManagementKind.cashiers:
                if (value == 'Reset PIN') {
                  return widget.cashiers.resetPin(merchant, r.id);
                }
                await widget.cashiers.setCashierStatus(merchant, r.id,
                    r.status == 'active' ? 'suspended' : 'active');
              case ManagementKind.devices:
                await widget.devices.revoke(merchant, r.id);
              case ManagementKind.branches:
                await widget.membershipRepository
                    .deactivateBranch(merchant, r.id);
              case ManagementKind.managers:
                await widget.membershipRepository.removeManager(merchant, r.id);
              case ManagementKind.invitations:
                await widget.membershipRepository
                    .revokeManagerInvitation(merchant, r.id);
            }
            return null;
          });
        },
        itemBuilder: (_) => [
              if (_kind == ManagementKind.cashiers) ...[
                _menuItem('Reset PIN', Icons.key_outlined),
                _menuItem(r.status == 'active' ? 'Suspend' : 'Restore',
                    r.status == 'active' ? Icons.block : Icons.restore,
                    destructive: r.status == 'active'),
              ],
              if (_kind == ManagementKind.devices && r.status == 'active')
                _menuItem('Revoke device', Icons.link_off, destructive: true),
              if (_kind == ManagementKind.branches &&
                  _owner &&
                  r.status == 'active')
                _menuItem('Deactivate branch', Icons.store_outlined,
                    destructive: true),
              if (_kind == ManagementKind.managers && r.status == 'active') ...[
                _menuItem('Edit access', Icons.edit_outlined),
                _menuItem('Remove manager', Icons.person_remove_outlined,
                    destructive: true),
              ],
              if (_kind == ManagementKind.invitations && r.status == 'active')
                _menuItem('Revoke invitation', Icons.mail_outline,
                    destructive: true),
            ]);
  }

  PopupMenuItem<String> _menuItem(String label, IconData icon,
      {bool destructive = false}) {
    final color = destructive
        ? Theme.of(context).colorScheme.error
        : Theme.of(context).colorScheme.onSurface;
    return PopupMenuItem(
      value: label,
      child: Row(children: [
        Icon(icon, size: 20, color: color),
        const SizedBox(width: 12),
        Flexible(child: Text(label, style: TextStyle(color: color))),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
      appBar: sariSupplyTaskAppBar(context, title: 'Store management'),
      body: LayoutBuilder(builder: (context, constraints) {
        final wide = constraints.maxWidth >= 1024;
        final showOverview = _section == _ManagementSection.overview && _owner;
        return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          if (wide && _member != null)
            SizedBox(
                width: 220,
                child: SariSupplyPageContent(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                      for (final section in _sections)
                        Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: section == _section
                                ? FilledButton.icon(
                                    onPressed: _busy
                                        ? null
                                        : () => _selectSection(section),
                                    icon: Icon(_sectionIcon(section)),
                                    label: Text(_sectionLabel(section)))
                                : TextButton.icon(
                                    onPressed: _busy
                                        ? null
                                        : () => _selectSection(section),
                                    icon: Icon(_sectionIcon(section)),
                                    label: Text(_sectionLabel(section)))),
                    ]))),
          Expanded(
            child: showOverview
                ? Center(
                    child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 900),
                        child: _overviewContent()))
                : SariSupplyPageContent(child: _content()),
          ),
        ]);
      }),
      bottomNavigationBar: _member == null
          ? null
          : LayoutBuilder(builder: (context, constraints) {
              if (constraints.maxWidth >= 1024) return const SizedBox.shrink();
              final sections = _sections;
              return NavigationBar(
                selectedIndex: sections.indexOf(_section),
                onDestinationSelected: (index) =>
                    _selectSection(sections[index]),
                destinations: [
                  for (final section in sections)
                    NavigationDestination(
                      icon: Icon(_sectionIcon(section)),
                      label: _sectionLabel(section),
                    ),
                ],
              );
            }));

  Widget _overviewContent() => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (widget.memberships.length > 1)
            DropdownButtonFormField<String>(
              isExpanded: true,
              initialValue: _member!.merchantId,
              decoration: const InputDecoration(labelText: 'Store'),
              items: widget.memberships
                  .map((membership) => DropdownMenuItem(
                      value: membership.merchantId,
                      child: Text(membership.merchantName)))
                  .toList(),
              onChanged: _selectStore,
            ),
          Expanded(
            child: StoreOverviewScreen(
              key: ValueKey(_member!.merchantId),
              membership: _member!,
              membershipRepository: widget.membershipRepository,
              onOpenBranch: widget.onOpenBranch,
              loadData: widget.loadOverviewData,
            ),
          ),
        ],
      );

  String get _description => switch (_kind) {
        ManagementKind.branches =>
          'Manage the locations where your store operates.',
        ManagementKind.cashiers =>
          'Manage cashier sign-in and assigned branches.',
        ManagementKind.managers =>
          'Manage who can run your store and their branch access.',
        ManagementKind.invitations =>
          'Invite managers using their Google account email.',
        ManagementKind.devices =>
          'Review the POS devices activated for your store.',
      };

  IconData get _recordIcon => switch (_kind) {
        ManagementKind.branches => Icons.store_outlined,
        ManagementKind.cashiers => Icons.badge_outlined,
        ManagementKind.managers => Icons.manage_accounts_outlined,
        ManagementKind.invitations => Icons.mail_outline,
        ManagementKind.devices => Icons.point_of_sale_outlined,
      };

  Widget? get _createButton {
    final action = switch (_kind) {
      ManagementKind.branches when _owner => ManagementAction.branch,
      ManagementKind.cashiers => ManagementAction.cashier,
      ManagementKind.invitations => ManagementAction.invitation,
      _ => null,
    };
    if (action == null) return null;
    return FilledButton.icon(
      onPressed: _busy || _denied ? null : () => _form(action),
      icon: const Icon(Icons.add, size: 20),
      label: Text(switch (action) {
        ManagementAction.branch => 'Add branch',
        ManagementAction.cashier => 'Add cashier',
        _ => 'Invite manager',
      }),
    );
  }

  Widget _statusBadge(String status) {
    final colors = Theme.of(context).colorScheme;
    final pendingInvitation =
        _kind == ManagementKind.invitations && status == 'active';
    final label = pendingInvitation
        ? 'Awaiting acceptance'
        : status.isEmpty
            ? 'Status unavailable'
            : '${status[0].toUpperCase()}${status.substring(1)}';
    final color = pendingInvitation
        ? colors.onSurfaceVariant
        : switch (status) {
            'active' || 'accepted' => SariSupplyColors.success,
            'revoked' || 'inactive' => colors.error,
            _ => colors.onSurfaceVariant,
          };
    return Semantics(
      label: 'Status: $label',
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: color.withValues(alpha: .08),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(label,
            style: Theme.of(context)
                .textTheme
                .labelMedium
                ?.copyWith(color: color)),
      ),
    );
  }

  Widget _recordCard(ManagementRecord record) {
    final theme = Theme.of(context);
    final isDeviceId =
        _kind == ManagementKind.devices && record.name == record.id;
    final scope = record.allBranches
        ? 'All branches'
        : '${record.branchIds.length} assigned ${record.branchIds.length == 1 ? 'branch' : 'branches'}';
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 8, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Padding(
                padding: const EdgeInsets.only(top: 4, right: 12),
                child: Icon(_recordIcon,
                    color: theme.colorScheme.onSurfaceVariant),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(top: 3),
                  child: Text(isDeviceId ? 'POS device' : record.name,
                      style: theme.textTheme.titleMedium),
                ),
              ),
              _actions(record),
            ]),
            if (record.code.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                  '${_kind == ManagementKind.branches ? 'Branch code' : 'Code'}: ${record.code}',
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
            ],
            if (_kind == ManagementKind.devices) ...[
              const SizedBox(height: 6),
              Text('Device ID: ${record.id}', style: theme.textTheme.bodySmall),
            ],
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                _statusBadge(record.status),
                if (_kind != ManagementKind.branches)
                  Text(scope, style: theme.textTheme.bodyMedium),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _content() {
    if (_member == null) {
      return widget.applicationPending
          ? const SariSupplyStatus(
              message:
                  'Application pending review. The supplying Company Owner will review your application. Store access will be available after approval.',
              icon: Icons.hourglass_top)
          : const SariSupplyStatus(
              message: 'No active store access for this account');
    }
    final theme = Theme.of(context);
    final query = _search.text.trim().toLowerCase();
    final visible = _records
        .where((record) =>
            query.isEmpty ||
            '${record.name} ${record.code} ${record.id} ${record.status}'
                .toLowerCase()
                .contains(query))
        .toList();
    final create = _createButton;
    final loadedLabel = _records.length == 1
        ? switch (_kind) {
            ManagementKind.branches => 'branch',
            ManagementKind.cashiers => 'cashier',
            ManagementKind.managers => 'manager',
            ManagementKind.invitations => 'invitation',
            ManagementKind.devices => 'device',
          }
        : _kind.name;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      if (widget.memberships.length > 1) ...[
        DropdownButtonFormField<String>(
          isExpanded: true,
          initialValue: _member!.merchantId,
          decoration: const InputDecoration(labelText: 'Store'),
          items: widget.memberships
              .map((m) => DropdownMenuItem(
                  value: m.merchantId, child: Text(m.merchantName)))
              .toList(),
          onChanged: _busy ? null : _selectStore,
        ),
        const SizedBox(height: 20),
      ] else
        Text(_member!.merchantName,
            style: theme.textTheme.labelLarge
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
      const SizedBox(height: 4),
      Text(_sectionLabel(_section), style: theme.textTheme.headlineMedium),
      const SizedBox(height: 6),
      Text(_description, style: theme.textTheme.bodyMedium),
      const SizedBox(height: 20),
      if (_section == _ManagementSection.team && _owner) ...[
        Wrap(spacing: 8, runSpacing: 8, children: [
          for (final kind in const [
            ManagementKind.cashiers,
            ManagementKind.managers,
            ManagementKind.invitations
          ])
            ChoiceChip(
              label: Text(_label(kind)),
              selected: _kind == kind,
              showCheckmark: false,
              onSelected: _busy ? null : (_) => _selectTeamKind(kind),
            ),
        ]),
        const SizedBox(height: 16),
      ],
      Wrap(
        spacing: 12,
        runSpacing: 8,
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          if (create != null) create,
          if (_kind == ManagementKind.managers)
            OutlinedButton.icon(
              onPressed: _busy || _denied
                  ? null
                  : () => _selectTeamKind(ManagementKind.invitations),
              icon: const Icon(Icons.mail_outline, size: 20),
              label: const Text('View invitations'),
            ),
          TextButton.icon(
            onPressed: _busy || _loading || _denied ? null : _load,
            icon: const Icon(Icons.refresh, size: 20),
            label: const Text('Refresh'),
          ),
        ],
      ),
      const SizedBox(height: 16),
      if (_records.isNotEmpty || query.isNotEmpty) ...[
        TextField(
          controller: _search,
          enabled: !_denied,
          textInputAction: TextInputAction.search,
          onChanged: (_) => setState(() {}),
          decoration: InputDecoration(
            labelText: 'Search ${_kind.name}',
            helperText: _cursor != null
                ? 'Searches loaded records. Load more to search further.'
                : null,
            helperMaxLines: 3,
            prefixIcon: const Icon(Icons.search),
            suffixIcon: query.isEmpty
                ? null
                : IconButton(
                    tooltip: 'Clear search',
                    onPressed: () => setState(_search.clear),
                    icon: const Icon(Icons.close),
                  ),
          ),
        ),
        const SizedBox(height: 16),
      ],
      if ((_busy || _loading) && !_pinVisible && !_formVisible)
        const Padding(
            padding: EdgeInsets.only(bottom: 12),
            child: LinearProgressIndicator()),
      if (_error != null)
        Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: SariSupplyStatus(message: _error!, error: true, actions: [
            if (!_denied)
              TextButton(
                  onPressed: _busy || _loading ? null : _load,
                  child: const Text('Retry')),
          ]),
        ),
      if (_records.isNotEmpty) ...[
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Text(
              query.isEmpty
                  ? '${_records.length} $loadedLabel loaded'
                  : '${visible.length} of ${_records.length} loaded records',
              style: theme.textTheme.labelLarge
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
        ),
        for (final record in visible) _recordCard(record),
        if (visible.isEmpty)
          SariSupplyStatus(
            message: 'No matching ${_kind.name} in the loaded records.',
            icon: Icons.search_off,
            actions: [
              TextButton(
                  onPressed: () => setState(_search.clear),
                  child: const Text('Clear search'))
            ],
          ),
      ] else if (!_busy && !_loading && _error == null)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: SariSupplyStatus(
            message: switch (_kind) {
              ManagementKind.branches => _owner
                  ? 'No branches loaded. Add a branch to set up a store location.'
                  : 'No branches loaded for your access.',
              ManagementKind.cashiers =>
                'No cashiers loaded. Add a cashier and choose their branches.',
              ManagementKind.managers =>
                'No managers loaded. View invitations to invite a manager.',
              ManagementKind.invitations =>
                'No invitations loaded. Invite a manager using their Google account email.',
              ManagementKind.devices =>
                'No devices loaded. Activate a POS device from device setup.',
            },
            icon: _recordIcon,
          ),
        ),
      if (_cursor != null)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: OutlinedButton.icon(
            onPressed:
                _busy || _loading || _denied ? null : () => _load(more: true),
            icon: const Icon(Icons.expand_more),
            label: const Text('Load more'),
          ),
        ),
      if (_kind == ManagementKind.devices) ...[
        const SizedBox(height: 12),
        Text(
            'Activate new devices from device setup. Revoking access requires activation again; saved inventory and pending counts remain on the device.',
            style: theme.textTheme.bodySmall
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
      ],
      if (widget.onCatalog != null) ...[
        const SizedBox(height: 20),
        const Divider(),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: _busy ? null : widget.onCatalog,
            icon: const SariSupplyIcon(SariSupplyIconName.inventory, size: 20),
            label: const Text('Catalog and stock'),
          ),
        ),
      ],
    ]);
  }
}

final class _ManagementPageState {
  List<ManagementRecord> records = [];
  String? cursor;
  DateTime? loadedAt;
  int pageCount = 1;
  Future<void>? work;
}
