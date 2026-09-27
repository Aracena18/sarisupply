import 'package:flutter/material.dart';
import 'package:sarisupply_auth/sarisupply_auth.dart';
import 'package:sarisupply_models/sarisupply_models.dart';

import 'merchant_application_screen.dart';

class OwnerOnboardingGate extends StatefulWidget {
  const OwnerOnboardingGate({
    super.key,
    required this.applications,
    required this.memberships,
    required this.onChanged,
    required this.onSignOut,
    this.existing,
  });

  final MerchantApplicationRepository applications;
  final MembershipRepository memberships;
  final MerchantApplication? existing;
  final VoidCallback onChanged;
  final VoidCallback onSignOut;

  @override
  State<OwnerOnboardingGate> createState() => _OwnerOnboardingGateState();
}

class _OwnerOnboardingGateState extends State<OwnerOnboardingGate> {
  late Future<List<ManagerInvitation>> _invitations;

  @override
  void initState() {
    super.initState();
    _invitations = widget.memberships.listMyInvitations();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Set up your store'), actions: [
          TextButton(
              onPressed: widget.onSignOut, child: const Text('Sign out')),
        ]),
        body: Center(
            child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: ListView(padding: const EdgeInsets.all(24), children: [
            Text('Apply to use SariSupply',
                style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 16),
            MerchantApplicationScreen(
              applications: widget.applications,
              existing: widget.existing,
              onSubmitted: widget.onChanged,
            ),
            const SizedBox(height: 32),
            Text('Manager invitations',
                style: Theme.of(context).textTheme.titleLarge),
            FutureBuilder<List<ManagerInvitation>>(
              future: _invitations,
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return const Text('Unable to load invitations');
                }
                if (!snapshot.hasData) {
                  return const LinearProgressIndicator();
                }
                if (snapshot.data!.isEmpty) {
                  return const Text('No invitations for this account');
                }
                return Column(
                    children: snapshot.data!
                        .map((invite) => ListTile(
                              title: Text('Merchant ${invite.merchantId}'),
                              subtitle:
                                  Text('Expires ${invite.expiresAt.toLocal()}'),
                              trailing: TextButton(
                                  onPressed: () async {
                                    try {
                                      await widget.memberships
                                          .acceptManagerInvitation(
                                              invite.merchantId,
                                              invite.inviteId);
                                      widget.onChanged();
                                    } catch (error) {
                                      if (context.mounted) {
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(SnackBar(
                                                content: Text(
                                                    'Unable to accept: $error')));
                                      }
                                    }
                                  },
                                  child: const Text('Accept')),
                            ))
                        .toList());
              },
            ),
          ]),
        )),
      );
}
