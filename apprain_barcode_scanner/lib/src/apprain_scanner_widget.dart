import 'dart:async';
import 'dart:io';

import 'package:apprain_barcode_scanner/src/apprain_scanner_config.dart';
import 'package:apprain_barcode_scanner/src/apprain_scanner_controller.dart';
import 'package:apprain_barcode_scanner/src/presentation/focus_indicator.dart';
import 'package:apprain_barcode_scanner/src/presentation/scan_window_overlay.dart';
import 'package:apprain_barcode_scanner/src/presentation/scanner_overlay_painter.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Native barcode scanner widget backed by CameraX (Android) and
/// AVFoundation (iOS) via PlatformView.
///
/// Wraps the native camera preview and provides Flutter-side overlays
/// (scan window, focus indicator, custom top/bottom widgets).
///
/// Usage:
/// ```dart
/// ApprainScannerWidget(
///   controller: _scannerController,
///   config: ApprainScannerConfig(
///     scanWindowWidthRatio: 0.75,
///     scanWindowHeightRatio: 0.35,
///   ),
///   topWidget: Text('Scan your barcode'),
///   bottomWidget: ElevatedButton(onPressed: () {}, child: Text('Cancel')),
/// )
/// ```
class ApprainScannerWidget extends StatefulWidget {
  /// Creates an [ApprainScannerWidget] with the given [controller].
  const ApprainScannerWidget({
    required this.controller,
    this.config = const ApprainScannerConfig(),
    this.topWidget,
    this.bottomWidget,
    super.key,
  });

  /// The scanner controller managing the native camera and detection.
  final ApprainScannerController controller;

  /// Visual overlay configuration (scan window, borders, colors).
  final ApprainScannerConfig config;

  /// Widget placed above the camera preview (e.g. header).
  final Widget? topWidget;

  /// Widget placed below the camera preview (e.g. info card).
  final Widget? bottomWidget;

  @override
  State<ApprainScannerWidget> createState() => _ApprainScannerWidgetState();
}

class _ApprainScannerWidgetState extends State<ApprainScannerWidget>
    with SingleTickerProviderStateMixin {
  /// Focus indicator position notifier.
  final ValueNotifier<Offset?> _focusPoint = ValueNotifier<Offset?>(null);

  /// Focus ring animation controller.
  late final AnimationController _focusAnimController;

  /// Timer to hide focus indicator after a delay.
  Timer? _focusHideTimer;

  @override
  void initState() {
    super.initState();
    _focusAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
  }

  @override
  void dispose() {
    _focusHideTimer?.cancel();
    _focusPoint.dispose();
    _focusAnimController.dispose();
    super.dispose();
  }

  /// Handles tap-to-focus by sending normalized coordinates to native.
  Future<void> _handleTapToFocus(
    TapDownDetails details,
    Size previewSize,
  ) async {
    if (!widget.controller.isRunning) return;

    // Only respond to taps within the scan window area
    if (widget.config.showScanWindow) {
      final scanWindow = widget.config.calculateScanWindow(previewSize);
      if (!scanWindow.contains(details.localPosition)) return;
    }

    final normalizedX =
        (details.localPosition.dx / previewSize.width).clamp(0.0, 1.0);
    final normalizedY =
        (details.localPosition.dy / previewSize.height).clamp(0.0, 1.0);

    await widget.controller.setFocusPoint(normalizedX, normalizedY);

    // Show focus indicator with animation
    _focusPoint.value = details.localPosition;
    await _focusAnimController.forward(from: 0);

    _focusHideTimer?.cancel();
    _focusHideTimer = Timer(const Duration(milliseconds: 1200), () {
      if (mounted) _focusPoint.value = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final scanWindow = widget.config.showScanWindow
            ? widget.config.calculateScanWindow(constraints.biggest)
            : null;

        return Stack(
          alignment: widget.topWidget != null
              ? Alignment.topCenter
              : Alignment.bottomCenter,
          children: [
            // ── Native Camera Preview ──────────────────────────────
            GestureDetector(
              onTapDown: (details) =>
                  _handleTapToFocus(details, constraints.biggest),
              child: SizedBox.expand(
                child: _buildNativePlatformView(),
              ),
            ),

            // ── Scan Window Overlay ────────────────────────────────
            if (widget.config.showScanWindow && scanWindow != null)
              Positioned.fill(
                child: IgnorePointer(
                  child: ScanWindowOverlay(
                    scanWindow: scanWindow,
                    borderColor: widget.config.scanWindowBorderColor,
                    borderWidth: widget.config.scanWindowBorderWidth,
                    borderRadius: widget.config.scanWindowBorderRadius,
                    overlayColor: widget.config.scanWindowOverlayColor,
                    borderType: widget.config.scanWindowBorderType,
                    cornerLength: widget.config.scanWindowCornerLength,
                  ),
                ),
              ),

            // ── Barcode Bounding Box Overlay ───────────────────────
            Positioned.fill(
              child: IgnorePointer(
                child: ValueListenableBuilder<List<List<Offset>>>(
                  valueListenable: widget.controller.barcodeCorners,
                  builder: (context, cornersList, _) {
                    if (cornersList.isEmpty) {
                      return const SizedBox.shrink();
                    }
                    // Convert normalized (0-1) corners to pixel coords
                    final size = constraints.biggest;
                    final scaledCorners = cornersList.map((corners) {
                      return corners
                          .map(
                            (p) => Offset(
                              p.dx * size.width,
                              p.dy * size.height,
                            ),
                          )
                          .toList();
                    }).toList();
                    return CustomPaint(
                      painter: ScannerOverlayPainter(
                        barcodeCorners: scaledCorners,
                        boxColor: widget.config.barcodeOverlayColor,
                        borderType: widget.config.barcodeOverlayBorderType,
                        boxBorderWidth:
                            widget.config.barcodeOverlayBorderWidth,
                        cornerRadius:
                            widget.config.barcodeOverlayCornerRadius,
                        cornerLength:
                            widget.config.barcodeOverlayCornerLength,
                      ),
                    );
                  },
                ),
              ),
            ),

            // ── Focus Indicator ────────────────────────────────────
            ValueListenableBuilder<Offset?>(
              valueListenable: _focusPoint,
              builder: (context, point, child) {
                if (point == null) return const SizedBox.shrink();
                return FocusIndicator(
                  position: point,
                  animation: _focusAnimController,
                );
              },
            ),

            // ── Top Widget ─────────────────────────────────────────
            if (widget.topWidget != null) widget.topWidget!,

            // ── Bottom Widget ──────────────────────────────────────
            if (widget.bottomWidget != null)
              widget.topWidget != null
                  ? Positioned(
                      bottom: 0,
                      left: 0,
                      right: 0,
                      child: widget.bottomWidget!,
                    )
                  : widget.bottomWidget!,
          ],
        );
      },
    );
  }

  /// Creates the native platform view for the camera preview.
  Widget _buildNativePlatformView() {
    const viewType = 'com.apprain.barcode_scanner/scanner_view';
    final creationParams = widget.controller.config.toMap();

    if (Platform.isAndroid) {
      return AndroidView(
        viewType: viewType,
        creationParams: creationParams,
        creationParamsCodec: const StandardMessageCodec(),
      );
    } else if (Platform.isIOS) {
      return UiKitView(
        viewType: viewType,
        creationParams: creationParams,
        creationParamsCodec: const StandardMessageCodec(),
      );
    }

    return const Center(
      child: Text('Platform not supported'),
    );
  }
}
