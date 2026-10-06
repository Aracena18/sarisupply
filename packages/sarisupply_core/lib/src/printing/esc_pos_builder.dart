import 'dart:convert';
import 'dart:typed_data';

enum EscPosAlign { left, center, right }

enum EscPosPaperSize {
  mm58(32),
  mm80(42);

  const EscPosPaperSize(this.columns);
  final int columns;
}

class EscPosBuilder {
  EscPosBuilder({this.paperSize = EscPosPaperSize.mm58}) {
    init();
  }

  final EscPosPaperSize paperSize;
  final List<int> _bytes = [];

  int get maxColumns => paperSize.columns;

  /// Resets printer settings to default (ESC @).
  EscPosBuilder init() {
    _bytes.addAll([0x1B, 0x40]);
    return this;
  }

  /// Sets text alignment (ESC a n).
  EscPosBuilder align(EscPosAlign alignment) {
    final int val;
    switch (alignment) {
      case EscPosAlign.left:
        val = 0;
        break;
      case EscPosAlign.center:
        val = 1;
        break;
      case EscPosAlign.right:
        val = 2;
        break;
    }
    _bytes.addAll([0x1B, 0x61, val]);
    return this;
  }

  /// Enables or disables bold text (ESC E n).
  EscPosBuilder bold(bool enabled) {
    _bytes.addAll([0x1B, 0x45, enabled ? 1 : 0]);
    return this;
  }

  /// Enables or disables underline (ESC - n).
  EscPosBuilder underline(bool enabled) {
    _bytes.addAll([0x1B, 0x2D, enabled ? 1 : 0]);
    return this;
  }

  /// Enables or disables double height (GS ! n).
  EscPosBuilder doubleHeight(bool enabled) {
    _bytes.addAll([0x1D, 0x21, enabled ? 0x01 : 0x00]);
    return this;
  }

  /// Writes text bytes without trailing newline.
  EscPosBuilder text(
    String content, {
    EscPosAlign? alignment,
    bool bold = false,
    bool doubleHeight = false,
  }) {
    if (alignment != null) align(alignment);
    if (bold) this.bold(true);
    if (doubleHeight) this.doubleHeight(true);

    _bytes.addAll(utf8.encode(content));

    if (doubleHeight) this.doubleHeight(false);
    if (bold) this.bold(false);
    if (alignment != null) align(EscPosAlign.left);
    return this;
  }

  /// Writes a complete line of text followed by newline (0x0A).
  EscPosBuilder textLine(
    String content, {
    EscPosAlign? alignment,
    bool bold = false,
    bool doubleHeight = false,
  }) {
    text(content, alignment: alignment, bold: bold, doubleHeight: doubleHeight);
    _bytes.add(0x0A);
    return this;
  }

  /// Justifies two columns (e.g. Item name on left, Price on right).
  EscPosBuilder twoColumns(
    String left,
    String right, {
    bool bold = false,
  }) {
    final totalWidth = maxColumns;
    final availableLeft = totalWidth - right.length - 1;

    String cleanLeft = left;
    if (cleanLeft.length > availableLeft && availableLeft > 0) {
      cleanLeft = '${cleanLeft.substring(0, availableLeft - 1)}…';
    }

    final spaceCount = totalWidth - (cleanLeft.length + right.length);
    final spaces = spaceCount > 0 ? ' ' * spaceCount : ' ';
    final line = '$cleanLeft$spaces$right';

    return textLine(line, bold: bold);
  }

  /// Prints a horizontal divider line of specified character.
  EscPosBuilder hr({String char = '-'}) {
    return textLine(char * maxColumns);
  }

  /// Feeds [lines] paper lines (ESC d n).
  EscPosBuilder feed([int lines = 1]) {
    _bytes.addAll([0x1B, 0x64, lines]);
    return this;
  }

  /// Cuts paper (feed lines + GS V m).
  EscPosBuilder cut({bool partial = false}) {
    feed(3);
    _bytes.addAll([0x1D, 0x56, partial ? 0x01 : 0x00]);
    return this;
  }

  /// Sends electrical pulse to open connected cash drawer (ESC p m t1 t2).
  EscPosBuilder kickDrawer() {
    _bytes.addAll([0x1B, 0x70, 0x00, 0x19, 0xFA]);
    return this;
  }

  /// Returns compiled byte array.
  Uint8List toBytes() {
    return Uint8List.fromList(_bytes);
  }
}
