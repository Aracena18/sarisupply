import 'dart:convert';
import 'dart:math';

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

final class StoredDeviceContext {
  const StoredDeviceContext({
    required this.deviceId,
    required this.merchantId,
    required this.branchId,
    required this.verifiedAt,
    required this.lastObservedWallClock,
    required this.clockAnchor,
  });

  final String deviceId;
  final String merchantId;
  final String branchId;
  final DateTime verifiedAt;
  final DateTime lastObservedWallClock;
  final OfflineClockAnchor? clockAnchor;

  bool isUsableAt(OfflineTimeEvidence time) =>
      OfflineCredentialPolicy.isWithinTrustedWindow(
        issuedAt: verifiedAt,
        expiresAt: verifiedAt.add(OfflineCredentialPolicy.maximumOfflineAge),
        time: time,
      );

  StoredDeviceContext copyWith({DateTime? lastObservedWallClock}) =>
      StoredDeviceContext(
        deviceId: deviceId,
        merchantId: merchantId,
        branchId: branchId,
        verifiedAt: verifiedAt,
        lastObservedWallClock:
            lastObservedWallClock ?? this.lastObservedWallClock,
        clockAnchor: clockAnchor,
      );

  Map<String, Object?> toMap() => {
        'deviceId': deviceId,
        'merchantId': merchantId,
        'branchId': branchId,
        'verifiedAt': verifiedAt.toUtc().toIso8601String(),
        'lastObservedWallClock':
            lastObservedWallClock.toUtc().toIso8601String(),
        'clockAnchor': clockAnchor == null
            ? null
            : {
                'wallClock': clockAnchor!.wallClock.toUtc().toIso8601String(),
                'bootCount': clockAnchor!.bootCount,
                'elapsedRealtimeMs':
                    clockAnchor!.elapsedRealtime.inMilliseconds,
              },
      };

  factory StoredDeviceContext.fromMap(Map<String, dynamic> map) =>
      StoredDeviceContext(
        deviceId: map['deviceId'] as String,
        merchantId: map['merchantId'] as String,
        branchId: map['branchId'] as String,
        verifiedAt: DateTime.parse(map['verifiedAt'] as String),
        lastObservedWallClock:
            DateTime.parse(map['lastObservedWallClock'] as String),
        clockAnchor: map['clockAnchor'] == null
            ? null
            : StoredOfflineCredential._anchorFromMap(
                Map<String, dynamic>.from(map['clockAnchor'] as Map)),
      );
}

final class SecureOfflineCredentialStore {
  SecureOfflineCredentialStore([SecureKeyValueStore? keys])
      : _keys = keys ?? FlutterSecureKeyValueStore();

  static const maxQueuedSecurityEvents = 200;

  final SecureKeyValueStore _keys;
  static String _credentialKey(String deviceId, String cashierId) =>
      'offline-credential:$deviceId:$cashierId';
  static String _legacyEventsKey(String deviceId) => 'offline-events:$deviceId';
  static String _eventPrefix(String deviceId) => 'offline-event:$deviceId:';
  static String _eventKey(String deviceId, String eventId) =>
      '${_eventPrefix(deviceId)}$eventId';
  static String _contextKey(String deviceId) => 'device-context:$deviceId';
  static String _newEventId() {
    final random = Random.secure();
    return base64Url
        .encode(List<int>.generate(16, (_) => random.nextInt(256)))
        .replaceAll('=', '');
  }

  static bool _isEventId(Object? value) =>
      value is String && RegExp(r'^[A-Za-z0-9_-]{16,80}$').hasMatch(value);

  static bool _hasValidEventPayload(Map<String, Object?> event) {
    final cashierId = event['cashierId'];
    final attempts = event['failedAttempts'];
    final occurredAt = event['occurredAt'];
    return event['type'] == 'offline_pin_failed' &&
        cashierId is String &&
        cashierId.isNotEmpty &&
        cashierId.length <= 128 &&
        !cashierId.contains('/') &&
        cashierId != '.' &&
        cashierId != '..' &&
        attempts is int &&
        attempts >= 5 &&
        attempts <= 1000 &&
        occurredAt is String &&
        occurredAt.length <= 40 &&
        DateTime.tryParse(occurredAt) != null;
  }

  static bool _sameEvent(
      Map<String, Object?> left, Map<String, Object?> right) {
    if (left.length != right.length) return false;
    for (final entry in left.entries) {
      if (right[entry.key] != entry.value) return false;
    }
    return true;
  }

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

  /// Remove offline authorization while preserving pending audit evidence.
  Future<void> invalidateDeviceAuthorization(String deviceId) async {
    // Invalidate the bootstrap anchor before any potentially corrupt credential.
    await _keys.delete(_contextKey(deviceId));
    final entries = await _keys.readAll();
    final prefix = 'offline-credential:$deviceId:';
    for (final key in entries.keys.where((key) => key.startsWith(prefix))) {
      await _keys.delete(key);
    }
  }

  Future<void> deleteForDevice(String deviceId) async {
    await invalidateDeviceAuthorization(deviceId);
    await clearQueuedSecurityEvents(deviceId);
  }

  Future<StoredDeviceContext?> readDeviceContext(String deviceId) async {
    final key = _contextKey(deviceId);
    final encoded = await _keys.read(key);
    if (encoded == null) return null;
    try {
      final context = StoredDeviceContext.fromMap(
          Map<String, dynamic>.from(jsonDecode(encoded) as Map));
      if (context.deviceId != deviceId ||
          context.merchantId.trim().isEmpty ||
          context.branchId.trim().isEmpty) {
        throw const FormatException('Invalid device context');
      }
      return context;
    } on FormatException {
      await _keys.delete(key);
      return null;
    } on TypeError {
      await _keys.delete(key);
      return null;
    }
  }

  Future<void> saveDeviceContext(StoredDeviceContext context) =>
      _keys.write(_contextKey(context.deviceId), jsonEncode(context.toMap()));

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
    if (!await hasSecurityEventCapacity(deviceId)) {
      throw StateError('Offline security event queue is full');
    }
    var eventId = _newEventId();
    var key = _eventKey(deviceId, eventId);
    while (await _keys.read(key) != null) {
      eventId = _newEventId();
      key = _eventKey(deviceId, eventId);
    }
    await _keys.write(
        key,
        jsonEncode({
          'type': 'offline_pin_failed',
          'eventId': eventId,
          'cashierId': cashierId,
          'failedAttempts': failedAttempts,
          'occurredAt': occurredAt.toIso8601String(),
        }));
  }

  Future<bool> hasSecurityEventCapacity(String deviceId) async {
    List<Map<String, Object?>> validEvents;
    try {
      validEvents = await queuedSecurityEvents(deviceId);
    } on Object {
      return false;
    }
    final entries = await _keys.readAll();
    if (entries.containsKey(_legacyEventsKey(deviceId))) return false;
    final prefix = _eventPrefix(deviceId);
    final count = entries.keys.where((key) => key.startsWith(prefix)).length;
    // A quarantined record occupies capacity and requires online recovery.
    return validEvents.length == count && count < maxQueuedSecurityEvents;
  }

  Future<List<Map<String, Object?>>> queuedSecurityEvents(
      String deviceId) async {
    final entries = await _keys.readAll();
    final prefix = _eventPrefix(deviceId);
    final events = <Map<String, Object?>>[];
    for (final entry in entries.entries.where((entry) =>
        entry.key.startsWith(prefix) &&
        entry.key != _legacyEventsKey(deviceId))) {
      try {
        final event = Map<String, Object?>.from(jsonDecode(entry.value) as Map);
        final eventId = event['eventId'];
        if (_hasValidEventPayload(event) &&
            _isEventId(eventId) &&
            entry.key == _eventKey(deviceId, eventId as String)) {
          events.add(event);
        }
      } on FormatException {
        // Keep unreadable records on disk instead of discarding pending data.
      } on TypeError {
        // Keep unreadable records on disk instead of discarding pending data.
      }
    }

    final legacyKey = _legacyEventsKey(deviceId);
    final legacyEncoded = entries[legacyKey];
    if (legacyEncoded != null) {
      List<Map<String, Object?>> legacyEvents;
      try {
        legacyEvents = (jsonDecode(legacyEncoded) as List)
            .map((event) => Map<String, Object?>.from(event as Map))
            .toList();
        if (!legacyEvents.every(_hasValidEventPayload)) return events;
      } on FormatException {
        return events;
      } on TypeError {
        return events;
      }
      // Leave corrupt legacy payloads untouched; never migrate or acknowledge them.
      final eventsById = <String, Map<String, Object?>>{
        for (final event in events) event['eventId']! as String: event,
      };
      final usedIds = {
        ...eventsById.keys,
        ...entries.keys
            .where((key) => key.startsWith(prefix))
            .map((key) => key.substring(prefix.length)),
      };
      final legacyIds = <String>{};
      for (final event in legacyEvents) {
        var eventId = event['eventId'];
        final existing = _isEventId(eventId) ? eventsById[eventId] : null;
        if (!_isEventId(eventId) ||
            legacyIds.contains(eventId) ||
            (existing == null && usedIds.contains(eventId)) ||
            (existing != null && !_sameEvent(existing, event))) {
          eventId = _newEventId();
          while (usedIds.contains(eventId) || legacyIds.contains(eventId)) {
            eventId = _newEventId();
          }
        }
        event['eventId'] = eventId;
        final stableId = eventId as String;
        legacyIds.add(stableId);
        usedIds.add(stableId);
      }

      // Save the assigned IDs first so an interrupted migration can resume
      // without generating new IDs or duplicating accepted reports.
      await _keys.write(legacyKey, jsonEncode(legacyEvents));
      for (final event in legacyEvents) {
        final eventId = event['eventId']! as String;
        final key = _eventKey(deviceId, eventId);
        final existing = eventsById[eventId];
        if (existing != null && _sameEvent(existing, event)) continue;
        if (await _keys.read(key) == null) {
          await _keys.write(key, jsonEncode(event));
        }
        events.add(event);
      }
      await _keys.delete(legacyKey);
    }
    return events;
  }

  Future<void> acknowledgeSecurityEvents(
      String deviceId, List<String> acceptedEventIds) async {
    await queuedSecurityEvents(deviceId);
    for (final eventId in acceptedEventIds.where(_isEventId)) {
      await _keys.delete(_eventKey(deviceId, eventId));
    }
  }

  Future<void> clearQueuedSecurityEvents(String deviceId) async {
    final entries = await _keys.readAll();
    final prefix = _eventPrefix(deviceId);
    for (final key in entries.keys.where((key) => key.startsWith(prefix))) {
      await _keys.delete(key);
    }
    await _keys.delete(_legacyEventsKey(deviceId));
  }
}
