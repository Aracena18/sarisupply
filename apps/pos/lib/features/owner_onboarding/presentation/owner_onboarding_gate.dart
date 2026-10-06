import 'package:flutter/material.dart';
import 'package:sarisupply_auth/sarisupply_auth.dart';
import 'package:sarisupply_design_system/sarisupply_design_system.dart';
import 'package:sarisupply_models/sarisupply_models.dart';
import 'package:sarisupply_firebase/sarisupply_firebase.dart';
import 'merchant_application_screen.dart';

class OwnerOnboardingGate extends StatefulWidget {
  const OwnerOnboardingGate(
      {super.key,
      required this.applications,
      required this.memberships,
      required this.onChanged,
      required this.onSignOut,
      this.existing});
  final MerchantApplicationRepository applications;
  final MembershipRepository memberships;
  final MerchantApplication? existing;
  final VoidCallback onChanged, onSignOut;
  @override
  State<OwnerOnboardingGate> createState() => _OwnerOnboardingGateState();
}

class _OwnerOnboardingGateState extends State<OwnerOnboardingGate> {
  late Future<List<ManagerInvitation>> _invitations;
  String? _accepting, _error;
  @override
  void initState() {
    super.initState();
    _refresh();
  }

  void _refresh() {
    _invitations = widget.memberships.listMyInvitations();
  }

  Future<void> _accept(ManagerInvitation invite) async {
    if (_accepting != null) return;
    setState(() {
      _accepting = invite.inviteId;
      _error = null;
    });
    try {
      await widget.memberships
          .acceptManagerInvitation(invite.merchantId, invite.inviteId);
      if (mounted) widget.onChanged();
    } catch (error) {
      if (mounted) setState(() => _error = operationErrorMessage(error));
    } finally {
      if (mounted) setState(() => _accepting = null);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar:
            sariSupplyTaskAppBar(context, title: 'Set up your store', actions: [
          IconButton(
              tooltip: 'Sign out',
              onPressed: _accepting != null ? null : widget.onSignOut,
              icon: const Icon(Icons.logout)),
        ]),
        body: SariSupplyPageContent(
            maxWidth: 600,
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  FutureBuilder<List<ManagerInvitation>>(
                      future: _invitations,
                      builder: (context, snapshot) {
                        if (snapshot.hasError) {
                          return Padding(
                              padding: const EdgeInsets.only(bottom: 24),
                              child: SariSupplyStatus(
                                  message:
                                      'Unable to load manager invitations.',
                                  actions: [
                                    TextButton(
                                        onPressed: _accepting != null
                                            ? null
                                            : () => setState(_refresh),
                                        child: const Text('Retry invitations'))
                                  ]));
                        }
                        if (!snapshot.hasData) {
                          return const Padding(
                              padding: EdgeInsets.only(bottom: 24),
                              child: LinearProgressIndicator());
                        }
                        if (snapshot.data!.isEmpty) {
                          return const SizedBox.shrink();
                        }
                        return Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Text('Manager invitations',
                                  style:
                                      Theme.of(context).textTheme.titleMedium),
                              const SizedBox(height: 12),
                              for (final invite in snapshot.data!)
                                Card(
                                    child: Padding(
                                        padding: const EdgeInsets.all(16),
                                        child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.stretch,
                                            children: [
                                              Text(
                                                  'Store reference: ${invite.merchantId}'),
                                              const SizedBox(height: 8),
                                              Text(
                                                  'Expires ${MaterialLocalizations.of(context).formatMediumDate(invite.expiresAt.toLocal())} at ${MaterialLocalizations.of(context).formatTimeOfDay(TimeOfDay.fromDateTime(invite.expiresAt.toLocal()))}',
                                                  style: Theme.of(context)
                                                      .textTheme
                                                      .bodySmall),
                                              const SizedBox(height: 12),
                                              OutlinedButton(
                                                  onPressed: _accepting != null
                                                      ? null
                                                      : () => _accept(invite),
                                                  child: Text(_accepting ==
                                                          invite.inviteId
                                                      ? 'Accepting…'
                                                      : 'Accept invitation')),
                                            ]))),
                              if (_error != null)
                                SariSupplyStatus(message: _error!, error: true),
                              const SizedBox(height: 24),
                              const Divider(),
                              const SizedBox(height: 16),
                            ]);
                      }),
                  AbsorbPointer(
                      absorbing: _accepting != null,
                      child: MerchantApplicationScreen(
                          applications: widget.applications,
                          existing: widget.existing,
                          onSubmitted: widget.onChanged)),
                ])),
      );
}
