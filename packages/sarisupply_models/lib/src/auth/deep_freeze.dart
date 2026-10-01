/// Copies collection values at the model boundary so callers cannot mutate
/// stored state through nested maps, lists, or sets.
Map<String, Object?> deepFreezeStringMap(Map<String, Object?> source) =>
    Map<String, Object?>.unmodifiable({
      for (final entry in source.entries) entry.key: _deepFreeze(entry.value),
    });

Object? _deepFreeze(Object? value) {
  if (value is Map<String, dynamic>) {
    return Map<String, Object?>.unmodifiable({
      for (final entry in value.entries) entry.key: _deepFreeze(entry.value),
    });
  }
  if (value is Map) {
    return Map<Object?, Object?>.unmodifiable({
      for (final entry in value.entries)
        _deepFreeze(entry.key): _deepFreeze(entry.value),
    });
  }
  if (value is List) {
    return List<Object?>.unmodifiable(value.map(_deepFreeze));
  }
  if (value is Set) {
    return Set<Object?>.unmodifiable(value.map(_deepFreeze));
  }
  return value;
}
