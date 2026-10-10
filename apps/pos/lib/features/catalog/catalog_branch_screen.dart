import 'package:flutter/material.dart';
import 'package:sarisupply_auth/sarisupply_auth.dart';
import 'package:sarisupply_design_system/sarisupply_design_system.dart';
import 'package:sarisupply_firebase/sarisupply_firebase.dart';
import 'package:sarisupply_models/sarisupply_models.dart';
import 'catalog_screen.dart';
import 'inventory_database.dart';

class CatalogBranchScreen extends StatefulWidget {
  const CatalogBranchScreen(
      {super.key,
      required this.memberships,
      required this.repository,
      required this.gateway});
  final List<MerchantMembership> memberships;
  final MembershipRepository repository;
  final InventoryGateway gateway;
  @override
  State<CatalogBranchScreen> createState() => _CatalogBranchScreenState();
}

class _CatalogBranchScreenState extends State<CatalogBranchScreen> {
  MerchantMembership? _member;
  List<Branch> _branches = [];
  Branch? _branch;
  bool _busy = false;
  String? _error;
  @override
  void initState() {
    super.initState();
    _member = widget.memberships.firstOrNull;
    if (_member != null) _load();
  }

  Future<void> _load() async {
    setState(() {
      _busy = true;
      _error = null;
      _branches = [];
      _branch = null;
    });
    try {
      final branches = await widget.repository.listAccessibleBranches(_member!);
      if (mounted) {
        setState(() => _branches =
            branches.where((b) => b.status == BranchStatus.active).toList());
      }
    } catch (error) {
      if (mounted) setState(() => _error = operationErrorMessage(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _open() async {
    if (_branch == null || _member == null) return;
    final member = _member!;
    final branch = _branch!;
    await Navigator.of(context).push(MaterialPageRoute<void>(
        builder: (_) => CatalogScreen(
            branchName: branch.name,
            openStore: () => openInventory(member.merchantId, branch.id),
            gateway: widget.gateway,
            canUpload: true,
            authorizationRevision: '${member.role.name}:'
                '${member.updatedAt.microsecondsSinceEpoch}:'
                '${member.allBranches}:${member.branchIds.join(',')}',
            canEdit: member.role == MerchantRole.owner)));
  }

  @override
  Widget build(BuildContext context) {
    if (!_busy &&
        _error == null &&
        widget.memberships.length == 1 &&
        _branches.length == 1) {
      final member = _member!;
      final branch = _branches.single;
      return CatalogScreen(
          branchName: branch.name,
          openStore: () => openInventory(member.merchantId, branch.id),
          gateway: widget.gateway,
          canUpload: true,
          authorizationRevision: '${member.role.name}:'
              '${member.updatedAt.microsecondsSinceEpoch}:'
              '${member.allBranches}:${member.branchIds.join(',')}',
          canEdit: member.role == MerchantRole.owner);
    }
    return Scaffold(
        appBar: sariSupplyTaskAppBar(context, title: 'Select stock location'),
        body: SariSupplyPageContent(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
              if (_member == null)
                const Text('No active store access')
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
                              _member = widget.memberships
                                  .firstWhere((m) => m.merchantId == id);
                              _load();
                            }),
                if (_busy) const LinearProgressIndicator(),
                if (_error != null) ...[
                  Text(_error!),
                  TextButton(
                      onPressed: _busy ? null : _load,
                      child: const Text('Retry'))
                ],
                if (!_busy && _error == null && _branches.isEmpty)
                  const Text('Create an active branch to manage stock.'),
                if (_branches.isNotEmpty) ...[
                  DropdownButtonFormField<String>(
                      isExpanded: true,
                      key: ValueKey(_member!.merchantId),
                      initialValue: _branch?.id,
                      decoration: const InputDecoration(labelText: 'Branch'),
                      items: _branches
                          .map((b) => DropdownMenuItem(
                              value: b.id, child: Text(b.name)))
                          .toList(),
                      onChanged: _busy
                          ? null
                          : (id) => setState(() => _branch =
                              _branches.firstWhere((b) => b.id == id))),
                  const SizedBox(height: 16),
                  FilledButton(
                      onPressed: _branch == null ? null : _open,
                      child: const Text('Open catalog and stock')),
                ],
              ]
            ])));
  }
}
