import 'dart:async';
import 'package:http/http.dart' as http;
import 'package:sarisupply_models/sarisupply_models.dart';
import 'merchant_application_functions.dart';

/// Direct binary uploads; trusted HTTPS commands issue authority and verify assets.
final class ProductImageFunctions {
  ProductImageFunctions(this.gateway, {http.Client Function()? clientFactory})
      : _clientFactory = clientFactory ?? http.Client.new;
  final MerchantCallableGateway gateway;
  final http.Client Function() _clientFactory;

  Future<ProductImageRef> upload(String merchantId, String productId,
      String uploadId, List<int> bytes, String format) async {
    if (bytes.isEmpty ||
        bytes.length > 5 * 1024 * 1024 ||
        !['jpg', 'png', 'webp'].contains(format)) {
      throw ArgumentError('Use a JPEG, PNG or WebP photo up to 5 MiB');
    }
    final scope = {
      'merchantId': merchantId,
      'productId': productId,
      'uploadId': uploadId
    };
    // Completion also recovers an uploaded asset after a lost response or app retry.
    final prepared = await gateway.call('prepareProductImageUpload', {
      ...scope,
      'bytes': bytes.length,
      'format': format,
    });
    final url = Uri.parse(prepared['uploadUrl'] as String);
    final publicId = prepared['publicId'];
    if (prepared['uploadId'] != uploadId ||
        publicId is! String ||
        url.scheme != 'https' ||
        url.host != 'api.cloudinary.com' ||
        !RegExp(r'^/v1_1/[A-Za-z0-9_-]+/image/upload$').hasMatch(url.path) ||
        url.hasQuery ||
        url.userInfo.isNotEmpty ||
        prepared['parameters'] is! Map) {
      throw const FormatException('Invalid photo upload authorization');
    }
    final fields = Map<String, String>.from(prepared['parameters'] as Map);
    if (fields['public_id'] != publicId ||
        fields['overwrite'] != 'false' ||
        fields['api_key'] == null ||
        fields['signature'] == null) {
      throw const FormatException('Invalid photo upload authorization');
    }
    final client = _clientFactory();
    try {
      final request = http.MultipartRequest('POST', url)
        ..fields.addAll(fields)
        ..files.add(http.MultipartFile.fromBytes('file', bytes,
            filename: 'product.$format'));
      final response =
          await client.send(request).timeout(const Duration(seconds: 60));
      await response.stream.drain<void>().timeout(const Duration(seconds: 30));
      // An existing deterministic ID indicates an earlier successful upload.
      // Even an uncertain upload is resolved solely by authoritative completion.
      if (response.statusCode >= 500 || response.statusCode == 429) {
        throw const FormatException(
            'Photo service unavailable; retry with the same photo');
      }
    } on TimeoutException {
      // The provider may have accepted the upload. Completion checks the same ID.
    } on http.ClientException {
      // Preserve the draft and resolve uncertain upload outcomes on the backend.
    } finally {
      client.close();
    }
    final result = await gateway.call('completeProductImageUpload', scope);
    if (result['uploadId'] != uploadId || result['image'] is! Map) {
      throw const FormatException('Invalid verified photo');
    }
    final image = ProductImageRef.fromMap(
        Map<String, Object?>.from(result['image'] as Map));
    if (image.publicId != publicId ||
        image.version < 1 ||
        Uri.parse(image.secureUrl).host != 'res.cloudinary.com' ||
        !image.secureUrl.startsWith('https://')) {
      throw const FormatException('Invalid verified photo');
    }
    return image;
  }
}
