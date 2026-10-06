import 'package:flutter/material.dart';
import 'package:sarisupply_firebase/sarisupply_firebase.dart';
import 'package:sarisupply_models/sarisupply_models.dart';
import 'checkout_controller.dart';

Future<bool> requestOwnerReversalApproval(
    {required BuildContext context,
    required CheckoutController controller,
    required CheckoutIntent intent,
    required CheckoutSale sale}) async {
  final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
              title: const Text('Owner approval required'),
              content: Text('${sale.merchantName} · ${sale.branchName}\n\n'
                  '${intent.kind == 'refund' ? 'Refund' : 'Void'} ${formatPhp((intent.payload[intent.kind == 'refund' ? 'totalRefundCentavos' : 'voidCentavos']) as int)}\n'
                  'Tender: ${intent.payload['tenderKind']}\nReason: ${intent.payload['reason']}\nReceipt: ${sale.id}\n\n'
                  'Sign in with the store Owner’s Google account to approve this exact request.'),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text('Cancel')),
                FilledButton(
                    onPressed: () => Navigator.pop(context, true),
                    child: const Text('Sign in as Owner'))
              ]));
  if (confirmed != true || !context.mounted) return false;
  await controller.sync();
  final original = await controller.store.checkout.operation(sale.id);
  if (original?.status != 'accepted') {
    throw StateError('Sync the original receipt before approval');
  }
  final auth = FirebaseGoogleAuthRepository.forDefaultApp();
  try {
    await auth.signInWithGoogle();
    await CheckoutFunctions.forHuman().approveReversal(intent);
  } finally {
    await auth.signOut();
  }
  if (!await controller.revalidate()) {
    throw StateError('Cashier access changed');
  }
  return true;
}
