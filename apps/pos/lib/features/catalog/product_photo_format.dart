/// Recognize supported file contents, not the user-controlled filename.
String? productPhotoFormat(List<int> bytes) {
  bool matches(int start, List<int> signature) =>
      bytes.length >= start + signature.length &&
      List.generate(signature.length, (i) => bytes[start + i] == signature[i])
          .every((b) => b);
  if (matches(0, [0xff, 0xd8, 0xff])) return 'jpg';
  if (matches(0, [137, 80, 78, 71, 13, 10, 26, 10])) {
    // Reject APNG animation control chunks before preview/upload.
    var offset = 8;
    while (offset + 12 <= bytes.length) {
      final length = (bytes[offset] << 24) |
          (bytes[offset + 1] << 16) |
          (bytes[offset + 2] << 8) |
          bytes[offset + 3];
      if (matches(offset + 4, [97, 99, 84, 76])) return null;
      offset += length + 12;
    }
    return 'png';
  }
  if (matches(0, [82, 73, 70, 70]) && matches(8, [87, 69, 66, 80])) {
    if (matches(12, [86, 80, 56, 88]) &&
        bytes.length > 20 &&
        bytes[20] & 2 != 0) {
      return null;
    }
    return 'webp';
  }
  return null;
}
