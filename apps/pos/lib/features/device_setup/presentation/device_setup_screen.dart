import 'package:flutter/material.dart';
import 'package:sarisupply_auth/sarisupply_auth.dart';
import 'package:sarisupply_models/sarisupply_models.dart';
import 'package:uuid/uuid.dart';

class DeviceSetupScreen extends StatefulWidget {
  const DeviceSetupScreen({
    super.key,
    required this.memberships,
    required this.membershipRepository,
    required this.devices,
    required this.onActivated,
    required this.onSignOut,
  });

  final List<MerchantMembership> memberships;
  final MembershipRepository membershipRepository;
  final DeviceRepository devices;
  final VoidCallback onActivated;
  final VoidCallback onSignOut;

  @override
  State<DeviceSetupScreen> createState() => _DeviceSetupScreenState();
}

class _DeviceSetupScreenState extends State<DeviceSetupScreen> {
  final _name = TextEditingController(text: 'Counter tablet');
  MerchantMembership? _membership;
  Future<List<Branch>>? _branches;
  String? _branchId;
  bool _busy = false;
  String? _error;

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
    try {
      await widget.devices.activate(
        merchantId: _membership!.merchantId,
        branchId: _branchId!,
        displayName: _name.text.trim(),
        platform: 'android',
        appVersion: '0.1.0',
        operationId: const Uuid().v4(),
      );
      widget.onActivated();
    } catch (error) {
      if (mounted) setState(() => _error = 'Activation failed: $error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Activate this POS'), actions: [
          TextButton(
              onPressed: widget.onSignOut, child: const Text('Sign out')),
        ]),
        body: Center(
            child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: ListView(padding: const EdgeInsets.all(24), children: [
            const Text(
                'Choose an authorized merchant and branch for this tablet.'),
            const SizedBox(height: 16),
            if (widget.memberships.isEmpty)
              const Text(
                  'No authorized merchant is available for this account.')
            else ...[
              DropdownButtonFormField<String>(
                initialValue: _membership?.merchantId,
                decoration: const InputDecoration(labelText: 'Merchant'),
                items: widget.memberships
                    .map((membership) => DropdownMenuItem(
                          value: membership.merchantId,
                          child: Text(membership.merchantId),
                        ))
                    .toList(),
                onChanged: (value) {
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
                    return Text('Unable to load branches: ${snapshot.error}');
                  }
                  if (!snapshot.hasData) {
                    return const LinearProgressIndicator();
                  }
                  final branches = snapshot.data!;
                  if (branches.isEmpty) {
                    return const Text('No active authorized branch');
                  }
                  return DropdownButtonFormField<String>(
                    initialValue: _branchId,
                    decoration: const InputDecoration(labelText: 'Branch'),
                    items: branches
                        .map((branch) => DropdownMenuItem(
                              value: branch.id,
                              child: Text(branch.name),
                            ))
                        .toList(),
                    onChanged: (value) => setState(() => _branchId = value),
                  );
                },
              ),
              const SizedBox(height: 16),
              TextField(
                  controller: _name,
                  decoration: const InputDecoration(labelText: 'Device name')),
              if (_error != null)
                Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Text(_error!,
                        style: TextStyle(
                            color: Theme.of(context).colorScheme.error))),
              const SizedBox(height: 20),
              FilledButton(
                  onPressed: _busy ? null : _activate,
                  child: Text(_busy ? 'Activating…' : 'Activate device')),
            ],
          ]),
        )),
      );
}
