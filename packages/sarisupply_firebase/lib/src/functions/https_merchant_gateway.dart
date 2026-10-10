import 'dart:async';
import 'dart:convert';
import 'dart:developer';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../environment/sarisupply_environment.dart';
import '../environment/client_configuration.dart';
import 'merchant_application_functions.dart';

final class HttpsMerchantGateway implements MerchantCallableGateway {
  HttpsMerchantGateway({
    required Uri endpoint,
    required SariSupplyEnvironment environment,
    required Future<String?> Function() idToken,
    required Future<String?> Function() appCheckToken,
    http.Client? client,
    Duration timeout = const Duration(seconds: 20),
  })  : _endpoint = endpoint,
        _environment = environment,
        _idToken = idToken,
        _appCheckToken = appCheckToken,
        _client = client ?? _sharedClient,
        _timeout = timeout {
    if (endpoint.scheme != 'https' ||
        endpoint.host.isEmpty ||
        endpoint.userInfo.isNotEmpty ||
        endpoint.hasQuery ||
        endpoint.hasFragment ||
        (endpoint.path.isNotEmpty && endpoint.path != '/')) {
      throw ArgumentError('Backend endpoint must be an HTTPS origin');
    }
  }

  factory HttpsMerchantGateway.forApp(FirebaseApp app) {
    final environment = parseSariSupplyEnvironment(
        const String.fromEnvironment('SARISUPPLY_ENV', defaultValue: 'dev'));
    if (app.options.projectId != 'sarisupply-${environment.name}-aracena18') {
      throw StateError('Backend and Firebase environments must match');
    }
    const envUrl = String.fromEnvironment('SARISUPPLY_API_URL');
    final endpoint = ClientConfiguration.backendOrigin(envUrl);
    return HttpsMerchantGateway(
      endpoint: endpoint,
      environment: environment,
      idToken: () async =>
          FirebaseAuth.instanceFor(app: app).currentUser?.getIdToken(),
      appCheckToken: () async {
        await _activateAppCheck(app, environment);
        return FirebaseAppCheck.instanceFor(app: app).getToken();
      },
    );
  }

  static final _sharedClient = http.Client();
  static final _appCheckActivations = <String, Future<void>>{};
  static Future<void> _activateAppCheck(
      FirebaseApp app, SariSupplyEnvironment environment) async {
    await (_appCheckActivations[app.name] ??= () async {
      try {
        const webKey = String.fromEnvironment('SARISUPPLY_APP_CHECK_WEB_KEY');
        const webProvider = String.fromEnvironment(
          'SARISUPPLY_APP_CHECK_WEB_PROVIDER',
          defaultValue: 'recaptcha-v3',
        );
        if (kIsWeb && webKey.isEmpty) {
          throw StateError('App Check web site key is required');
        }
        await FirebaseAppCheck.instanceFor(app: app).activate(
          providerWeb: kIsWeb
              ? switch (webProvider) {
                  'enterprise' => ReCaptchaEnterpriseProvider(webKey),
                  'recaptcha-v3' => ReCaptchaV3Provider(webKey),
                  _ => throw StateError('Unknown App Check web provider'),
                }
              : null,
          providerAndroid: environment == SariSupplyEnvironment.prod
              ? const AndroidPlayIntegrityProvider()
              : const AndroidDebugProvider(),
        );
      } catch (_) {
        _appCheckActivations.remove(app.name);
        rethrow;
      }
    }());
  }

  final Uri _endpoint;
  final SariSupplyEnvironment _environment;
  final Future<String?> Function() _idToken;
  final Future<String?> Function() _appCheckToken;
  final http.Client _client;
  final Duration _timeout;

  @override
  Future<Map<String, Object?>> call(
      String name, Map<String, Object?> payload) async {
    final abort = Completer<void>();
    try {
      return await _call(name, payload, abort).timeout(_timeout);
    } on TimeoutException {
      throw FirebaseFunctionsException(
          code: 'deadline-exceeded', message: 'Connection timed out');
    } on http.ClientException {
      throw FirebaseFunctionsException(
          code: 'unavailable', message: 'Connection unavailable');
    } on FirebaseException catch (error) {
      if (error is FirebaseFunctionsException) rethrow;
      final denied = [
        'user-disabled',
        'user-token-expired',
        'invalid-user-token'
      ].contains(error.code);
      throw FirebaseFunctionsException(
          code: denied ? 'unauthenticated' : 'unavailable',
          message: denied
              ? 'Sign in again'
              : error.code == 'network-request-failed'
                  ? 'Connection unavailable'
                  : 'Authentication service unavailable');
    } finally {
      if (!abort.isCompleted) abort.complete();
    }
  }

  Future<T> _timed<T>(String name, Future<T> Function() action) async {
    final task = TimelineTask()..start(name);
    try {
      return await action();
    } finally {
      task.finish();
    }
  }

  Future<Map<String, Object?>> _call(
      String name, Map<String, Object?> payload, Completer<void> abort) async {
    if (!RegExp(r'^[A-Za-z]+$').hasMatch(name)) {
      throw ArgumentError('Invalid command name');
    }
    final token = await _timed('https.authToken', _idToken);
    if (token == null || token.isEmpty) {
      throw FirebaseFunctionsException(
          code: 'unauthenticated', message: 'Sign in required');
    }
    final String? attestation;
    try {
      attestation = await _timed('https.appCheck', _appCheckToken);
    } on FirebaseException {
      // Failed attestation is retryable; it is never proof of device revocation.
      throw FirebaseFunctionsException(
          code: 'unavailable', message: 'App verification unavailable');
    }
    if (attestation == null || attestation.isEmpty) {
      throw FirebaseFunctionsException(
          code: 'unavailable', message: 'App verification unavailable');
    }
    // A delayed token must never start a mutation after the caller timed out.
    if (abort.isCompleted) throw TimeoutException('Connection timed out');
    final request = http.AbortableRequest(
        'POST', _endpoint.resolve('/v1/commands/$name'),
        abortTrigger: abort.future)
      ..headers.addAll({
        'content-type': 'application/json',
        'authorization': 'Bearer $token',
        'x-firebase-appcheck': attestation,
        'x-sarisupply-environment': _environment.name
      })
      ..body = jsonEncode({'data': payload});
    final response = await _timed('https.request.$name',
        () async => http.Response.fromStream(await _client.send(request)));
    Object? body;
    try {
      body = jsonDecode(response.body);
    } on FormatException {
      throw FirebaseFunctionsException(
          code: response.statusCode >= 500 ? 'unavailable' : 'data-loss',
          message: response.statusCode >= 500
              ? 'Service unavailable'
              : 'Invalid server response');
    }
    if (body is Map<String, dynamic>) {
      final error = body['error'];
      if (response.statusCode != 200 &&
          error is Map<String, dynamic> &&
          error['code'] is String) {
        throw FirebaseFunctionsException(
            code: response.statusCode >= 500
                ? 'unavailable'
                : error['code'] as String,
            message: error['message'] is String
                ? error['message'] as String
                : 'Request failed');
      }
      final result = body['result'];
      if (response.statusCode == 200 && result is Map<String, dynamic>) {
        return Map<String, Object?>.from(result);
      }
    }
    throw FirebaseFunctionsException(
        code: response.statusCode >= 500 ? 'unavailable' : 'data-loss',
        message: response.statusCode >= 500
            ? 'Service unavailable'
            : 'Invalid server response');
  }
}
