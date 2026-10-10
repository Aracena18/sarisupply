import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sarisupply_firebase/src/functions/product_image_functions.dart';
import 'package:sarisupply_firebase/src/functions/merchant_application_functions.dart';

class _Gateway implements MerchantCallableGateway {
  final calls = <String>[];
  bool forged = false;
  @override
  Future<Map<String, Object?>> call(
      String name, Map<String, Object?> payload) async {
    calls.add(name);
    expect(payload['uploadId'], 'u');
    if (name == 'prepareProductImageUpload') {
      return {
        'uploadId': 'u',
        'publicId': 'sarisupply/dev/p/u',
        'uploadUrl': forged
            ? 'https://attacker.example/upload'
            : 'https://api.cloudinary.com/v1_1/cloud/image/upload',
        'parameters': {
          'public_id': 'sarisupply/dev/p/u',
          'overwrite': 'false',
          'api_key': 'key',
          'signature': 'signature'
        }
      };
    }
    return {
      'uploadId': 'u',
      'image': {
        'assetId': 'asset',
        'publicId': 'sarisupply/dev/p/u',
        'version': 1,
        'secureUrl':
            'https://res.cloudinary.com/cloud/image/upload/v1/photo.webp',
        'thumbnailUrl':
            'https://res.cloudinary.com/cloud/image/upload/v1/thumb.webp'
      }
    };
  }
}

void main() {
  test(
      'uncertain uploads and duplicate provider IDs are verified by the server',
      () async {
    for (final response in [409, 200, 0]) {
      final gateway = _Gateway();
      final functions = ProductImageFunctions(gateway,
          clientFactory: () => MockClient((request) async {
                expect(request.url.host, 'api.cloudinary.com');
                expect(request.headers['content-type'],
                    startsWith('multipart/form-data'));
                if (response == 0) throw TimeoutException('lost response');
                return http.Response('{}', response);
              }));
      final result =
          await functions.upload('m', 'p', 'u', [255, 216, 255], 'jpg');
      expect(result.assetId, 'asset');
      expect(gateway.calls,
          ['prepareProductImageUpload', 'completeProductImageUpload']);
    }
  });
  test(
      'rejects oversize files before calls and rejects forged upload endpoints',
      () async {
    final gateway = _Gateway();
    final functions = ProductImageFunctions(gateway);
    await expectLater(
        functions.upload('m', 'p', 'u', [], 'jpg'), throwsArgumentError);
    expect(gateway.calls, isEmpty);
    gateway.forged = true;
    await expectLater(
        functions.upload('m', 'p', 'u', [1], 'jpg'), throwsFormatException);
    expect(gateway.calls, ['prepareProductImageUpload']);
  });
}
