import 'package:apprain_barcode_scanner/src/presentation/scan_window_overlay.dart';
import 'package:flutter/material.dart';

/// Visual configuration for the scanner widget overlay.
///
/// Controls scan window appearance, barcode overlay styling,
/// and overlay timeout behavior.
class ApprainScannerConfig {
  /// Creates an [ApprainScannerConfig] with the given visual overlay settings.
  const ApprainScannerConfig({
    this.scanWindowWidthRatio = _defaultScanWindowWidthRatio,
    this.scanWindowHeightRatio = _defaultScanWindowHeightRatio,
    this.scanWindowVerticalOffsetRatio = _defaultVerticalOffsetRatio,
    this.showScanWindow = true,
    this.showBarcodeOverlay = true,
    this.overlayTimeout = _defaultOverlayTimeout,
    this.scanWindowBorderType = ScanWindowBorderType.corners,
    this.scanWindowBorderWidth = _defaultBorderWidth,
    this.scanWindowBorderRadius = _defaultBorderRadius,
    this.scanWindowBorderColor = _defaultBorderColor,
    this.scanWindowOverlayColor = _defaultOverlayColor,
    this.scanWindowCornerLength = _defaultCornerLength,
    this.barcodeOverlayColor = _defaultBarcodeOverlayColor,
    this.barcodeOverlayBorderType = ScanWindowBorderType.corners,
    this.barcodeOverlayBorderWidth = _defaultBarcodeOverlayBorderWidth,
    this.barcodeOverlayCornerRadius = _defaultBarcodeOverlayCornerRadius,
    this.barcodeOverlayCornerLength = _defaultBarcodeOverlayCornerLength,
  });

  // ── Scan Window ──────────────────────────────────────────────

  /// Scan window width ratio relative to screen width.
  final double scanWindowWidthRatio;

  /// Scan window height ratio relative to screen height.
  final double scanWindowHeightRatio;

  /// Vertical offset of scan window center from screen center.
  final double scanWindowVerticalOffsetRatio;

  /// Whether to show the scan window overlay (dimmed area).
  final bool showScanWindow;

  /// Scan window border type — full box or corner accents only.
  final ScanWindowBorderType scanWindowBorderType;

  /// Scan window border width.
  final double scanWindowBorderWidth;

  /// Scan window corner radius.
  final BorderRadius scanWindowBorderRadius;

  /// Scan window border color.
  final Color scanWindowBorderColor;

  /// Dimmed overlay color outside the scan window.
  final Color scanWindowOverlayColor;

  /// Corner accent length in [ScanWindowBorderType.corners] mode.
  ///
  /// Ignored in [ScanWindowBorderType.box] mode.
  final double scanWindowCornerLength;

  // ── Barcode Overlay ──────────────────────────────────────────

  /// Whether to show the barcode bounding box overlay.
  final bool showBarcodeOverlay;

  /// Duration before barcode overlay fades after barcode disappears.
  final Duration overlayTimeout;

  /// Color of the barcode bounding box.
  final Color barcodeOverlayColor;

  /// Barcode overlay border type — full box or corner accents only.
  final ScanWindowBorderType barcodeOverlayBorderType;

  /// Barcode overlay border width.
  final double barcodeOverlayBorderWidth;

  /// Barcode overlay corner radius.
  ///
  /// Applied to the perspective-aware polygon.
  final double barcodeOverlayCornerRadius;

  /// Corner accent length in [ScanWindowBorderType.corners] mode for barcode.
  final double barcodeOverlayCornerLength;

  // ── Defaults ──────────────────────────────────────────────────

  static const double _defaultScanWindowWidthRatio = 0.75;
  static const double _defaultScanWindowHeightRatio = 0.35;
  static const double _defaultVerticalOffsetRatio = 0.10;
  static const double _defaultBorderWidth = 2.5;
  static const double _defaultCornerLength = 28;
  static const Duration _defaultOverlayTimeout = Duration(milliseconds: 300);
  static const BorderRadius _defaultBorderRadius =
      BorderRadius.all(Radius.circular(16));
  static const Color _defaultBorderColor = Color.fromARGB(255, 255, 255, 255);
  static const Color _defaultOverlayColor = Color.fromARGB(255, 255, 255, 255);
  static const Color _defaultBarcodeOverlayColor = Color(0xFFFA8C16);
  static const double _defaultBarcodeOverlayBorderWidth = 3;
  static const double _defaultBarcodeOverlayCornerRadius = 6;
  static const double _defaultBarcodeOverlayCornerLength = 18;

  /// Calculates the scan window rect for the given [size].
  Rect calculateScanWindow(Size size) {
    final scanWindowWidth = size.width * scanWindowWidthRatio;
    final scanWindowHeight = size.height * scanWindowHeightRatio;
    final verticalOffset = size.height * scanWindowVerticalOffsetRatio;

    return Rect.fromCenter(
      center: size.center(Offset(0, -verticalOffset)),
      width: scanWindowWidth,
      height: scanWindowHeight,
    );
  }
}
