import 'dart:io';
import 'package:file/file.dart' as files;
import 'package:file/local.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sarisupply_design_system/src/product_photo_cache.dart';

class _Files implements FileSystem {
  _Files(this.directory);
  final String directory;
  @override
  Future<files.File> createFile(String name) async =>
      const LocalFileSystem().file('$directory/$name');
}

class _Service extends FileService {
  bool online = true;
  int calls = 0;
  @override
  Future<FileServiceResponse> get(
    String url, {
    Map<String, String>? headers,
  }) async {
    calls++;
    if (!online) throw const SocketException('offline');
    return _Response();
  }
}

class _Response implements FileServiceResponse {
  @override
  Stream<List<int>> get content => Stream.value(List.filled(8, 1));
  @override
  int get contentLength => 8;
  @override
  int get statusCode => 200;
  @override
  DateTime get validTill => DateTime.now().add(const Duration(days: 365));
  @override
  String? get eTag => null;
  @override
  String get fileExtension => '.webp';
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'cache survives restart offline and evicts completed files within its byte budget',
    () async {
      final root = await Directory.systemTemp.createTemp(
        'sarisupply-photo-cache-',
      );
      final service = _Service();
      Config config() => Config(
        'test-product-photos',
        fileSystem: _Files(root.path),
        repo: JsonCacheInfoRepository(path: '${root.path}/metadata.json'),
        fileService: service,
      );
      var cache = ProductPhotoCache(configuration: config(), maxBytes: 12);
      try {
        await cache.getFileStream('https://example.com/a.webp').toList();
        await cache.getFileStream('https://example.com/b.webp').toList();
        expect(
          await cache.getFileFromCache('https://example.com/a.webp'),
          isNull,
        );
        expect(
          await cache.getFileFromCache('https://example.com/b.webp'),
          isNotNull,
        );
        await cache.dispose();
        service.online = false;
        final count = service.calls;
        cache = ProductPhotoCache(configuration: config(), maxBytes: 12);
        final restored = await cache
            .getFileStream('https://example.com/b.webp')
            .toList();
        expect(restored.whereType<FileInfo>().single.source, FileSource.Cache);
        expect(service.calls, count);
        final absent = cache
            .getFileStream('https://example.com/uncached.webp')
            .toList();
        await expectLater(absent, throwsA(isA<SocketException>()));
      } finally {
        await cache.dispose();
        await root.delete(recursive: true);
      }
    },
  );
}
