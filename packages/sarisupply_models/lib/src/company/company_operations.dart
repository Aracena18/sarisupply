/// Version-one company records. Business authority always comes from the server.
final class CompanyRecord {
  CompanyRecord(Map<String, Object?> map) : data = Map.unmodifiable(map) {
    if (data['id'] is! String || (data['id'] as String).isEmpty) {
      throw const FormatException('Invalid company record');
    }
  }
  final Map<String, Object?> data;
  String get id => data['id'] as String;
  String string(String key) => data[key] is String ? data[key] as String : '';
  int number(String key) => data[key] is int ? data[key] as int : 0;
  List<Map<String, Object?>> records(String key) {
    final raw = data[key];
    if (raw == null) return const [];
    if (raw is! List || raw.any((item) => item is! Map)) {
      throw FormatException('Invalid $key');
    }
    return raw.map((item) => Map<String, Object?>.from(item as Map)).toList();
  }

  String get status => string('status');
  int get revision => number('revision');

  /// Optional company product photo URL. Empty means no photo; callers fall
  /// back to a category placeholder via [ProductThumbnail].
  String get imageUrl => string('imageUrl');
}

final class CompanyPage {
  CompanyPage(
      {required this.records, required this.nextCursor, required this.hasMore});
  final List<CompanyRecord> records;
  final String? nextCursor;
  final bool hasMore;
}

final class SupplyingCompany {
  const SupplyingCompany(this.id, this.name);
  final String id, name;
}
