import 'package:apprain_barcode_scanner_platform_interface/apprain_barcode_scanner_platform_interface.dart';
import 'package:flutter/foundation.dart';

/// The Android implementation of [ApprainBarcodeScannerPlatform].
///
/// Uses MethodChannel + EventChannel to communicate with the native
/// Kotlin layer (CameraX + ML Kit).
class ApprainBarcodeScannerAndroid
    extends MethodChannelApprainBarcodeScanner {
  /// Registers this class as the default instance of
  /// [ApprainBarcodeScannerPlatform].
  static void registerWith() {
    ApprainBarcodeScannerPlatform.instance =
        ApprainBarcodeScannerAndroid();
    debugPrint('📷 ApprainBarcodeScannerAndroid registered.');
  }
}
