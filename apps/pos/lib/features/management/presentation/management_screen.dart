import 'package:flutter/material.dart';
import 'package:sarisupply_auth/sarisupply_auth.dart';
import 'package:sarisupply_design_system/sarisupply_design_system.dart';
import 'package:sarisupply_firebase/sarisupply_firebase.dart';
import 'package:sarisupply_models/sarisupply_models.dart';
import 'management_form_dialog.dart';

class ManagementScreen extends StatefulWidget {
  const ManagementScreen(
      {super.key,
      required this.memberships,
      required this.management,
      required this.membershipRepository,
      required this.cashiers,
      required this.devices,
      this.onCatalog});
  final List<MerchantMembership> memberships;
  final ManagementRepository management;
  final MembershipRepository membershipRepository;
  final CashierRepository cashiers;
  final DeviceRepository devices;
  final Future<void> Function()? onCatalog;
  @override
  State<ManagementScreen> createState() => _ManagementScreenState();
}

class _ManagementScreenState extends State<ManagementScreen>
    with WidgetsBindingObserver {
  MerchantMembership? _member;
  ManagementKind _kind = ManagementKind.cashiers;
  final _records = <ManagementRecord>[];
  String? _cursor;
  String? _error;
  bool _busy = false;
  bool _pinVisible = false;
  bool _formVisible = false;
  bool get _owner => _member?.role == MerchantRole.owner;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _member = widget.memberships.firstOrNull;
    if (_member != null) _load();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed && _pinVisible && mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  void dispose() {
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
    setState(() => _kind = kind);
    _load();
  }

  Future<void> _load({bool more = false}) async {
    if (_busy || _member == null) return;
    setState(() {
      _busy = true;
      _error = null;
      if (!more) {
        _records.clear();
        _cursor = null;
      }
    });
    try {
      final page = await widget.management
          .list(_member!.merchantId, _kind, cursor: more ? _cursor : null);
      if (!mounted) return;
      setState(() {
        if (!more) _records.clear();
        _records.addAll(page.records);
        _cursor = page.nextCursor;
      });
    } catch (error) {
      if (mounted) setState(() => _error = operationErrorMessage(error));
    } finally {
      if (mounted) setState(() => _busy = false);
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
    if (_busy || _member == null) return;
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
    if (_busy) return;
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
    if (confirmed != true || !mounted || _busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final pin = await action();
      if (mounted && pin != null) await _pin(pin);
    } catch (error) {
      if (mounted) setState(() => _error = operationErrorMessage(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
    if (mounted && _error == null) await _load();
  }

  Widget _actions(ManagementRecord r) {
    if ((_kind == ManagementKind.branches && !_owner) ||
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
        enabled: !_busy,
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
                const PopupMenuItem(
                    value: 'Reset PIN', child: Text('Reset PIN')),
                PopupMenuItem(
                    value: r.status == 'active' ? 'Suspend' : 'Restore',
                    child: Text(r.status == 'active' ? 'Suspend' : 'Restore'))
              ],
              if (_kind == ManagementKind.devices && r.status == 'active')
                const PopupMenuItem(
                    value: 'Revoke device', child: Text('Revoke device')),
              if (_kind == ManagementKind.branches &&
                  _owner &&
                  r.status == 'active')
                const PopupMenuItem(
                    value: 'Deactivate branch',
                    child: Text('Deactivate branch')),
              if (_kind == ManagementKind.managers && r.status == 'active') ...[
                const PopupMenuItem(
                    value: 'Edit access', child: Text('Edit access')),
                const PopupMenuItem(
                    value: 'Remove manager', child: Text('Remove manager'))
              ],
              if (_kind == ManagementKind.invitations && r.status == 'active')
                const PopupMenuItem(
                    value: 'Revoke invitation',
                    child: Text('Revoke invitation')),
            ]);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
      appBar: sariSupplyTaskAppBar(context, title: 'Manage store'),
      body: LayoutBuilder(builder: (context, constraints) {
        final wide = constraints.maxWidth >= 1024;
        return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          if (wide && _member != null)
            SizedBox(
                width: 220,
                child: SariSupplyPageContent(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                      for (final kind in _kinds)
                        Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: kind == _kind
                                ? FilledButton(
                                    onPressed:
                                        _busy ? null : () => _choose(kind),
                                    child: Text(_label(kind)))
                                : TextButton(
                                    onPressed:
                                        _busy ? null : () => _choose(kind),
                                    child: Text(_label(kind)))),
                    ]))),
          Expanded(child: SariSupplyPageContent(child: _content(wide))),
        ]);
      }));

  Widget _content(bool wide) =>
      Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        if (_member == null)
          const SariSupplyStatus(
              message: 'No active store access for this account')
        else ...[
          if (widget.memberships.length > 1)
            DropdownButtonFormField<String>(
                isExpanded: true,
                initialValue: _member!.merchantId,
                decoration: const InputDecoration(labelText: 'Store'),
                items: widget.memberships
                    .map((m) => DropdownMenuItem(
                        value: m.merchantId, child: Text(m.merchantName)))
                    .toList(),
                onChanged: _busy
                    ? null
                    : (id) {
                        setState(() {
                          _member = widget.memberships
                              .firstWhere((m) => m.merchantId == id);
                          _kind = ManagementKind.cashiers;
                        });
                        _load();
                      })
          else
            Text(_member!.merchantName,
                style: Theme.of(context).textTheme.titleMedium),
          if (widget.onCatalog != null)
            Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                    onPressed: _busy ? null : widget.onCatalog,
                    icon: const Icon(Icons.inventory_2_outlined),
                    label: const Text('Catalog and stock'))),
          const SizedBox(height: 16),
          if (!wide)
            DropdownButtonFormField<ManagementKind>(
                key: ValueKey(_kind),
                initialValue: _kind,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Manage'),
                items: _kinds
                    .map((k) =>
                        DropdownMenuItem(value: k, child: Text(_label(k))))
                    .toList(),
                onChanged: _busy
                    ? null
                    : (kind) {
                        if (kind != null) _choose(kind);
                      }),
          const SizedBox(height: 16),
          Wrap(spacing: 12, runSpacing: 8, children: [
            if (_kind == ManagementKind.cashiers)
              FilledButton(
                  onPressed:
                      _busy ? null : () => _form(ManagementAction.cashier),
                  child: const Text('Add cashier')),
            if (_kind == ManagementKind.branches && _owner)
              FilledButton(
                  onPressed:
                      _busy ? null : () => _form(ManagementAction.branch),
                  child: const Text('Add branch')),
            if (_kind == ManagementKind.invitations)
              FilledButton(
                  onPressed:
                      _busy ? null : () => _form(ManagementAction.invitation),
                  child: const Text('Invite manager')),
            TextButton.icon(
                onPressed: _busy ? null : _load,
                icon: const Icon(Icons.refresh),
                label: const Text('Refresh')),
          ]),
          if (_busy && !_pinVisible && !_formVisible)
            const LinearProgressIndicator(),
          if (_error != null)
            Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: SariSupplyStatus(
                    message: _error!,
                    error: true,
                    actions: [
                      TextButton(
                          onPressed: _busy ? null : _load,
                          child: const Text('Retry'))
                    ])),
          if (!_busy && _records.isEmpty && _error == null)
            Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: SariSupplyStatus(
                    message: 'No ${_kind.name} on this page',
                    icon: Icons.store_outlined)),
          for (final record in _records)
            Card(
                child: ListTile(
                    title: Text(record.name),
                    subtitle: Text([
                      if (record.code.isNotEmpty) record.code,
                      record.status
                    ].join(' · ')),
                    trailing: _actions(record))),
          if (_cursor != null)
            TextButton(
                onPressed: _busy ? null : () => _load(more: true),
                child: const Text('Load more')),
        ],
      ]);
}
