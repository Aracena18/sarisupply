import 'package:sarisupply_design_system/sarisupply_design_system.dart';
import 'package:flutter/material.dart';

/// Touch signature capture canvas that converts finger strokes to SVG path data.
/// Works 100% offline without image files or cloud storage dependencies.
class SignaturePad extends StatefulWidget {
  const SignaturePad({
    super.key,
    required this.onChanged,
    this.height = 180,
  });

  final ValueChanged<String?> onChanged;
  final double height;

  @override
  State<SignaturePad> createState() => _SignaturePadState();
}

class _SignaturePadState extends State<SignaturePad> {
  final List<Offset?> _points = [];

  void _addPoint(Offset? point) {
    setState(() {
      _points.add(point);
    });
    _notify();
  }

  void _clear() {
    setState(() {
      _points.clear();
    });
    widget.onChanged(null);
  }

  void _notify() {
    final validPoints = _points.whereType<Offset>().toList();
    if (validPoints.length < 5) {
      widget.onChanged(null);
      return;
    }
    widget.onChanged(_serializeSvgPath(_points));
  }

  static String _serializeSvgPath(List<Offset?> points) {
    if (points.isEmpty) return '';
    final buffer = StringBuffer();
    bool isNewStroke = true;
    for (final pt in points) {
      if (pt == null) {
        isNewStroke = true;
      } else {
        if (isNewStroke) {
          buffer.write(
              'M ${pt.dx.toStringAsFixed(1)} ${pt.dy.toStringAsFixed(1)} ');
          isNewStroke = false;
        } else {
          buffer.write(
              'L ${pt.dx.toStringAsFixed(1)} ${pt.dy.toStringAsFixed(1)} ');
        }
      }
    }
    return buffer.toString().trim();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasPoints = _points.whereType<Offset>().isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Recipient Signature',
              style: theme.textTheme.titleSmall
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            if (hasPoints)
              TextButton.icon(
                onPressed: _clear,
                icon: const Icon(Icons.clear, size: 16),
                label: const Text('Clear'),
                style: TextButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  foregroundColor: theme.colorScheme.error,
                ),
              ),
          ],
        ),
        const SizedBox(height: 6),
        Container(
          height: widget.height,
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(SariSupplyRadii.sm),
            border: Border.all(
              color: hasPoints
                  ? theme.colorScheme.primary
                  : theme.colorScheme.outlineVariant,
              width: hasPoints ? 1.5 : 1.0,
            ),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(SariSupplyRadii.sm),
            child: Stack(
              children: [
                Positioned.fill(
                  child: CustomPaint(
                    painter: _SignatureCanvasPainter(
                        _points, theme.colorScheme.onSurface),
                  ),
                ),
                GestureDetector(
                  onPanStart: (details) => _addPoint(details.localPosition),
                  onPanUpdate: (details) => _addPoint(details.localPosition),
                  onPanEnd: (_) => _addPoint(null),
                ),
                if (!hasPoints)
                  Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.draw_outlined,
                            color: theme.colorScheme.outline, size: 28),
                        const SizedBox(height: 4),
                        Text(
                          'Sign here with finger or stylus',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.outline,
                          ),
                        ),
                      ],
                    ),
                  ),
                Positioned(
                  left: 16,
                  right: 16,
                  bottom: 28,
                  child: IgnorePointer(
                    child: Container(
                      height: 1,
                      color: theme.colorScheme.outlineVariant
                          .withValues(alpha: 0.5),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _SignatureCanvasPainter extends CustomPainter {
  _SignatureCanvasPainter(this.points, this.color);

  final List<Offset?> points;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke;

    for (int i = 0; i < points.length - 1; i++) {
      final p1 = points[i];
      final p2 = points[i + 1];
      if (p1 != null && p2 != null) {
        canvas.drawLine(p1, p2, paint);
      }
    }
  }

  @override
  bool shouldRepaint(_SignatureCanvasPainter oldDelegate) => true;
}
