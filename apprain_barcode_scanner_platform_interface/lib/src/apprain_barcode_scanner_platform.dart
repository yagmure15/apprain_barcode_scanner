import 'package:apprain_barcode_scanner_platform_interface/apprain_barcode_scanner_platform_interface.dart';
import 'package:flutter/services.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

/// The interface that implementations of apprain_barcode_scanner must implement.
///
/// Platform implementations should extend this class rather than
/// implement it, as `implements` does not consider newly added
/// methods to be breaking changes.
abstract class ApprainBarcodeScannerPlatform extends PlatformInterface {
  /// Creates a [ApprainBarcodeScannerPlatform] instance.
  ApprainBarcodeScannerPlatform() : super(token: _token);

  static final Object _token = Object();

  static ApprainBarcodeScannerPlatform _instance =
      _DefaultApprainBarcodeScannerPlatform();

  /// The default instance of [ApprainBarcodeScannerPlatform] to use.
  static ApprainBarcodeScannerPlatform get instance => _instance;

  /// Platform-specific implementations should set this with their own
  /// platform-specific class that extends [ApprainBarcodeScannerPlatform].
  static set instance(ApprainBarcodeScannerPlatform instance) {
    PlatformInterface.verify(instance, _token);
    _instance = instance;
  }

  /// Creates the native platform view.
  ///
  /// Returns a widget creation params map suitable for
  /// `AndroidView` or `UiKitView`.
  Future<void> initialize(ScannerConfiguration config) {
    throw UnimplementedError('initialize() has not been implemented.');
  }

  /// Starts the camera preview and barcode detection.
  Future<void> startCamera() {
    throw UnimplementedError('startCamera() has not been implemented.');
  }

  /// Stops the camera preview and barcode detection.
  Future<void> stopCamera() {
    throw UnimplementedError('stopCamera() has not been implemented.');
  }

  /// Disposes all native resources.
  Future<void> dispose() {
    throw UnimplementedError('dispose() has not been implemented.');
  }

  /// Toggles the flashlight/torch.
  Future<void> setTorch({required bool enabled}) {
    throw UnimplementedError('setTorch() has not been implemented.');
  }

  /// Sets the camera zoom level (0.0 – 1.0).
  Future<void> setZoom(double zoomLevel) {
    throw UnimplementedError('setZoom() has not been implemented.');
  }

  /// Sets the camera focus point (normalized 0.0 – 1.0 coordinates).
  Future<void> setFocusPoint(double x, double y) {
    throw UnimplementedError('setFocusPoint() has not been implemented.');
  }

  /// Switches between front and back cameras.
  Future<void> switchCamera() {
    throw UnimplementedError('switchCamera() has not been implemented.');
  }

  /// Updates the scanner configuration while running.
  Future<void> updateConfig(ScannerConfiguration config) {
    throw UnimplementedError('updateConfig() has not been implemented.');
  }

  /// Stream of barcode scan results from the native detector.
  Stream<List<NativeScanResult>> get scanResults {
    throw UnimplementedError('scanResults has not been implemented.');
  }

  /// Stream of camera lifecycle events (ready, error, etc.).
  Stream<CameraEvent> get cameraEvents {
    throw UnimplementedError('cameraEvents has not been implemented.');
  }

  /// The view type identifier used for PlatformView registration.
  String get viewType => 'com.apprain.barcode_scanner/scanner_view';
}

/// Camera lifecycle events.
sealed class CameraEvent {
  const CameraEvent();
}

/// Emitted when the camera is ready and streaming.
class CameraReadyEvent extends CameraEvent {
  /// Creates a [CameraReadyEvent].
  const CameraReadyEvent();
}

/// Emitted when the camera encountered an error.
class CameraErrorEvent extends CameraEvent {
  /// Creates a [CameraErrorEvent] with the given [message].
  const CameraErrorEvent(this.message);

  /// Error description.
  final String message;
}

// ─────────────────────────────────────────────────────────────────────────────
// Default (unimplemented) platform
// ─────────────────────────────────────────────────────────────────────────────

/// A default no-op implementation that throws for all methods.
class _DefaultApprainBarcodeScannerPlatform
    extends ApprainBarcodeScannerPlatform {}

/// Method channel-based implementation.
///
/// This serves as a base implementation that platform packages
/// can extend if they prefer MethodChannel over Pigeon.
class MethodChannelApprainBarcodeScanner
    extends ApprainBarcodeScannerPlatform {
  /// The method channel used for control commands.
  final _methodChannel =
      const MethodChannel('com.apprain.barcode_scanner/methods');

  /// The event channel used for barcode detection results.
  final _scanEventChannel =
      const EventChannel('com.apprain.barcode_scanner/scan_results');

  /// The event channel used for camera lifecycle events.
  final _cameraEventChannel =
      const EventChannel('com.apprain.barcode_scanner/camera_events');

  @override
  Future<void> initialize(ScannerConfiguration config) async {
    await _methodChannel.invokeMethod<void>('initialize', config.toMap());
  }

  @override
  Future<void> startCamera() async {
    await _methodChannel.invokeMethod<void>('startCamera');
  }

  @override
  Future<void> stopCamera() async {
    await _methodChannel.invokeMethod<void>('stopCamera');
  }

  @override
  Future<void> dispose() async {
    await _methodChannel.invokeMethod<void>('dispose');
  }

  @override
  Future<void> setTorch({required bool enabled}) async {
    await _methodChannel
        .invokeMethod<void>('setTorch', {'enabled': enabled});
  }

  @override
  Future<void> setZoom(double zoomLevel) async {
    await _methodChannel.invokeMethod<void>('setZoom', {'zoom': zoomLevel});
  }

  @override
  Future<void> setFocusPoint(double x, double y) async {
    await _methodChannel.invokeMethod<void>('setFocusPoint', {
      'x': x,
      'y': y,
    });
  }

  @override
  Future<void> switchCamera() async {
    await _methodChannel.invokeMethod<void>('switchCamera');
  }

  @override
  Future<void> updateConfig(ScannerConfiguration config) async {
    await _methodChannel
        .invokeMethod<void>('updateConfig', config.toMap());
  }

  @override
  Stream<List<NativeScanResult>> get scanResults {
    return _scanEventChannel.receiveBroadcastStream().map((event) {
      if (event is List) {
        return event
            .whereType<Map<Object?, Object?>>()
            .map(NativeScanResult.fromMap)
            .toList();
      }
      return const <NativeScanResult>[];
    });
  }

  @override
  Stream<CameraEvent> get cameraEvents {
    return _cameraEventChannel.receiveBroadcastStream().map((event) {
      if (event is Map) {
        final type = event['type'] as String?;
        if (type == 'error') {
          return CameraErrorEvent(
            event['message'] as String? ?? 'Unknown camera error',
          );
        }
      }
      return const CameraReadyEvent();
    });
  }
}
