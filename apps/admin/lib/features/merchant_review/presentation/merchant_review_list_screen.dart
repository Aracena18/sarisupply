import 'package:flutter/material.dart';
import 'package:sarisupply_auth/sarisupply_auth.dart';
import 'package:sarisupply_models/sarisupply_models.dart';

import 'merchant_review_detail_screen.dart';

class MerchantReviewListScreen extends StatelessWidget {
  const MerchantReviewListScreen({
    super.key,
    required this.reviews,
    required this.onSignOut,
  });

  final AdminReviewRepository reviews;
  final Future<void> Function() onSignOut;

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Pending applications'), actions: [
          TextButton(onPressed: onSignOut, child: const Text('Sign out')),
        ]),
        body: StreamBuilder<List<MerchantApplication>>(
          stream: reviews.watchPending(),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return Center(
                  child:
                      Text('Unable to load applications: ${snapshot.error}'));
            }
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            final applications = snapshot.data!;
            if (applications.isEmpty) {
              return const Center(child: Text('No applications need review'));
            }
            return ListView.builder(
              itemCount: applications.length,
              itemBuilder: (context, index) {
                final application = applications[index];
                return ListTile(
                  title: Text(application.businessProfile['name']?.toString() ??
                      'Unnamed business'),
                  subtitle: Text('Applicant: ${application.applicantUid}'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () =>
                      Navigator.of(context).push(MaterialPageRoute<void>(
                    builder: (_) => MerchantReviewDetailScreen(
                      application: application,
                      reviews: reviews,
                    ),
                  )),
                );
              },
            );
          },
        ),
      );
}
