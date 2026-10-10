import 'package:flutter_test/flutter_test.dart';
import 'package:sarisupply_pos/features/catalog/product_photo_format.dart';

void main() {
  test('photo formats use contents and reject unsupported or animated files',
      () {
    expect(productPhotoFormat([255, 216, 255, 0]), 'jpg');
    expect(productPhotoFormat([137, 80, 78, 71, 13, 10, 26, 10]), 'png');
    expect(
        productPhotoFormat([
          137,
          80,
          78,
          71,
          13,
          10,
          26,
          10,
          0,
          0,
          0,
          0,
          97,
          99,
          84,
          76,
          0,
          0,
          0,
          0
        ]),
        isNull);
    final webp = [
      82,
      73,
      70,
      70,
      0,
      0,
      0,
      0,
      87,
      69,
      66,
      80,
      86,
      80,
      56,
      88,
      0,
      0,
      0,
      0,
      0
    ];
    expect(productPhotoFormat(webp), 'webp');
    webp[20] = 2;
    expect(productPhotoFormat(webp), isNull);
    expect(productPhotoFormat('GIF89a'.codeUnits), isNull);
    expect(productPhotoFormat([]), isNull);
  });
}
