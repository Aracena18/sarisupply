import 'package:flutter/material.dart';
import 'package:sarisupply_auth/sarisupply_auth.dart';
import 'package:sarisupply_models/sarisupply_models.dart';
import 'package:uuid/uuid.dart';

class MerchantReviewDetailScreen extends StatefulWidget {
  const MerchantReviewDetailScreen({
    super.key,
    required this.application,
    required this.reviews,
  });

  final MerchantApplication application;
  final AdminReviewRepository reviews;

  @override
  State<MerchantReviewDetailScreen> createState() =>
      _MerchantReviewDetailScreenState();
}

class _MerchantReviewDetailScreenState
    extends State<MerchantReviewDetailScreen> {
  final _notes = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _notes.dispose();
    super.dispose();
  }

  Future<void> _review(String decision) async {
    if (_busy) return;
    final notes = _notes.text.trim();
    if (decision == 'reject' && notes.isEmpty) {
      setState(() => _error = 'Review notes are required');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.reviews.review(
        applicationId: widget.application.id,
        decision: decision,
        operationId: const Uuid().v4(),
        reviewNotes: decision == 'reject' ? notes : null,
      );
      if (mounted) Navigator.of(context).pop();
    } catch (error) {
      if (mounted) setState(() => _error = 'Review failed: $error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final application = widget.application;
    return Scaffold(
      appBar: AppBar(title: const Text('Review application')),
      body: Center(
          child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 600),
        child: ListView(padding: const EdgeInsets.all(24), children: [
          Text(
              application.businessProfile['name']?.toString() ??
                  'Unnamed business',
              style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 16),
          Text('Applicant UID: ${application.applicantUid}'),
          Text('Branch: ${application.firstBranchDraft['name'] ?? ''}'),
          Text('Code: ${application.firstBranchDraft['code'] ?? ''}'),
          Text('Address: ${application.firstBranchDraft['address'] ?? ''}'),
          const SizedBox(height: 24),
          TextField(
              controller: _notes,
              maxLines: 3,
              decoration: const InputDecoration(
                  labelText: 'Review notes (required to reject)',
                  border: OutlineInputBorder())),
          if (_error != null)
            Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(_error!,
                    style:
                        TextStyle(color: Theme.of(context).colorScheme.error))),
          const SizedBox(height: 16),
          Wrap(spacing: 12, children: [
            FilledButton(
                onPressed: _busy ? null : () => _review('approve'),
                child: const Text('Approve')),
            OutlinedButton(
                onPressed: _busy ? null : () => _review('reject'),
                child: const Text('Reject')),
          ]),
        ]),
      )),
    );
  }
}
