/// Shared types for the Apprain Barcode Scanner platform interface.
///
/// These types are used for communication between the Dart layer
/// and native platform implementations.
library;

// Platform interface definition.
export 'src/apprain_barcode_scanner_platform.dart';
// Scan result returned from native barcode detection.
export 'src/types/native_scan_result.dart';
// Scanner configuration sent to native side.
export 'src/types/scanner_configuration.dart';
