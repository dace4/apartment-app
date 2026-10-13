import 'package:flutter/material.dart';

import '../../../models/signature_drawing.dart';
import '../../../models/signature_point.dart';

/// US-11: pointer input is translated into normalized model coordinates.
class SignaturePad extends StatelessWidget {
  const SignaturePad({
    super.key,
    required this.drawing,
    this.onStart,
    this.onUpdate,
    this.enabled = true,
  });
  final SignatureDrawing drawing;
  final ValueChanged<SignaturePoint>? onStart;
  final ValueChanged<SignaturePoint>? onUpdate;
  final bool enabled;

  @override
  Widget build(BuildContext context) => Semantics(
    label: enabled
        ? 'Signature drawing area. Draw with your finger or stylus.'
        : 'Saved handwritten signature',
    child: AspectRatio(
      aspectRatio: 2,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          border: Border.all(color: Theme.of(context).colorScheme.outline),
          borderRadius: BorderRadius.circular(12),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: LayoutBuilder(
            builder: (context, constraints) {
              SignaturePoint point(Offset offset) => SignaturePoint(
                (offset.dx / constraints.maxWidth).clamp(0, 1).toDouble(),
                (offset.dy / constraints.maxHeight).clamp(0, 1).toDouble(),
              );
              return GestureDetector(
                behavior: HitTestBehavior.opaque,
                onPanStart: enabled
                    ? (details) => onStart?.call(point(details.localPosition))
                    : null,
                onPanUpdate: enabled
                    ? (details) => onUpdate?.call(point(details.localPosition))
                    : null,
                child: CustomPaint(
                  painter: _SignaturePainter(
                    drawing,
                    Theme.of(context).colorScheme.onSurface,
                  ),
                ),
              );
            },
          ),
        ),
      ),
    ),
  );
}

class _SignaturePainter extends CustomPainter {
  _SignaturePainter(this.drawing, this.color);
  final SignatureDrawing drawing;
  final Color color;
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;
    for (final stroke in drawing.strokes) {
      if (stroke.isEmpty) continue;
      final path = Path()
        ..moveTo(stroke.first.x * size.width, stroke.first.y * size.height);
      for (final point in stroke.skip(1)) {
        path.lineTo(point.x * size.width, point.y * size.height);
      }
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(_SignaturePainter oldDelegate) =>
      drawing != oldDelegate.drawing || color != oldDelegate.color;
}
