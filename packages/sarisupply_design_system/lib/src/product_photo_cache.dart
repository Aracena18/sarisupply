import 'package:flutter/foundation.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';

/// A dedicated disk cache isolates product photos from other app files.
final class ProductPhotoCache extends CacheManager {
  ProductPhotoCache({Config? configuration, this.maxBytes = 100 * 1024 * 1024})
    : super(
        configuration ??
            Config(
              'sarisupply_product_photos',
              stalePeriod: const Duration(days: 365),
              maxNrOfCacheObjects: 3000,
            ),
      );
  static final ProductPhotoCache instance = ProductPhotoCache();
  final int maxBytes;
  Future<void> _pruning = Future.value();

  Future<void> _enforceBudget(FileInfo current) {
    final result = _pruning.catchError((Object _) {}).then((_) async {
      var total = 0;
      final objects = await config.repo.getAllObjects();
      final sizes = <String, int>{};
      // Only completed, registered downloads participate. Never remove a file
      // being written by another request. removeFile also clears cache metadata.
      for (final object in objects) {
        final file = await config.fileSystem.createFile(object.relativePath);
        if (await file.exists()) {
          sizes[object.key] = await file.length();
          total += sizes[object.key]!;
        }
      }
      objects.sort(
        (a, b) =>
            (a.touched ?? DateTime(0)).compareTo(b.touched ?? DateTime(0)),
      );
      for (final object in objects) {
        if (total <= maxBytes) break;
        if (object.key == current.originalUrl) continue;
        await removeFile(object.key);
        total -= sizes[object.key] ?? 0;
      }
      if (total > maxBytes) {
        await removeFile(current.originalUrl);
        throw const FormatException('Product photo exceeds cache limit');
      }
    });
    _pruning = result;
    return result;
  }

  @override
  Stream<FileResponse> getFileStream(
    String url, {
    String? key,
    Map<String, String>? headers,
    bool withProgress = false,
  }) async* {
    await for (final response in super.getFileStream(
      url,
      key: key,
      headers: headers,
      withProgress: withProgress,
    )) {
      if (!kIsWeb &&
          response is FileInfo &&
          response.source == FileSource.Online) {
        await _enforceBudget(response);
      }
      yield response;
    }
  }
}
