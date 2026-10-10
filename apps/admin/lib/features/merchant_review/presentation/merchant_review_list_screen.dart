import 'package:flutter/material.dart';
import 'package:sarisupply_auth/sarisupply_auth.dart';
import 'package:sarisupply_design_system/sarisupply_design_system.dart';
import 'package:sarisupply_firebase/sarisupply_firebase.dart';
import 'package:sarisupply_models/sarisupply_models.dart';

import 'merchant_review_detail_screen.dart';

class MerchantReviewListScreen extends StatefulWidget {
  const MerchantReviewListScreen({
    super.key,
    required this.reviews,
    required this.onSignOut,
    this.procurement,
    this.onSwitchContext,
    this.embedded = false,
  });

  final AdminReviewRepository reviews;
  final Future<void> Function() onSignOut;
  final ProcurementGateway? procurement;
  final VoidCallback? onSwitchContext;
  final bool embedded;

  @override
  State<MerchantReviewListScreen> createState() =>
      _MerchantReviewListScreenState();
}

class _MerchantReviewListScreenState extends State<MerchantReviewListScreen> {
  late Stream<List<MerchantApplication>> _stream;
  String _search = '';
  bool _signingOut = false;
  @override
  void initState() {
    super.initState();
    _stream = widget.reviews.watchPending();
  }

  @override
  void didUpdateWidget(covariant MerchantReviewListScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.reviews != widget.reviews) {
      _stream = widget.reviews.watchPending();
    }
  }

  Future<void> _signOut() async {
    if (_signingOut) return;
    setState(() => _signingOut = true);
    try {
      await widget.onSignOut();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(operationErrorMessage(error))));
      }
    } finally {
      if (mounted) setState(() => _signingOut = false);
    }
  }

  @override
  Widget build(BuildContext context) => _applications(context);

  Widget _applications(BuildContext context) => Scaffold(
        appBar: widget.embedded
            ? null
            : sariSupplyTaskAppBar(context,
                title: 'Pending applications',
                actions: [
                    if (widget.onSwitchContext != null)
                      IconButton(
                          onPressed: widget.onSwitchContext,
                          tooltip: 'Switch workspace',
                          icon: const Icon(Icons.swap_horiz)),
                    IconButton(
                        onPressed: _signingOut ? null : _signOut,
                        tooltip: _signingOut ? 'Signing out…' : 'Sign out',
                        icon: const Icon(Icons.logout)),
                  ]),
        body: SafeArea(
            child: Center(
                child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1000),
                    child: Column(children: [
                      if (widget.embedded)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Text(
                                'Store applications',
                                style: Theme.of(context).textTheme.titleLarge,
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'Review requests from stores that want to join SariSupply.',
                                style: Theme.of(context).textTheme.bodyMedium,
                              ),
                            ],
                          ),
                        ),
                      Padding(
                          padding: EdgeInsets.all(
                              MediaQuery.sizeOf(context).width < 600 ? 16 : 24),
                          child: Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  decoration: const InputDecoration(
                                      labelText: 'Search applications',
                                      prefixIcon: Icon(Icons.search)),
                                  onChanged: (value) => setState(() =>
                                      _search = value.trim().toLowerCase()),
                                ),
                              ),
                              const SizedBox(width: 8),
                              IconButton(
                                tooltip: 'Refresh applications',
                                onPressed: () => setState(() =>
                                    _stream = widget.reviews.watchPending()),
                                icon: const Icon(Icons.refresh),
                              ),
                            ],
                          )),
                      Expanded(
                          child: StreamBuilder<List<MerchantApplication>>(
                        stream: _stream,
                        builder: (context, snapshot) {
                          if (snapshot.hasError) {
                            return Center(
                                child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                  const Text('Unable to load applications'),
                                  TextButton(
                                      onPressed: () => setState(() => _stream =
                                          widget.reviews.watchPending()),
                                      child: const Text('Retry')),
                                ]));
                          }
                          if (!snapshot.hasData) {
                            return const Center(
                                child: CircularProgressIndicator());
                          }
                          final applications = snapshot.data!
                              .where((a) =>
                                  '${a.businessProfile['name']} ${a.firstBranchDraft['name']} ${a.firstBranchDraft['address']}'
                                      .toLowerCase()
                                      .contains(_search))
                              .toList();
                          if (applications.isEmpty) {
                            return Center(
                                child: Padding(
                              padding: const EdgeInsets.all(24),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    _search.isEmpty
                                        ? Icons.inbox_outlined
                                        : Icons.search_off,
                                    size: 40,
                                    color: SariSupplyColors.ink600,
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    _search.isEmpty
                                        ? 'No applications waiting'
                                        : 'No matching applications',
                                    textAlign: TextAlign.center,
                                    style:
                                        Theme.of(context).textTheme.titleMedium,
                                  ),
                                  if (_search.isEmpty) ...[
                                    const SizedBox(height: 6),
                                    const Text(
                                      'New store requests will appear here.',
                                      textAlign: TextAlign.center,
                                    ),
                                  ],
                                ],
                              ),
                            ));
                          }
                          return ListView.separated(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            separatorBuilder: (_, index) =>
                                const Divider(height: 1),
                            itemCount: applications.length,
                            itemBuilder: (context, index) {
                              final application = applications[index];
                              final submittedAt =
                                  application.submittedAt?.toLocal();
                              final submittedLabel = submittedAt == null
                                  ? 'Submission date unavailable'
                                  : 'Submitted ${MaterialLocalizations.of(context).formatMediumDate(submittedAt)}';
                              return ListTile(
                                tileColor: SariSupplyColors.card,
                                contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 8),
                                leading: const SariSupplyIcon(
                                    SariSupplyIconName.branches,
                                    color: SariSupplyColors.ink600),
                                title: Text(application.businessProfile['name']
                                        ?.toString() ??
                                    'Unnamed business'),
                                subtitle: Text(
                                    '${application.firstBranchDraft['name'] ?? ''} · ${application.firstBranchDraft['address'] ?? ''}\n$submittedLabel'),
                                isThreeLine: true,
                                trailing: const Icon(Icons.chevron_right),
                                onTap: () async {
                                  final messenger =
                                      ScaffoldMessenger.of(context);
                                  final decision = await Navigator.of(context)
                                      .push<String>(MaterialPageRoute<String>(
                                    builder: (_) => MerchantReviewDetailScreen(
                                      application: application,
                                      reviews: widget.reviews,
                                    ),
                                  ));
                                  if (!mounted) return;
                                  setState(() =>
                                      _stream = widget.reviews.watchPending());
                                  if (decision == 'approve' ||
                                      decision == 'reject') {
                                    messenger.showSnackBar(
                                      SnackBar(
                                        content: Text(decision == 'approve'
                                            ? 'Store application approved'
                                            : 'Application rejected'),
                                      ),
                                    );
                                  }
                                },
                              );
                            },
                          );
                        },
                      )),
                    ])))),
      );
}
