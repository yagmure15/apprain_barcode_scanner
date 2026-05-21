import 'package:apprain_barcode_scanner/src/presentation/scan_window_overlay.dart';
import 'package:flutter/material.dart';

/// Draws perspective-aware polygons around detected barcodes.
///
/// Instead of axis-aligned rectangles, this painter uses the actual
/// four corner points of each barcode to draw polygons that follow
/// the barcode's perspective and rotation — matching what the user
/// sees through the camera at any angle.
///
/// Use [borderType] to select between full polygon border or
/// corner accent brackets.
class ScannerOverlayPainter extends CustomPainter {
  /// Creates a [ScannerOverlayPainter] with detected barcode corners.
  const ScannerOverlayPainter({
    this.barcodeCorners = const [],
    this.boxColor = const Color(0xFFFA8C16),
    this.boxBorderWidth = 3.0,
    this.cornerRadius = 6.0,
    this.cornerLength = 18.0,
    this.borderType = ScanWindowBorderType.corners,
  });

  /// List of detected barcodes, each represented by 4 corner `Offset` points.
  ///
  /// Order: [topLeft, topRight, bottomRight, bottomLeft].
  /// Coordinates should be in screen pixel space (already scaled).
  final List<List<Offset>> barcodeCorners;

  /// Color of the overlay border and fill.
  final Color boxColor;

  /// Border width of the polygon outline.
  final double boxBorderWidth;

  /// Radius for rounded corner markers.
  final double cornerRadius;

  /// Length of the corner bracket lines.
  final double cornerLength;

  /// Border type — [ScanWindowBorderType.box] draws full polygon border,
  /// [ScanWindowBorderType.corners] draws only corner brackets.
  final ScanWindowBorderType borderType;

  @override
  void paint(Canvas canvas, Size size) {
    if (barcodeCorners.isEmpty) return;

    final fillPaint = Paint()
      ..color = boxColor.withValues(alpha: 0.12)
      ..style = PaintingStyle.fill;

    final strokePaint = Paint()
      ..color = boxColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = boxBorderWidth
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final cornerPaint = Paint()
      ..color = boxColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = boxBorderWidth + 1.5
      ..strokeCap = StrokeCap.round;

    for (final corners in barcodeCorners) {
      if (corners.length != 4) continue;

      // Rounded or straight polygon path — also used for fill
      final path = cornerRadius > 0
          ? _buildRoundedPolygon(corners, cornerRadius)
          : (Path()
              ..moveTo(corners[0].dx, corners[0].dy)
              ..lineTo(corners[1].dx, corners[1].dy)
              ..lineTo(corners[2].dx, corners[2].dy)
              ..lineTo(corners[3].dx, corners[3].dy)
              ..close());

      canvas.drawPath(path, fillPaint);

      switch (borderType) {
        case ScanWindowBorderType.box:
          // Full polygon border (rounded or straight)
          canvas.drawPath(path, strokePaint);
        case ScanWindowBorderType.corners:
          // Corner brackets only
          _drawCornerBrackets(canvas, corners, cornerPaint);
      }
    }
  }

  /// Draws L-shaped bracket markers at each corner of the barcode.
  void _drawCornerBrackets(
    Canvas canvas,
    List<Offset> corners,
    Paint paint,
  ) {
    for (var i = 0; i < 4; i++) {
      final current = corners[i];
      final prev = corners[(i + 3) % 4]; // Previous corner
      final next = corners[(i + 1) % 4]; // Next corner

      // Direction vectors to adjacent corners (normalized + clamped)
      final toPrev = _clampedDirection(current, prev, cornerLength);
      final toNext = _clampedDirection(current, next, cornerLength);

      canvas
        ..drawLine(current, toPrev, paint)
        ..drawLine(current, toNext, paint);
    }
  }

  /// Returns a point at [maxLength] distance from [from] toward [to].
  Offset _clampedDirection(Offset from, Offset to, double maxLength) {
    final dx = to.dx - from.dx;
    final dy = to.dy - from.dy;
    final distance = Offset(dx, dy).distance;
    if (distance == 0) return from;

    final ratio = maxLength.clamp(0, distance) / distance;
    return Offset(from.dx + dx * ratio, from.dy + dy * ratio);
  }

  /// Builds a perspective-aware rounded polygon path.
  ///
  /// At each corner, moves inward along both adjacent edges by [radius]
  /// and uses `arcToPoint` for smooth transitions.
  Path _buildRoundedPolygon(List<Offset> corners, double radius) {
    final path = Path();
    final n = corners.length;

    for (var i = 0; i < n; i++) {
      final prev = corners[(i + n - 1) % n];
      final current = corners[i];
      final next = corners[(i + 1) % n];

      // Unit vectors toward adjacent corners
      final toPrev = prev - current;
      final toNext = next - current;
      final distPrev = toPrev.distance;
      final distNext = toNext.distance;

      // Clamp radius to half the shorter adjacent edge
      final r = radius.clamp(0.0, (distPrev / 2).clamp(0.0, distNext / 2));

      if (r <= 0 || distPrev == 0 || distNext == 0) {
        // No radius or degenerate edge — sharp corner
        if (i == 0) {
          path.moveTo(current.dx, current.dy);
        } else {
          path.lineTo(current.dx, current.dy);
        }
        continue;
      }

      // Arc start and end points
      final unitPrev = Offset(toPrev.dx / distPrev, toPrev.dy / distPrev);
      final unitNext = Offset(toNext.dx / distNext, toNext.dy / distNext);
      final arcStart = Offset(
        current.dx + unitPrev.dx * r,
        current.dy + unitPrev.dy * r,
      );
      final arcEnd = Offset(
        current.dx + unitNext.dx * r,
        current.dy + unitNext.dy * r,
      );

      if (i == 0) {
        path.moveTo(arcStart.dx, arcStart.dy);
      } else {
        path.lineTo(arcStart.dx, arcStart.dy);
      }

      path.arcToPoint(
        arcEnd,
        radius: Radius.circular(r),
        clockwise: false,
      );
    }

    path.close();
    return path;
  }

  @override
  bool shouldRepaint(ScannerOverlayPainter oldDelegate) =>
      barcodeCorners != oldDelegate.barcodeCorners ||
      boxColor != oldDelegate.boxColor ||
      boxBorderWidth != oldDelegate.boxBorderWidth ||
      cornerRadius != oldDelegate.cornerRadius ||
      cornerLength != oldDelegate.cornerLength ||
      borderType != oldDelegate.borderType;
}
