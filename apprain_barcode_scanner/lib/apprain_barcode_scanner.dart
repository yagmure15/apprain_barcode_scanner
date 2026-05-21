/// High-performance native barcode/QR scanner for Flutter.
///
/// Built with CameraX (Android) and AVFoundation (iOS).
/// Includes customizable scan window overlay, perspective-aware barcode
/// bounding box, and tap-to-focus support.
library;

// Re-export platform interface types
export 'package:apprain_barcode_scanner_platform_interface/apprain_barcode_scanner_platform_interface.dart'
    show
        ApprainBarcodeScannerPlatform,
        CameraErrorEvent,
        CameraEvent,
        CameraReadyEvent,
        NativeScanResult,
        ScannerConfiguration,
        ScannerResolution;

// Controller
export 'src/apprain_scanner_controller.dart';
// Visual config
export 'src/apprain_scanner_config.dart';
// Widget
export 'src/apprain_scanner_widget.dart';
// Presentation
export 'src/presentation/focus_indicator.dart';
export 'src/presentation/scan_window_overlay.dart';
export 'src/presentation/scanner_overlay_painter.dart';
