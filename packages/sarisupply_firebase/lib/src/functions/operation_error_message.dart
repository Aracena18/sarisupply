import 'package:firebase_core/firebase_core.dart';
import '../environment/client_configuration.dart';

// Recovery policy must use error codes, never translated user-facing copy.
bool isRetryableOperationError(Object error) =>
    error is FirebaseException &&
    const {'unavailable', 'deadline-exceeded', 'network-request-failed'}
        .contains(error.code);

String operationErrorMessage(Object error,
    {String fallback = 'Unable to complete this action. Try again.'}) {
  if (error is ClientConfigurationException) {
    return 'Application setup is incomplete. Contact your administrator.';
  }
  if (error is FirebaseException) {
    return switch (error.code) {
      'unavailable' => switch (error.message) {
          'Connection unavailable' => 'Check your connection and try again.',
          'App verification unavailable' =>
            'App verification failed. Retry or contact your administrator.',
          'App not allowed' ||
          'Environment mismatch' ||
          'Origin not allowed' =>
            'Application setup is incomplete. Contact your administrator.',
          'Authentication service unavailable' =>
            'Sign-in service is unavailable. Try again shortly.',
          _ => 'The service is unavailable. Try again shortly.',
        },
      'deadline-exceeded' => 'The request timed out. Try again.',
      'network-request-failed' => 'Check your connection and try again.',
      'permission-denied' => 'Your access has changed. Refresh and try again.',
      'unauthenticated' => 'Sign in again to continue.',
      'already-exists' =>
        'This record already exists. Refresh the list. For a cashier, reset the PIN.',
      'resource-exhausted' => 'Too many attempts. Wait and try again.',
      'failed-precondition' => switch (error.message) {
          'Available warehouse stock changed. Refresh the order.' =>
            'Not enough available warehouse stock. Receive stock or propose smaller quantities, then try again.',
          'Order changed. Refresh before continuing.' =>
            'This order changed. Refresh to load its current quantities and status.',
          'Order is not awaiting acceptance' =>
            'This order was already processed. Refresh to see its current status.',
          'Payment exceeds order value' =>
            'This payment exceeds the remaining order balance. Refresh the order and enter no more than the unpaid balance.',
          _ => 'This action is no longer available. Refresh and try again.',
        },
      'invalid-argument' => 'Check the entered details and try again.',
      _ => fallback,
    };
  }
  return fallback;
}
