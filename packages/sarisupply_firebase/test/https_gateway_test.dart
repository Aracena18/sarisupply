import 'dart:async';
import 'dart:convert';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sarisupply_firebase/sarisupply_firebase.dart';

HttpsMerchantGateway gateway(
  Future<http.Response> Function(http.Request) send, {
  Future<String?> Function()? token,
  Duration timeout = const Duration(seconds: 20),
}) =>
    HttpsMerchantGateway(
      endpoint: Uri.parse('https://dev-api.example.test'),
      environment: SariSupplyEnvironment.dev,
      idToken: token ?? () async => 'device-token',
      appCheckToken: () async => 'app-check',
      client: MockClient(send),
      timeout: timeout,
    );

void main() {
  test('sends command with the selected session, App Check and environment',
      () async {
    final api = gateway((request) async {
      final correct = request.url.toString() ==
              'https://dev-api.example.test/v1/commands/getDeviceBootstrap' &&
          request.headers['authorization'] == 'Bearer device-token' &&
          request.headers['x-firebase-appcheck'] == 'app-check' &&
          request.headers['x-sarisupply-environment'] == 'dev' &&
          jsonDecode(request.body)['data']['branchId'] == 'branch-1';
      return http.Response(
        correct
            ? '{"result":{"deviceId":"device-1"}}'
            : '{"error":{"code":"permission-denied","message":"wrong identity"}}',
        correct ? 200 : 403,
      );
    });
    expect(await api.call('getDeviceBootstrap', {'branchId': 'branch-1'}),
        {'deviceId': 'device-1'});
  });
  test('preserves authoritative denial for existing revocation handling',
      () async {
    final api = gateway((_) async => http.Response(
        '{"error":{"code":"permission-denied","message":"Device revoked"}}',
        403));
    await expectLater(
        api.call('getDeviceBootstrap', {}),
        throwsA(isA<FirebaseFunctionsException>()
            .having((error) => error.code, 'code', 'permission-denied')));
  });
  test('maps server and network outages to retryable unavailable', () async {
    for (final send in <Future<http.Response> Function(http.Request)>[
      (_) async => http.Response('Bad Gateway', 502),
      (_) async => throw http.ClientException('offline'),
    ]) {
      await expectLater(
          gateway(send).call('getDeviceBootstrap', {}),
          throwsA(isA<FirebaseFunctionsException>()
              .having((error) => error.code, 'code', 'unavailable')));
    }
  });
  test('preserves server verification reason without revoking offline access',
      () async {
    final api = gateway((_) async => http.Response(
        '{"error":{"code":"unavailable","message":"App verification unavailable"}}',
        503));
    await expectLater(
        api.call('getDeviceBootstrap', {}),
        throwsA(isA<FirebaseFunctionsException>()
            .having((e) => e.code, 'code', 'unavailable')
            .having((e) => operationErrorMessage(e), 'recovery',
                'App verification failed. Retry or contact your administrator.')));
  });
  test('an upstream 5xx denial cannot invalidate cached authority', () async {
    final api = gateway((_) async => http.Response(
        '{"error":{"code":"permission-denied","message":"Proxy error"}}', 502));
    await expectLater(
        api.call('getDeviceBootstrap', {}),
        throwsA(isA<FirebaseFunctionsException>()
            .having((e) => isRetryableOperationError(e), 'retryable', true)));
  });
  test('recovery policy is independent of error copy', () {
    for (final message in [
      'App verification unavailable',
      'Service unavailable'
    ]) {
      final error =
          FirebaseFunctionsException(code: 'unavailable', message: message);
      expect(isRetryableOperationError(error), isTrue);
      expect(operationErrorMessage(error), isNot(contains('connection')));
    }
    expect(
        isRetryableOperationError(FirebaseFunctionsException(
            code: 'permission-denied', message: 'Device revoked')),
        isFalse);
    expect(
        operationErrorMessage(FirebaseFunctionsException(
            code: 'unavailable', message: 'Connection unavailable')),
        'Check your connection and try again.');
    expect(
        operationErrorMessage(FirebaseFunctionsException(
            code: 'unavailable', message: 'token=secret PIN=secret')),
        'The service is unavailable. Try again shortly.');
  });
  test('does not turn a broken successful response into an accepted command',
      () async {
    for (final body in ['broken', '{"result":[]}', '{}']) {
      await expectLater(
          gateway((_) async => http.Response(body, 200))
              .call('getDeviceBootstrap', {}),
          throwsA(isA<FirebaseFunctionsException>()
              .having((error) => error.code, 'code', 'data-loss')));
    }
  });
  test('rejects anonymous calls before a network mutation', () async {
    await expectLater(
        gateway((_) async => throw StateError('must not send'),
            token: () async => null).call('activatePosDevice', {}),
        throwsA(isA<FirebaseFunctionsException>()
            .having((error) => error.code, 'code', 'unauthenticated')));
  });
  test('missing attestation is retryable and is not a device revocation',
      () async {
    final api = HttpsMerchantGateway(
      endpoint: Uri.parse('https://dev-api.example.test'),
      environment: SariSupplyEnvironment.dev,
      idToken: () async => 'device-token',
      appCheckToken: () async => null,
      client: MockClient((_) async => throw StateError('must not send')),
    );
    await expectLater(
        api.call('getDeviceBootstrap', {}),
        throwsA(isA<FirebaseFunctionsException>()
            .having((error) => error.code, 'code', 'unavailable')));
  });
  test('times out the entire call, including token acquisition', () async {
    await expectLater(
        gateway((_) async => http.Response('{"result":{}}', 200),
                token: () => Completer<String?>().future,
                timeout: const Duration(milliseconds: 10))
            .call('getDeviceBootstrap', {}),
        throwsA(isA<FirebaseFunctionsException>()
            .having((error) => error.code, 'code', 'deadline-exceeded')));
  });
  test('refuses insecure or credential-bearing backend endpoints', () {
    for (final url in [
      'http://example.test',
      'https://user:password@example.test',
      'https://example.test?token=secret',
      'https://example.test/path'
    ]) {
      expect(
          () => HttpsMerchantGateway(
              endpoint: Uri.parse(url),
              environment: SariSupplyEnvironment.dev,
              idToken: () async => 'token',
              appCheckToken: () async => 'app'),
          throwsArgumentError);
    }
  });
  test('a late identity token cannot start a mutation after timeout', () async {
    final token = Completer<String?>();
    var writes = 0;
    final api = gateway((_) async {
      writes++;
      return http.Response('{"result":{}}', 200);
    }, token: () => token.future, timeout: const Duration(milliseconds: 10));
    await expectLater(api.call('activatePosDevice', {}),
        throwsA(isA<FirebaseFunctionsException>()));
    token.complete('late-token');
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(writes, 0);
  });
}
