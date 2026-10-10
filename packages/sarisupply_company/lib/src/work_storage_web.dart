import 'dart:convert';
import 'package:web/web.dart' as web;
import 'package:sarisupply_inventory/sarisupply_inventory.dart';

Future<CompanyWorkStorage> openCompanyWorkStorage({
  required String companyId,
  required String uid,
  required String role,
}) async => _BrowserWorkStore('company:$companyId:$uid:$role');

/// Browser drafts and operation IDs only; Android Rider work uses durable SQLite.
final class _BrowserWorkStore implements CompanyWorkStorage {
  _BrowserWorkStore(this.prefix);
  final String prefix;
  String key(String kind, String id) => '$prefix:$kind:$id';
  Future<void> _put(String kind, String id, Map<String, Object?> body) async =>
      web.window.localStorage.setItem(key(kind, id), jsonEncode(body));
  Future<Map<String, Object?>?> _get(String kind, String id) async {
    final raw = web.window.localStorage.getItem(key(kind, id));
    return raw == null
        ? null
        : Map<String, Object?>.from(jsonDecode(raw) as Map);
  }

  @override
  Future<void> saveDocument(String id, Map<String, Object?> body) =>
      _put('documents', id, body);
  @override
  Future<void> saveDraft(String id, Map<String, Object?> body) =>
      _put('drafts', id, body);
  @override
  Future<Map<String, Object?>?> document(String id) => _get('documents', id);
  @override
  Future<Map<String, Object?>?> draft(String id) => _get('drafts', id);
  @override
  Future<void> clearDraft(String id) async =>
      web.window.localStorage.removeItem(key('drafts', id));
  @override
  Future<void> queueProof(
    String id,
    Map<String, Object?> payload,
    Map<String, Object?> run,
  ) async => throw UnsupportedError('Driver work requires Android');
  @override
  Future<List<Map<String, Object?>>> pending() async => [];
  @override
  Future<void> acknowledge(String id) async {}
  @override
  Future<void> block(String id, String message) async {}
  @override
  Future<void> verifyAuthority(Map<String, Object?> clock) async {}
  @override
  Future<bool> offlineAllowed(Map<String, Object?>? clock) async => false;
  @override
  Future<void> invalidateAuthority() async {}
  @override
  Future<void> close() async {}
}
