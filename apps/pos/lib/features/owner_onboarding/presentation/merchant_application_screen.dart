import 'package:flutter/material.dart';
import 'package:sarisupply_auth/sarisupply_auth.dart';
import 'package:sarisupply_models/sarisupply_models.dart';

class MerchantApplicationScreen extends StatefulWidget {
  const MerchantApplicationScreen({
    super.key,
    required this.applications,
    required this.onSubmitted,
    this.existing,
  });

  final MerchantApplicationRepository applications;
  final MerchantApplication? existing;
  final VoidCallback onSubmitted;

  @override
  State<MerchantApplicationScreen> createState() =>
      _MerchantApplicationScreenState();
}

class _MerchantApplicationScreenState extends State<MerchantApplicationScreen> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _business;
  late final TextEditingController _branch;
  late final TextEditingController _code;
  late final TextEditingController _address;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final application = widget.existing;
    _business = TextEditingController(
        text: application?.businessProfile['name']?.toString());
    _branch = TextEditingController(
        text: application?.firstBranchDraft['name']?.toString());
    _code = TextEditingController(
        text: application?.firstBranchDraft['code']?.toString());
    _address = TextEditingController(
        text: application?.firstBranchDraft['address']?.toString());
  }

  @override
  void dispose() {
    _business.dispose();
    _branch.dispose();
    _code.dispose();
    _address.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy || !_form.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final applicationId = await widget.applications.saveDraft(
        applicationId: widget.existing?.id,
        businessProfile: {'name': _business.text.trim()},
        firstBranchDraft: {
          'name': _branch.text.trim(),
          'code': _code.text.trim().toUpperCase(),
          'address': _address.text.trim(),
        },
      );
      await widget.applications.submit(applicationId);
      widget.onSubmitted();
    } catch (error) {
      if (mounted) setState(() => _error = 'Unable to submit: $error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    String? required(String? value) =>
        value == null || value.trim().isEmpty ? 'Required' : null;
    return Form(
      key: _form,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        if (widget.existing?.status == MerchantApplicationStatus.rejected) ...[
          Text(
              'Please update your application: ${widget.existing?.reviewNotes ?? ''}'),
          const SizedBox(height: 12),
        ],
        TextFormField(
            controller: _business,
            validator: required,
            decoration: const InputDecoration(labelText: 'Business name')),
        TextFormField(
            controller: _branch,
            validator: required,
            decoration: const InputDecoration(labelText: 'First branch name')),
        TextFormField(
            controller: _code,
            validator: required,
            decoration: const InputDecoration(labelText: 'Branch code')),
        TextFormField(
            controller: _address,
            validator: required,
            decoration: const InputDecoration(labelText: 'Branch address')),
        if (_error != null)
          Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(_error!,
                  style:
                      TextStyle(color: Theme.of(context).colorScheme.error))),
        const SizedBox(height: 20),
        FilledButton(
            onPressed: _busy ? null : _submit,
            child: Text(_busy ? 'Submitting…' : 'Submit application')),
      ]),
    );
  }
}
