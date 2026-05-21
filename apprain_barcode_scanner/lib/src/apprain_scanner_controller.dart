import 'dart:async';
import 'dart:developer';
import 'dart:ui';

import 'package:apprain_barcode_scanner_platform_interface/apprain_barcode_scanner_platform_interface.dart';
import 'package:flutter/foundation.dart';

/// Controller for the Apprain native barcode scanner.
///
/// Manages the lifecycle of the native camera and barcode detection pipeline.
/// Provides control methods for torch, zoom, focus, and camera switching.
///
/// Usage:
/// ```dart
/// final controller = ApprainScannerController(
///   config: ScannerConfiguration(
///     allowedFormats: ['QR_CODE', 'CODE_128'],
///   ),
///   onDetect: (results) {
///     for (final result in results) {
///       print('Scanned: ${result.rawValue}');
///     }
///   },
/// );
///
/// await controller.initialize();
/// await controller.start();
/// // ...
/// await controller.dispose();
/// ```
class ApprainScannerController {
  /// Creates an [ApprainScannerController] with the given configuration.
  ApprainScannerController({
    ScannerConfiguration config = const ScannerConfiguration(),
    this.onDetect,
    this.onError,
    this.enableDuplicateFilter = true,
  }) : _config = config;

  /// The scanner configuration.
  ScannerConfiguration _config;

  /// Called when new barcodes are detected.
  ///
  /// Returns raw [NativeScanResult] list — parse/transform as needed.
  /// Duplicate scan protection is applied if [enableDuplicateFilter] is true.
  final void Function(List<NativeScanResult> results)? onDetect;

  /// Called when the camera encounters an error.
  final void Function(String message)? onError;

  /// Whether to filter out duplicate scans of the same barcode value.
  final bool enableDuplicateFilter;

  /// The set of already scanned values for duplicate filtering.
  final Set<String> _scannedValues = {};

  /// Platform implementation reference.
  ApprainBarcodeScannerPlatform get _platform =>
      ApprainBarcodeScannerPlatform.instance;

  /// Subscription to scan results from native.
  StreamSubscription<List<NativeScanResult>>? _scanSubscription;

  /// Subscription to camera events from native.
  StreamSubscription<CameraEvent>? _cameraSubscription;

  /// Whether the controller has been initialized.
  bool _isInitialized = false;

  /// Whether the camera is currently running.
  bool _isRunning = false;

  /// Whether the controller has been initialized.
  bool get isInitialized => _isInitialized;

  /// Whether the camera is currently running.
  bool get isRunning => _isRunning;

  /// Whether the front camera is currently active.
  bool get isFrontCamera => _config.useFrontCamera;

  /// The current scanner configuration.
  ScannerConfiguration get config => _config;

  /// Notifier for detected barcode corner points (normalized 0-1 coords).
  ///
  /// Each entry is a list of 4 `Offset` points representing the corners
  /// of a detected barcode: [topLeft, topRight, bottomRight, bottomLeft].
  /// Used by `ApprainScannerWidget` to draw perspective-aware polygon
  /// overlays.
  final ValueNotifier<List<List<Offset>>> barcodeCorners =
      ValueNotifier<List<List<Offset>>>([]);

  /// Initializes the native scanner with the current configuration.
  ///
  /// Must be called before [start].
  ///
  /// Retries initialization up to 10 times to handle the
  /// race condition where the PlatformView may not yet be registered when
  /// the MethodChannel call arrives.
  Future<void> initialize() async {
    if (_isInitialized) return;

    const maxRetries = 10;
    const retryDelay = Duration(milliseconds: 100);

    for (var attempt = 1; attempt <= maxRetries; attempt++) {
      try {
        await _platform.initialize(_config);
        break; // Success — exit retry loop
      } catch (e) {
        if (attempt == maxRetries) rethrow;
        log(
          '📷 Initialize attempt $attempt/$maxRetries failed, '
          'retrying in ${retryDelay.inMilliseconds}ms...',
        );
        await Future<void>.delayed(retryDelay);
      }
    }

    // Listen to scan results
    _scanSubscription = _platform.scanResults.listen(_handleScanResults);

    // Listen to camera events
    _cameraSubscription = _platform.cameraEvents.listen(_handleCameraEvent);

    _isInitialized = true;
    log('📷 ApprainScannerController initialized.');
  }

  /// Starts the camera preview and barcode detection.
  Future<void> start() async {
    if (!_isInitialized) await initialize();
    if (_isRunning) return;

    await _platform.startCamera();
    _isRunning = true;
    log('📷 ApprainScannerController started.');
  }

  /// Stops the camera preview and barcode detection.
  Future<void> stop() async {
    if (!_isRunning) return;

    await _platform.stopCamera();
    _isRunning = false;
    log('📷 ApprainScannerController stopped.');
  }

  /// Disposes all resources.
  ///
  /// The controller cannot be used after this call.
  Future<void> dispose() async {
    await _scanSubscription?.cancel();
    _scanSubscription = null;
    await _cameraSubscription?.cancel();
    _cameraSubscription = null;

    if (_isInitialized) {
      await _platform.dispose();
    }

    _isInitialized = false;
    _isRunning = false;
    _scannedValues.clear();
    log('📷 ApprainScannerController disposed.');
  }

  /// Toggles the flashlight/torch.
  Future<void> setTorch({required bool enabled}) async {
    await _platform.setTorch(enabled: enabled);
  }

  /// Sets the camera zoom level (0.0 – 1.0).
  Future<void> setZoom(double level) async {
    await _platform.setZoom(level);
  }

  /// Sets the camera focus point (normalized 0.0 – 1.0 coordinates).
  Future<void> setFocusPoint(double x, double y) async {
    await _platform.setFocusPoint(x, y);
  }

  /// Switches between front and back cameras.
  Future<void> switchCamera() async {
    _config = _config.copyWith(useFrontCamera: !_config.useFrontCamera);
    await _platform.switchCamera();
  }

  /// Updates the scanner configuration while running.
  Future<void> updateConfig(ScannerConfiguration config) async {
    _config = config;
    await _platform.updateConfig(config);
  }

  /// Clears the duplicate scan filter — allows re-scanning of same values.
  void resetScannedValues() {
    _scannedValues.clear();
  }

  // ── Private Handlers ───────────────────────────────────────────────────

  void _handleScanResults(List<NativeScanResult> results) {
    // Update corner points for polygon overlay
    final allCorners = <List<Offset>>[];
    for (final result in results) {
      final parsed = result.cornerOffsets;
      if (parsed.length == 4) {
        allCorners.add(parsed);
      }
    }
    barcodeCorners.value = allCorners;

    log(
      '📷 BarcodeCorners updated: ${allCorners.length} barcodes'
      '${allCorners.isNotEmpty ? " → ${allCorners.first}" : ""}',
    );

    // Apply duplicate filter and notify
    if (enableDuplicateFilter) {
      final filtered = results.where((r) => _scannedValues.add(r.rawValue));
      if (filtered.isNotEmpty) {
        for (final result in filtered) {
          log(
            '📷 ApprainScanner detected: ${result.rawValue} '
            '(format: ${result.format}, confidence: ${result.confidence})',
          );
        }
        onDetect?.call(filtered.toList());
      }
    } else {
      for (final result in results) {
        log(
          '📷 ApprainScanner detected: ${result.rawValue} '
          '(format: ${result.format}, confidence: ${result.confidence})',
        );
      }
      onDetect?.call(results);
    }
  }

  void _handleCameraEvent(CameraEvent event) {
    switch (event) {
      case CameraReadyEvent():
        log('📷 Camera ready.');
      case CameraErrorEvent(:final message):
        log('📷 Camera error: $message');
        onError?.call(message);
    }
  }
}
