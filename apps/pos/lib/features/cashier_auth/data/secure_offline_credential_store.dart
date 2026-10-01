import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:sarisupply_auth/sarisupply_auth.dart';

abstract interface class SecureKeyValueStore {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
  Future<void> delete(String key);
  Future<Map<String, String>> readAll();
}

final class FlutterSecureKeyValueStore implements SecureKeyValueStore {
  FlutterSecureKeyValueStore([FlutterSecureStorage? storage])
      : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  @override
  Future<String?> read(String key) => _storage.read(key: key);
  @override
  Future<void> write(String key, String value) =>
      _storage.write(key: key, value: value);
  @override
  Future<void> delete(String key) => _storage.delete(key: key);
  @override
  Future<Map<String, String>> readAll() => _storage.readAll();
}

final class StoredOfflineCredential {
  const StoredOfflineCredential({
    required this.cashierId,
    required this.deviceId,
    required this.credentialVersion,
    required this.salt,
    required this.derivedVerifier,
    required this.bundleIssuedAt,
    required this.bundleExpiresAt,
    required this.lastObservedWallClock,
    required this.clockAnchor,
    required this.failedAttempts,
    required this.cooldownUntil,
  });

  final String cashierId;
  final String deviceId;
  final int credentialVersion;
  final List<int> salt;
  final List<int> derivedVerifier;
  final DateTime bundleIssuedAt;
  final DateTime bundleExpiresAt;
  final DateTime lastObservedWallClock;
  final OfflineClockAnchor? clockAnchor;
  final int failedAttempts;
  final DateTime? cooldownUntil;

  StoredOfflineCredential copyWith({
    DateTime? bundleIssuedAt,
    DateTime? bundleExpiresAt,
    DateTime? lastObservedWallClock,
    OfflineClockAnchor? clockAnchor,
    bool clearClockAnchor = false,
    int? failedAttempts,
    DateTime? cooldownUntil,
    bool clearCooldown = false,
  }) =>
      StoredOfflineCredential(
        cashierId: cashierId,
        deviceId: deviceId,
        credentialVersion: credentialVersion,
        salt: salt,
        derivedVerifier: derivedVerifier,
        bundleIssuedAt: bundleIssuedAt ?? this.bundleIssuedAt,
        bundleExpiresAt: bundleExpiresAt ?? this.bundleExpiresAt,
        lastObservedWallClock:
            lastObservedWallClock ?? this.lastObservedWallClock,
        clockAnchor: clearClockAnchor ? null : clockAnchor ?? this.clockAnchor,
        failedAttempts: failedAttempts ?? this.failedAttempts,
        cooldownUntil:
            clearCooldown ? null : cooldownUntil ?? this.cooldownUntil,
      );

  Map<String, Object?> toMap() => {
        'cashierId': cashierId,
        'deviceId': deviceId,
        'credentialVersion': credentialVersion,
        'salt': base64Encode(salt),
        'derivedVerifier': base64Encode(derivedVerifier),
        'bundleIssuedAt': bundleIssuedAt.toIso8601String(),
        'bundleExpiresAt': bundleExpiresAt.toIso8601String(),
        'lastObservedWallClock': lastObservedWallClock.toIso8601String(),
        'clockAnchor': clockAnchor == null
            ? null
            : {
                'wallClock': clockAnchor!.wallClock.toIso8601String(),
                'bootCount': clockAnchor!.bootCount,
                'elapsedRealtimeMs':
                    clockAnchor!.elapsedRealtime.inMilliseconds,
              },
        'failedAttempts': failedAttempts,
        'cooldownUntil': cooldownUntil?.toIso8601String(),
      };

  factory StoredOfflineCredential.fromMap(Map<String, dynamic> map) =>
      StoredOfflineCredential(
        cashierId: map['cashierId'] as String,
        deviceId: map['deviceId'] as String,
        credentialVersion: map['credentialVersion'] as int,
        salt: base64Decode(map['salt'] as String),
        derivedVerifier: base64Decode(map['derivedVerifier'] as String),
        bundleIssuedAt: DateTime.parse(map['bundleIssuedAt'] as String),
        bundleExpiresAt: DateTime.parse(map['bundleExpiresAt'] as String),
        lastObservedWallClock:
            DateTime.parse(map['lastObservedWallClock'] as String),
        clockAnchor: map['clockAnchor'] == null
            ? null
            : _anchorFromMap(
                Map<String, dynamic>.from(map['clockAnchor'] as Map)),
        failedAttempts: map['failedAttempts'] as int,
        cooldownUntil: map['cooldownUntil'] == null
            ? null
            : DateTime.parse(map['cooldownUntil'] as String),
      );

  static OfflineClockAnchor _anchorFromMap(Map<String, dynamic> map) {
    final bootCount = map['bootCount'] as int;
    final elapsedMs = map['elapsedRealtimeMs'] as int;
    if (bootCount < 0 || elapsedMs < 0) {
      throw const FormatException('Invalid offline clock anchor');
    }
    return OfflineClockAnchor(
      wallClock: DateTime.parse(map['wallClock'] as String),
      bootCount: bootCount,
      elapsedRealtime: Duration(milliseconds: elapsedMs),
    );
  }
}

final class SecureOfflineCredentialStore {
  SecureOfflineCredentialStore([SecureKeyValueStore? keys])
      : _keys = keys ?? FlutterSecureKeyValueStore();

  final SecureKeyValueStore _keys;
  static String _credentialKey(String deviceId, String cashierId) =>
      'offline-credential:$deviceId:$cashierId';
  static String _eventsKey(String deviceId) => 'offline-events:$deviceId';

  Future<StoredOfflineCredential?> read(
      String deviceId, String cashierId) async {
    final key = _credentialKey(deviceId, cashierId);
    final encoded = await _keys.read(key);
    if (encoded == null) return null;
    try {
      final record = StoredOfflineCredential.fromMap(
          Map<String, dynamic>.from(jsonDecode(encoded) as Map));
      if (record.deviceId != deviceId ||
          record.cashierId != cashierId ||
          record.salt.length != 16 ||
          record.derivedVerifier.length != 32) {
        throw const FormatException('Invalid offline credential');
      }
      return record;
    } on FormatException {
      await _keys.delete(key);
      return null;
    } on TypeError {
      await _keys.delete(key);
      return null;
    }
  }

  Future<void> save(StoredOfflineCredential credential) => _keys.write(
      _credentialKey(credential.deviceId, credential.cashierId),
      jsonEncode(credential.toMap()));

  Future<void> delete(String deviceId, String cashierId) =>
      _keys.delete(_credentialKey(deviceId, cashierId));

  Future<void> deleteForDevice(String deviceId) async {
    final records = await listForDevice(deviceId);
    for (final record in records) {
      await delete(deviceId, record.cashierId);
    }
    await clearQueuedSecurityEvents(deviceId);
  }

  Future<List<StoredOfflineCredential>> listForDevice(String deviceId) async {
    final entries = await _keys.readAll();
    final prefix = 'offline-credential:$deviceId:';
    final records = <StoredOfflineCredential>[];
    for (final key in entries.keys.where((key) => key.startsWith(prefix))) {
      final cashierId = key.substring(prefix.length);
      final record = await read(deviceId, cashierId);
      if (record != null) records.add(record);
    }
    return records;
  }

  Future<void> queueFailedAttempt({
    required String deviceId,
    required String cashierId,
    required int failedAttempts,
    required DateTime occurredAt,
  }) async {
    final events = await queuedSecurityEvents(deviceId);
    events.add({
      'type': 'offline_pin_failed',
      'cashierId': cashierId,
      'failedAttempts': failedAttempts,
      'occurredAt': occurredAt.toIso8601String(),
    });
    await _keys.write(
        _eventsKey(deviceId),
        jsonEncode(events.length > 200
            ? events.sublist(events.length - 200)
            : events));
  }

  Future<List<Map<String, Object?>>> queuedSecurityEvents(
      String deviceId) async {
    final encoded = await _keys.read(_eventsKey(deviceId));
    if (encoded == null) return [];
    return (jsonDecode(encoded) as List)
        .map((event) => Map<String, Object?>.from(event as Map))
        .toList();
  }

  Future<void> clearQueuedSecurityEvents(String deviceId) =>
      _keys.delete(_eventsKey(deviceId));
}
