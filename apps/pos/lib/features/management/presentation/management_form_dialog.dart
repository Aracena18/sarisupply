import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:sarisupply_design_system/sarisupply_design_system.dart';
import 'package:sarisupply_auth/sarisupply_auth.dart';
import 'package:sarisupply_firebase/sarisupply_firebase.dart';
import 'package:sarisupply_models/sarisupply_models.dart';
import 'package:uuid/uuid.dart';

enum ManagementAction { branch, cashier, invitation, access }

class ManagementFormDialog extends StatefulWidget {
  const ManagementFormDialog(
      {super.key,
      required this.action,
      required this.branches,
      required this.onSubmit,
      this.existing});
  final ManagementAction action;
  final List<Branch> branches;
  final ManagementRecord? existing;
  final Future<IssuedCashierPin?> Function(
      String operationId,
      Map<String, String> fields,
      List<String> branchIds,
      bool allBranches) onSubmit;
  @override
  State<ManagementFormDialog> createState() => _ManagementFormDialogState();
}

class _ManagementFormDialogState extends State<ManagementFormDialog> {
  final _form = GlobalKey<FormState>();
  final _fields = <String, TextEditingController>{};
  late Set<String> _branches;
  bool _all = false;
  bool _busy = false;
  String? _error;
  String? _fingerprint;
  bool _removedInactive = false;
  String _operationId = const Uuid().v4();
  @override
  void initState() {
    super.initState();
    final existingIds = widget.existing?.branchIds.toSet() ?? <String>{};
    final activeIds = widget.branches.map((branch) => branch.id).toSet();
    _branches = existingIds.intersection(activeIds);
    _removedInactive = existingIds.difference(activeIds).isNotEmpty;
    _all = widget.existing?.allBranches ?? false;
    for (final key in ['name', 'code', 'address', 'email']) {
      _fields[key] = TextEditingController();
    }
  }

  @override
  void dispose() {
    for (final field in _fields.values) {
      field.dispose();
    }
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy || !_form.currentState!.validate()) return;
    if (widget.action != ManagementAction.branch &&
        !_all &&
        _branches.isEmpty) {
      setState(() => _error = 'Choose at least one branch');
      return;
    }
    final values =
        _fields.map((key, value) => MapEntry(key, value.text.trim()));
    final ids = _all ? <String>[] : (_branches.toList()..sort());
    final fingerprint = jsonEncode([values, ids, _all]);
    if (_fingerprint != null && _fingerprint != fingerprint) {
      _operationId = const Uuid().v4();
    }
    _fingerprint = fingerprint;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final pin = await widget.onSubmit(_operationId, values, ids, _all);
      if (mounted) Navigator.of(context).pop(pin);
    } catch (error) {
      if (mounted) setState(() => _error = operationErrorMessage(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _field(String key, String label, {bool email = false}) => Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: _fields[key],
        enabled: !_busy,
        textInputAction: TextInputAction.next,
        keyboardType: email ? TextInputType.emailAddress : TextInputType.text,
        decoration: InputDecoration(labelText: label),
        validator: (v) => v == null || v.trim().isEmpty
            ? 'Required'
            : email && !RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(v.trim())
                ? 'Enter a valid email'
                : null,
      ));
  @override
  Widget build(BuildContext context) {
    final action = widget.action;
    final scope = action == ManagementAction.invitation ||
        action == ManagementAction.access;
    return PopScope(
        canPop: !_busy,
        child: SariSupplyFormSurface(
          title: switch (action) {
            ManagementAction.branch => 'Add branch',
            ManagementAction.cashier => 'Add cashier',
            ManagementAction.invitation => 'Invite manager',
            ManagementAction.access => 'Edit branch access'
          },
          actions: [
            TextButton(
                onPressed: _busy ? null : () => Navigator.pop(context),
                child: const Text('Cancel')),
            FilledButton(
                onPressed: _busy ? null : _submit,
                child: Text(_busy
                    ? 'Saving…'
                    : switch (action) {
                        ManagementAction.branch => 'Add branch',
                        ManagementAction.cashier => 'Add cashier',
                        ManagementAction.invitation => 'Send invitation',
                        ManagementAction.access => 'Save access',
                      }))
          ],
          child: Form(
              key: _form,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(bottom: 20),
                    child: Text(switch (action) {
                      ManagementAction.branch =>
                        'Set up a store location for branch assignments and POS device activation.',
                      ManagementAction.cashier =>
                        'Choose where this cashier can work. A temporary PIN will be shown after creation.',
                      ManagementAction.invitation =>
                        'The manager will accept this invitation with the same Google account. Choose their branch access below.',
                      ManagementAction.access =>
                        'Choose the branches this manager can access.',
                    }),
                  ),
                  if (action == ManagementAction.branch ||
                      action == ManagementAction.cashier) ...[
                    _field(
                        'name',
                        action == ManagementAction.branch
                            ? 'Branch name'
                            : 'Cashier name'),
                    _field(
                        'code',
                        action == ManagementAction.branch
                            ? 'Branch code'
                            : 'Employee code'),
                  ],
                  if (action == ManagementAction.branch)
                    _field('address', 'Address'),
                  if (action == ManagementAction.invitation)
                    _field('email', 'Google account email', email: true),
                  if (_removedInactive)
                    const Padding(
                        padding: EdgeInsets.only(bottom: 12),
                        child: Text(
                            'Inactive branch assignments will be removed.')),
                  if (scope)
                    SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('All branches'),
                        subtitle: const Text('Grant access across this store'),
                        value: _all,
                        onChanged:
                            _busy ? null : (v) => setState(() => _all = v)),
                  if (action != ManagementAction.branch && !_all) ...[
                    Text('Branch access',
                        style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 4),
                    Text('${_branches.length} selected · Choose at least one'),
                    if (widget.branches.isEmpty)
                      const Text('Add an active branch first'),
                    for (final branch in widget.branches)
                      CheckboxListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(branch.name),
                          subtitle: Text(branch.code),
                          controlAffinity: ListTileControlAffinity.leading,
                          value: _branches.contains(branch.id),
                          onChanged: _busy
                              ? null
                              : (v) => setState(() {
                                    v == true
                                        ? _branches.add(branch.id)
                                        : _branches.remove(branch.id);
                                  })),
                  ],
                  if (_error != null)
                    Text(_error!,
                        style: TextStyle(color: SariSupplyColors.error)),
                ],
              )),
        ));
  }
}
