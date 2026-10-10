import 'dart:developer';
import 'dart:convert';
import 'package:sqflite_common/sqlite_api.dart';

/// A separate company workspace: never masquerades as a retail merchant database.
abstract interface class CompanyWorkStorage {
  Future<void> saveDocument(String key, Map<String, Object?> body);
  Future<void> saveDraft(String key, Map<String, Object?> body);
  Future<Map<String, Object?>?> document(String key);
  Future<Map<String, Object?>?> draft(String key);
  Future<void> clearDraft(String key);
  Future<void> queueProof(
      String id, Map<String, Object?> payload, Map<String, Object?> run);
  Future<List<Map<String, Object?>>> pending();
  Future<void> acknowledge(String id);
  Future<void> block(String id, String message);
  Future<void> verifyAuthority(Map<String, Object?> clock);
  Future<bool> offlineAllowed(Map<String, Object?>? clock);
  Future<void> invalidateAuthority();
  Future<void> close();
}

final class CompanyWorkStore implements CompanyWorkStorage {
  CompanyWorkStore._(this._db);
  final Database _db;
  static Future<CompanyWorkStore> open(DatabaseFactory factory, String path,
      {required String companyId,
      required String uid,
      required String role}) async {
    final db = await factory.openDatabase(path,
        options: OpenDatabaseOptions(
            version: 1,
            singleInstance: false,
            onConfigure: (db) async => db.execute('PRAGMA synchronous = FULL'),
            onCreate: (db, _) async {
              await db.execute(
                  'CREATE TABLE context(company TEXT NOT NULL,uid TEXT NOT NULL,role TEXT NOT NULL)');
              await db.execute(
                  'CREATE TABLE documents(key TEXT PRIMARY KEY,body TEXT NOT NULL)');
              await db.execute(
                  'CREATE TABLE drafts(key TEXT PRIMARY KEY,body TEXT NOT NULL)');
              await db.execute(
                  'CREATE TABLE outbox(id TEXT PRIMARY KEY,payload TEXT NOT NULL,status TEXT NOT NULL,message TEXT)');
              await db.execute(
                  'CREATE TABLE authority(id INTEGER PRIMARY KEY,boot INTEGER,elapsed INTEGER,wall INTEGER)');
            }));
    try {
      await db.transaction((tx) async {
        final rows = await tx.query('context');
        if (rows.isEmpty) {
          await tx.insert(
              'context', {'company': companyId, 'uid': uid, 'role': role});
        } else if (rows.single['company'] != companyId ||
            rows.single['uid'] != uid ||
            rows.single['role'] != role) {
          throw StateError('Company workspace scope mismatch');
        }
      });
      return CompanyWorkStore._(db);
    } catch (_) {
      await db.close();
      rethrow;
    }
  }

  @override
  Future<void> saveDocument(String key, Map<String, Object?> body) =>
      _put('documents', key, body);
  @override
  Future<void> saveDraft(String key, Map<String, Object?> body) =>
      _put('drafts', key, body);
  Future<void> _put(
          String table, String key, Map<String, Object?> body) async =>
      _db.insert(table, {'key': key, 'body': jsonEncode(body)},
          conflictAlgorithm: ConflictAlgorithm.replace);
  @override
  Future<Map<String, Object?>?> document(String key) => _get('documents', key);
  @override
  Future<Map<String, Object?>?> draft(String key) => _get('drafts', key);
  Future<Map<String, Object?>?> _get(String table, String key) async {
    final rows = await _db.query(table, where: 'key=?', whereArgs: [key]);
    return rows.isEmpty
        ? null
        : Map<String, Object?>.from(
            jsonDecode(rows.single['body'] as String) as Map);
  }

  @override
  Future<void> clearDraft(String key) async =>
      _db.delete('drafts', where: 'key=?', whereArgs: [key]);
  @override
  Future<void> queueProof(
      String id, Map<String, Object?> payload, Map<String, Object?> run) async {
    final trace = TimelineTask()..start('company.queueProof');
    try {
      await _db.transaction((tx) async {
        final old = await tx.query('outbox', where: 'id=?', whereArgs: [id]);
        if (old.isNotEmpty) {
          if (old.single['payload'] != jsonEncode(payload)) {
            throw StateError('Pending proof changed');
          }
          return;
        }
        await tx.insert('outbox',
            {'id': id, 'payload': jsonEncode(payload), 'status': 'pending'});
        await tx.insert(
            'documents', {'key': 'run:${run['id']}', 'body': jsonEncode(run)},
            conflictAlgorithm: ConflictAlgorithm.replace);
        await tx.delete('drafts',
            where: 'key=?', whereArgs: ['proof:${payload['stopId']}']);
      });
    } finally {
      trace.finish();
    }
  }

  @override
  Future<List<Map<String, Object?>>> pending() =>
      _db.query('outbox', orderBy: 'rowid');
  @override
  Future<void> acknowledge(String id) async =>
      _db.delete('outbox', where: 'id=?', whereArgs: [id]);
  @override
  Future<void> block(String id, String message) async =>
      _db.update('outbox', {'status': 'blocked', 'message': message},
          where: 'id=?', whereArgs: [id]);
  @override
  Future<void> verifyAuthority(Map<String, Object?> clock) async {
    if (clock['bootCount'] is! int ||
        clock['elapsedRealtimeMs'] is! int ||
        (clock['elapsedRealtimeMs'] as int) < 0) {
      await invalidateAuthority();
      return;
    }
    await _db.insert(
        'authority',
        {
          'id': 1,
          'boot': clock['bootCount'],
          'elapsed': clock['elapsedRealtimeMs'],
          'wall': DateTime.now().millisecondsSinceEpoch
        },
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  @override
  Future<bool> offlineAllowed(Map<String, Object?>? clock) async {
    if (clock == null ||
        clock['bootCount'] is! int ||
        clock['elapsedRealtimeMs'] is! int ||
        (clock['elapsedRealtimeMs'] as int) < 0) {
      return false;
    }
    final rows = await _db.query('authority');
    if (rows.isEmpty) return false;
    final row = rows.single;
    final elapsed = clock['elapsedRealtimeMs'];
    return row['boot'] == clock['bootCount'] &&
        elapsed is int &&
        row['elapsed'] is int &&
        elapsed >= (row['elapsed'] as int) &&
        elapsed - (row['elapsed'] as int) <
            const Duration(days: 7).inMilliseconds &&
        DateTime.now().millisecondsSinceEpoch >= (row['wall'] as int);
  }

  @override
  Future<void> invalidateAuthority() async => _db.delete('authority');
  @override
  Future<void> close() => _db.close();
}
