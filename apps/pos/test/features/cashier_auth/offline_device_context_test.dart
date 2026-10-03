import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:sarisupply_auth/sarisupply_auth.dart';
import 'package:sarisupply_pos/features/cashier_auth/data/secure_offline_credential_store.dart';

class _MemoryKeys implements SecureKeyValueStore {
  final values = <String, String>{};

  @override
  Future<String?> read(String key) async => values[key];

  @override
  Future<void> write(String key, String value) async {
    values[key] = value;
  }

  @override
  Future<void> delete(String key) async {
    values.remove(key);
  }

  @override
  Future<Map<String, String>> readAll() async => Map.of(values);
}

void main() {
  final verifiedAt = DateTime.utc(2026, 9, 28, 12);
  final anchor = OfflineClockAnchor(
    wallClock: verifiedAt,
    bootCount: 19,
    elapsedRealtime: const Duration(hours: 2),
  );

  StoredDeviceContext context() => StoredDeviceContext(
        deviceId: 'device-1',
        merchantId: 'merchant-1',
        branchId: 'branch-a',
        verifiedAt: verifiedAt,
        lastObservedWallClock: verifiedAt,
        clockAnchor: anchor,
      );

  OfflineTimeEvidence evidence({
    required DateTime now,
    required Duration elapsed,
    int bootCount = 19,
    OfflineClockReading? reading,
    bool missingReading = false,
  }) =>
      OfflineTimeEvidence(
        now: now,
        lastObservedWallClock: verifiedAt,
        anchor: anchor,
        reading: missingReading
            ? null
            : reading ??
                OfflineClockReading(
                  bootCount: bootCount,
                  elapsedRealtime: elapsed,
                ),
      );

  test('allows cached context for less than seven trusted elapsed days', () {
    final elapsed = const Duration(days: 6);
    expect(
      context().isUsableAt(evidence(
        now: verifiedAt.add(elapsed),
        elapsed: anchor.elapsedRealtime + elapsed,
      )),
      isTrue,
    );
  });

  test('requires online verification at exactly seven elapsed days', () {
    final elapsed = const Duration(days: 7);
    expect(
      context().isUsableAt(evidence(
        now: verifiedAt.add(elapsed),
        elapsed: anchor.elapsedRealtime + elapsed,
      )),
      isFalse,
    );
  });

  test('rejects forward and backward wall-clock manipulation', () {
    expect(
      context().isUsableAt(evidence(
        now: verifiedAt.add(const Duration(days: 8)),
        elapsed: anchor.elapsedRealtime + const Duration(days: 1),
      )),
      isFalse,
    );
    expect(
      context().isUsableAt(evidence(
        now: verifiedAt.add(const Duration(hours: 1)),
        elapsed: anchor.elapsedRealtime + const Duration(days: 1),
      )),
      isFalse,
    );
  });

  test('requires online verification after a reboot or missing clock sample',
      () {
    final elapsed = const Duration(days: 1);
    expect(
      context().isUsableAt(evidence(
        now: verifiedAt.add(elapsed),
        elapsed: anchor.elapsedRealtime + elapsed,
        bootCount: 20,
      )),
      isFalse,
    );
    expect(
      context().isUsableAt(evidence(
        now: verifiedAt.add(elapsed),
        elapsed: anchor.elapsedRealtime + elapsed,
        missingReading: true,
      )),
      isFalse,
    );
  });

  test('secure store preserves and binds context clock evidence to its device',
      () async {
    final keys = _MemoryKeys();
    final store = SecureOfflineCredentialStore(keys);
    await store.saveDeviceContext(context());

    final restored = await store.readDeviceContext('device-1');
    expect(restored?.merchantId, 'merchant-1');
    expect(restored?.branchId, 'branch-a');
    expect(restored?.clockAnchor?.bootCount, 19);
    expect(restored?.clockAnchor?.elapsedRealtime, const Duration(hours: 2));
    expect(await store.readDeviceContext('device-2'), isNull);
  });

  test('malformed cached context is removed and fails closed', () async {
    final keys = _MemoryKeys();
    final store = SecureOfflineCredentialStore(keys);
    const key = 'device-context:device-1';
    keys.values[key] = jsonEncode({
      'deviceId': 'device-1',
      'merchantId': 'merchant-1',
      'branchId': 'branch-a',
      'verifiedAt': verifiedAt.toIso8601String(),
      'lastObservedWallClock': verifiedAt.toIso8601String(),
      'clockAnchor': {'bootCount': -1, 'elapsedRealtimeMs': -1},
    });

    expect(await store.readDeviceContext('device-1'), isNull);
    expect(keys.values, isNot(contains(key)));
  });
}
