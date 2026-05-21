import 'dart:math';

import 'package:flutter/material.dart';

/// Scan window border type.
///
/// [box] — Full box border (RRect stroke).
/// [corners] — Only short accent lines at each corner.
enum ScanWindowBorderType {
  /// Draws a full rounded rectangle border.
  box,

  /// Draws short accent lines at each corner only.
  corners,
}

/// Semi-transparent overlay that dims everything outside the scan window.
///
/// Based on [borderType], draws either a full box border or
/// corner accent lines — not both at the same time.
class ScanWindowOverlay extends StatelessWidget {
  /// Creates a [ScanWindowOverlay] with the given window and styling.
  const ScanWindowOverlay({
    required this.scanWindow,
    required this.borderColor,
    required this.borderWidth,
    required this.borderRadius,
    required this.overlayColor,
    this.borderType = ScanWindowBorderType.corners,
    this.cornerLength = 28.0,
    super.key,
  });

  /// The scan window rectangle in local coordinates.
  final Rect scanWindow;

  /// Border color around the scan window.
  final Color borderColor;

  /// Border width around the scan window.
  final double borderWidth;

  /// Border radius of the scan window corners.
  final BorderRadius borderRadius;

  /// Color of the dimmed area outside the scan window.
  final Color overlayColor;

  /// Border type — [ScanWindowBorderType.box] or
  /// [ScanWindowBorderType.corners].
  final ScanWindowBorderType borderType;

  /// Corner accent line length in [ScanWindowBorderType.corners] mode.
  ///
  /// Ignored in [ScanWindowBorderType.box] mode.
  final double cornerLength;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _ScanWindowPainter(
        scanWindow: scanWindow,
        borderColor: borderColor,
        borderWidth: borderWidth,
        borderRadius: borderRadius,
        overlayColor: overlayColor,
        borderType: borderType,
        cornerLength: cornerLength,
      ),
    );
  }
}

class _ScanWindowPainter extends CustomPainter {
  _ScanWindowPainter({
    required this.scanWindow,
    required this.borderColor,
    required this.borderWidth,
    required this.borderRadius,
    required this.overlayColor,
    required this.borderType,
    required this.cornerLength,
  });

  final Rect scanWindow;
  final Color borderColor;
  final double borderWidth;
  final BorderRadius borderRadius;
  final Color overlayColor;
  final ScanWindowBorderType borderType;
  final double cornerLength;

  @override
  void paint(Canvas canvas, Size size) {
    final fullRect = Offset.zero & size;

    // Create the scan window rounded rect
    final rrect = borderRadius.toRRect(scanWindow);

    // Draw dimmed overlay with a hole for the scan window
    final overlayPaint = Paint()
      ..color = overlayColor
      ..style = PaintingStyle.fill;

    final path = Path()
      ..addRect(fullRect)
      ..addRRect(rrect)
      ..fillType = PathFillType.evenOdd;

    canvas.drawPath(path, overlayPaint);

    // Draw border based on type
    switch (borderType) {
      case ScanWindowBorderType.box:
        _drawBoxBorder(canvas, rrect);
      case ScanWindowBorderType.corners:
        _drawCornerAccents(canvas, rrect);
    }
  }

  /// Draws a full box border — RRect stroke.
  void _drawBoxBorder(Canvas canvas, RRect rrect) {
    final borderPaint = Paint()
      ..color = borderColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = borderWidth;

    canvas.drawRRect(rrect, borderPaint);
  }

  /// Draws short accent lines at each corner.
  ///
  /// Each corner consists of a radius-aware arc followed by straight lines.
  /// This ensures `borderRadius` is correctly applied in both box and
  /// corners modes.
  void _drawCornerAccents(Canvas canvas, RRect rrect) {
    final accentPaint = Paint()
      ..color = borderColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = borderWidth
      ..strokeCap = StrokeCap.round;

    // Get radius values for each corner
    final tlRadius = rrect.tlRadius;
    final trRadius = rrect.trRadius;
    final brRadius = rrect.brRadius;
    final blRadius = rrect.blRadius;

    // Clamp corner length to half the smaller dimension
    final maxHorizontal = (rrect.width / 2).abs();
    final maxVertical = (rrect.height / 2).abs();
    final clampedLength = min(cornerLength, min(maxHorizontal, maxVertical));

    // ── Top-Left ──────────────────────────────────────────────
    _drawCorner(
      canvas: canvas,
      paint: accentPaint,
      cornerPoint: Offset(rrect.left, rrect.top),
      radius: tlRadius,
      length: clampedLength,
      horizontalDir: 1, // right
      verticalDir: 1, // down
    );

    // ── Top-Right ─────────────────────────────────────────────
    _drawCorner(
      canvas: canvas,
      paint: accentPaint,
      cornerPoint: Offset(rrect.right, rrect.top),
      radius: trRadius,
      length: clampedLength,
      horizontalDir: -1, // left
      verticalDir: 1, // down
    );

    // ── Bottom-Right ──────────────────────────────────────────
    _drawCorner(
      canvas: canvas,
      paint: accentPaint,
      cornerPoint: Offset(rrect.right, rrect.bottom),
      radius: brRadius,
      length: clampedLength,
      horizontalDir: -1, // left
      verticalDir: -1, // up
    );

    // ── Bottom-Left ───────────────────────────────────────────
    _drawCorner(
      canvas: canvas,
      paint: accentPaint,
      cornerPoint: Offset(rrect.left, rrect.bottom),
      radius: blRadius,
      length: clampedLength,
      horizontalDir: 1, // right
      verticalDir: -1, // up
    );
  }

  /// Draws a single corner accent.
  ///
  /// [cornerPoint]: Corner point (e.g. rrect.left, rrect.top).
  /// [radius]: Radius at this corner.
  /// [length]: Total accent length (arc + straight line combined).
  /// [horizontalDir]: Horizontal direction (1 = right, -1 = left).
  /// [verticalDir]: Vertical direction (1 = down, -1 = up).
  void _drawCorner({
    required Canvas canvas,
    required Paint paint,
    required Offset cornerPoint,
    required Radius radius,
    required double length,
    required int horizontalDir,
    required int verticalDir,
  }) {
    final r = min(radius.x, radius.y);

    if (r <= 0) {
      // No radius — draw straight lines
      final path = Path()
        ..moveTo(
          cornerPoint.dx,
          cornerPoint.dy + verticalDir * length,
        )
        ..lineTo(cornerPoint.dx, cornerPoint.dy)
        ..lineTo(
          cornerPoint.dx + horizontalDir * length,
          cornerPoint.dy,
        );
      canvas.drawPath(path, paint);
      return;
    }

    // Calculate arc start angle and straight line length
    final straightLength = max(0, length - r);

    // Vertical arm: straight line + arc
    final verticalPath = Path();
    // Starting point of the straight vertical line
    final vStart = Offset(
      cornerPoint.dx,
      cornerPoint.dy + verticalDir * length,
    );
    // End point of straight line (arc start)
    final vEnd = Offset(
      cornerPoint.dx,
      cornerPoint.dy + verticalDir * r,
    );

    verticalPath.moveTo(vStart.dx, vStart.dy);
    if (straightLength > 0) {
      verticalPath.lineTo(vEnd.dx, vEnd.dy);
    }

    // Arc: from vertical arm to horizontal arm
    final arcRect = Rect.fromLTWH(
      horizontalDir > 0 ? cornerPoint.dx : cornerPoint.dx - 2 * r,
      verticalDir > 0 ? cornerPoint.dy : cornerPoint.dy - 2 * r,
      2 * r,
      2 * r,
    );

    // Determine start angle:
    // horizontalDir > 0 (going right) → arc from left side of circle (180°)
    // horizontalDir < 0 (going left) → arc from right side of circle (0°)
    final startAngle = horizontalDir > 0 ? pi : 0.0;

    // Sweep direction:
    // h and v same sign → clockwise (+π/2)
    // h and v opposite sign → counter-clockwise (−π/2)
    final sweepAngle = (horizontalDir * verticalDir > 0) ? pi / 2 : -pi / 2;

    verticalPath.arcTo(arcRect, startAngle, sweepAngle, straightLength <= 0);

    // Horizontal straight line
    final hEnd = Offset(
      cornerPoint.dx + horizontalDir * length,
      cornerPoint.dy,
    );

    if (straightLength > 0) {
      verticalPath.lineTo(hEnd.dx, hEnd.dy);
    }

    canvas.drawPath(verticalPath, paint);
  }

  @override
  bool shouldRepaint(_ScanWindowPainter oldDelegate) =>
      scanWindow != oldDelegate.scanWindow ||
      borderColor != oldDelegate.borderColor ||
      borderWidth != oldDelegate.borderWidth ||
      borderRadius != oldDelegate.borderRadius ||
      overlayColor != oldDelegate.overlayColor ||
      borderType != oldDelegate.borderType ||
      cornerLength != oldDelegate.cornerLength;
}
