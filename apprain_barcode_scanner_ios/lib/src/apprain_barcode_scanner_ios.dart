import 'package:apprain_barcode_scanner_platform_interface/apprain_barcode_scanner_platform_interface.dart';
import 'package:flutter/foundation.dart';

/// The iOS implementation of [ApprainBarcodeScannerPlatform].
///
/// Uses MethodChannel + EventChannel to communicate with the native
/// Swift layer (AVFoundation + Vision framework).
class ApprainBarcodeScannerIOS
    extends MethodChannelApprainBarcodeScanner {
  /// Registers this class as the default instance of
  /// [ApprainBarcodeScannerPlatform].
  static void registerWith() {
    ApprainBarcodeScannerPlatform.instance =
        ApprainBarcodeScannerIOS();
    debugPrint('📷 ApprainBarcodeScannerIOS registered.');
  }
}
