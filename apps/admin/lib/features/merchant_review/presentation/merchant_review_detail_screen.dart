import 'package:flutter/material.dart';
import 'package:sarisupply_design_system/sarisupply_design_system.dart';
import 'package:sarisupply_auth/sarisupply_auth.dart';
import 'package:sarisupply_models/sarisupply_models.dart';
import 'package:uuid/uuid.dart';
import 'package:sarisupply_firebase/sarisupply_firebase.dart';

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
  bool _submitting = false;
  String? _error;
  String? _attempt;
  String _operationId = const Uuid().v4();

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
    final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
                scrollable: true,
                title: Text(decision == 'approve'
                    ? 'Approve this store?'
                    : 'Reject this application?'),
                content: Text(decision == 'approve'
                    ? '${widget.application.businessProfile['name']} will receive a store, an Owner membership, and its first branch.'
                    : 'The applicant can update and resubmit. They will see this reason:\n\n$notes'),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('Cancel')),
                  FilledButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: Text(decision == 'approve'
                          ? 'Approve store'
                          : 'Reject application')),
                ]));
    if (!mounted) return;
    if (confirmed != true) {
      setState(() => _busy = false);
      return;
    }
    setState(() => _submitting = true);
    final attempt = '$decision:$notes';
    if (_attempt != null && _attempt != attempt) {
      _operationId = const Uuid().v4();
    }
    _attempt = attempt;
    try {
      await widget.reviews.review(
        applicationId: widget.application.id,
        decision: decision,
        operationId: _operationId,
        reviewNotes: decision == 'reject' ? notes : null,
      );
      if (mounted) Navigator.of(context).pop();
    } catch (error) {
      if (mounted) setState(() => _error = operationErrorMessage(error));
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
          _submitting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final application = widget.application;
    return PopScope(
        canPop: !_busy,
        child: Scaffold(
          appBar: sariSupplyTaskAppBar(context, title: 'Review application'),
          body: SariSupplyPageContent(
              maxWidth: 600,
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                        application.businessProfile['name']?.toString() ??
                            'Unnamed business',
                        style: Theme.of(context).textTheme.titleLarge),
                    const SizedBox(height: 16),
                    Card(
                        child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Text('Branch',
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall),
                                  Text(application.firstBranchDraft['name']
                                          ?.toString() ??
                                      ''),
                                  const SizedBox(height: 16),
                                  Text('Branch code',
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall),
                                  Text(application.firstBranchDraft['code']
                                          ?.toString() ??
                                      ''),
                                  const SizedBox(height: 16),
                                  Text('Location',
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall),
                                  Text(application.firstBranchDraft['address']
                                          ?.toString() ??
                                      ''),
                                ]))),
                    const SizedBox(height: 24),
                    TextField(
                        controller: _notes,
                        enabled: !_busy,
                        minLines: 2,
                        maxLines: 5,
                        decoration: const InputDecoration(
                            labelText: 'Rejection reason',
                            helperText:
                                'Required to reject; shared with the applicant.',
                            helperMaxLines: 3)),
                    if (_error != null) ...[
                      const SizedBox(height: 12),
                      SariSupplyStatus(message: _error!, error: true)
                    ],
                    const SizedBox(height: 24),
                    Wrap(spacing: 12, runSpacing: 12, children: [
                      FilledButton(
                          onPressed: _busy ? null : () => _review('approve'),
                          child: const Text('Approve')),
                      OutlinedButton(
                          onPressed: _busy ? null : () => _review('reject'),
                          child: const Text('Reject')),
                    ]),
                    if (_submitting)
                      const Padding(
                          padding: EdgeInsets.only(top: 16),
                          child: LinearProgressIndicator()),
                  ])),
        ));
  }
}
