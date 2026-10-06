import 'package:flutter/material.dart';
import 'package:sarisupply_auth/sarisupply_auth.dart';
import 'package:sarisupply_design_system/sarisupply_design_system.dart';
import 'package:sarisupply_firebase/sarisupply_firebase.dart';
import 'package:sarisupply_models/sarisupply_models.dart';

import '../../procurement/presentation/procurement_dashboard_screen.dart';
import '../../reports/presentation/admin_reports_screen.dart';
import 'merchant_review_detail_screen.dart';

class MerchantReviewListScreen extends StatefulWidget {
  const MerchantReviewListScreen({
    super.key,
    required this.reviews,
    required this.onSignOut,
    this.procurement,
  });

  final AdminReviewRepository reviews;
  final Future<void> Function() onSignOut;
  final ProcurementGateway? procurement;

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
  Widget build(BuildContext context) => Scaffold(
        appBar: sariSupplyTaskAppBar(context,
            title: 'Pending applications',
            actions: [
              IconButton(
                  onPressed: () =>
                      Navigator.of(context).push(MaterialPageRoute<void>(
                        builder: (_) => ProcurementDashboardScreen(
                          gateway: widget.procurement,
                        ),
                      )),
                  tooltip: 'Procurement & Warehousing',
                  icon: const Icon(Icons.warehouse_outlined)),
              IconButton(
                  onPressed: () =>
                      Navigator.of(context).push(MaterialPageRoute<void>(
                        builder: (_) => const AdminReportsScreen(),
                      )),
                  tooltip: 'Reports & Analytics',
                  icon: const Icon(Icons.analytics_outlined)),
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
                      const Padding(
                          padding: EdgeInsets.only(top: 16),
                          child: SariSupplyBrand(role: 'Admin')),
                      Padding(
                          padding: EdgeInsets.all(
                              MediaQuery.sizeOf(context).width < 600 ? 16 : 24),
                          child: TextField(
                            decoration: const InputDecoration(
                                labelText: 'Search applications',
                                prefixIcon: Icon(Icons.search)),
                            onChanged: (value) => setState(
                                () => _search = value.trim().toLowerCase()),
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
                                child: Text(_search.isEmpty
                                    ? 'No applications need review'
                                    : 'No matching applications'));
                          }
                          return ListView.builder(
                            itemCount: applications.length,
                            itemBuilder: (context, index) {
                              final application = applications[index];
                              return Card(
                                  margin: const EdgeInsets.symmetric(
                                      horizontal: 16, vertical: 4),
                                  child: ListTile(
                                    title: Text(application
                                            .businessProfile['name']
                                            ?.toString() ??
                                        'Unnamed business'),
                                    subtitle: Text(
                                        '${application.firstBranchDraft['name'] ?? ''} · ${application.firstBranchDraft['address'] ?? ''}'),
                                    trailing: const Icon(Icons.chevron_right),
                                    onTap: () => Navigator.of(context)
                                        .push(MaterialPageRoute<void>(
                                      builder: (_) =>
                                          MerchantReviewDetailScreen(
                                        application: application,
                                        reviews: widget.reviews,
                                      ),
                                    )),
                                  ));
                            },
                          );
                        },
                      )),
                    ])))),
      );
}
