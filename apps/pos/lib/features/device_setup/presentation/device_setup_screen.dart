import 'package:flutter/material.dart';
import 'package:sarisupply_design_system/sarisupply_design_system.dart';
import 'package:sarisupply_auth/sarisupply_auth.dart';
import 'package:sarisupply_models/sarisupply_models.dart';
import 'package:uuid/uuid.dart';
import 'package:sarisupply_firebase/sarisupply_firebase.dart';

class DeviceSetupScreen extends StatefulWidget {
  const DeviceSetupScreen({
    super.key,
    required this.memberships,
    required this.membershipRepository,
    required this.devices,
    required this.onActivated,
    required this.onSignOut,
    this.onManage,
  });

  final List<MerchantMembership> memberships;
  final MembershipRepository membershipRepository;
  final DeviceRepository devices;
  final VoidCallback onActivated;
  final VoidCallback onSignOut;
  final VoidCallback? onManage;

  @override
  State<DeviceSetupScreen> createState() => _DeviceSetupScreenState();
}

class _DeviceSetupScreenState extends State<DeviceSetupScreen> {
  final _name = TextEditingController(text: 'Counter device');
  MerchantMembership? _membership;
  Future<List<Branch>>? _branches;
  String? _branchId;
  bool _busy = false;
  String? _error;
  String? _attempt;
  String _operationId = const Uuid().v4();

  @override
  void initState() {
    super.initState();
    if (widget.memberships.isNotEmpty) _select(widget.memberships.first);
  }

  void _select(MerchantMembership membership) {
    _membership = membership;
    _branchId = null;
    _branches = widget.membershipRepository.listAccessibleBranches(membership);
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _activate() async {
    if (_busy ||
        _membership == null ||
        _branchId == null ||
        _name.text.trim().isEmpty) {
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    final attempt =
        '${_membership!.merchantId}:$_branchId:${_name.text.trim()}';
    if (_attempt != null && _attempt != attempt) {
      _operationId = const Uuid().v4();
    }
    _attempt = attempt;
    try {
      await widget.devices.activate(
        merchantId: _membership!.merchantId,
        branchId: _branchId!,
        displayName: _name.text.trim(),
        platform: 'android',
        appVersion: '0.1.0',
        operationId: _operationId,
      );
      if (mounted) widget.onActivated();
    } catch (error) {
      if (mounted) setState(() => _error = operationErrorMessage(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar:
            sariSupplyTaskAppBar(context, title: 'Activate this POS', actions: [
          IconButton(
              tooltip: 'Sign out',
              onPressed: _busy ? null : widget.onSignOut,
              icon: const Icon(Icons.logout)),
        ]),
        body: Center(
            child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: ListView(
              padding: EdgeInsets.all(
                  MediaQuery.sizeOf(context).width < 600 ? 16 : 24),
              children: [
                if (widget.memberships.isEmpty)
                  const Text(
                      'No authorized merchant is available for this account.')
                else ...[
                  DropdownButtonFormField<String>(
                    isExpanded: true,
                    initialValue: _membership?.merchantId,
                    decoration: const InputDecoration(labelText: 'Store'),
                    items: widget.memberships
                        .map((membership) => DropdownMenuItem(
                              value: membership.merchantId,
                              child: Text(membership.merchantName),
                            ))
                        .toList(),
                    onChanged: _busy
                        ? null
                        : (value) {
                            final selected = widget.memberships.firstWhere(
                                (membership) => membership.merchantId == value);
                            setState(() => _select(selected));
                          },
                  ),
                  const SizedBox(height: 16),
                  FutureBuilder<List<Branch>>(
                    future: _branches,
                    builder: (context, snapshot) {
                      if (snapshot.hasError) {
                        return Column(children: [
                          const Text('Unable to load branches'),
                          TextButton(
                              onPressed: _busy
                                  ? null
                                  : () => setState(() => _select(_membership!)),
                              child: const Text('Retry'))
                        ]);
                      }
                      if (!snapshot.hasData) {
                        return const LinearProgressIndicator();
                      }
                      final branches = snapshot.data!;
                      if (branches.isEmpty) {
                        return const Text('No active authorized branch');
                      }
                      return DropdownButtonFormField<String>(
                        isExpanded: true,
                        key: ValueKey(_membership!.merchantId),
                        initialValue: _branchId,
                        decoration: const InputDecoration(labelText: 'Branch'),
                        items: branches
                            .map((branch) => DropdownMenuItem(
                                  value: branch.id,
                                  child: Text(branch.name),
                                ))
                            .toList(),
                        onChanged: _busy
                            ? null
                            : (value) => setState(() => _branchId = value),
                      );
                    },
                  ),
                  const SizedBox(height: 16),
                  TextField(
                      controller: _name,
                      enabled: !_busy,
                      onChanged: (_) => setState(() {}),
                      decoration:
                          const InputDecoration(labelText: 'Device name')),
                  if (_error != null)
                    Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: Text(_error!,
                            style: TextStyle(
                                color: Theme.of(context).colorScheme.error))),
                  const SizedBox(height: 20),
                  FilledButton(
                      onPressed: _busy ||
                              _branchId == null ||
                              _name.text.trim().isEmpty
                          ? null
                          : _activate,
                      child: Text(_busy ? 'Activating…' : 'Activate device')),
                ],
                if (widget.onManage != null)
                  Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton(
                          onPressed: _busy ? null : widget.onManage,
                          child: const Text('Manage store'))),
              ]),
        )),
      );
}
