import 'barcode_format.dart';

/// Scanner configuration sent from Dart to native platform.
///
/// Controls camera behavior, scan window, and barcode format filtering.
class ScannerConfiguration {
  /// Creates a [ScannerConfiguration] with the given settings.
  const ScannerConfiguration({
    this.scanWindowWidthRatio = 0.75,
    this.scanWindowHeightRatio = 0.35,
    this.scanWindowVerticalOffsetRatio = 0.10,
    this.enableScanWindow = true,
    this.allowedFormats = const [],
    this.enablePreprocessing = true,
    this.targetResolution = ScannerResolution.hd720,
    this.maxFrameRate = 15,
    this.useFrontCamera = false,
    this.enableTorch = false,
  });

  /// Scan window width as a ratio of preview width (0.0 – 1.0).
  final double scanWindowWidthRatio;

  /// Scan window height as a ratio of preview height (0.0 – 1.0).
  final double scanWindowHeightRatio;

  /// Vertical offset of scan window center from screen center (0.0 – 0.5).
  final double scanWindowVerticalOffsetRatio;

  /// Whether to enable ROI-based scanning (crop frame to scan window).
  final bool enableScanWindow;

  /// Barcode formats to detect. Empty list means detect all formats.
  final List<BarcodeFormat> allowedFormats;

  /// Whether to enable image preprocessing (contrast, sharpening).
  final bool enablePreprocessing;

  /// Target camera resolution.
  final ScannerResolution targetResolution;

  /// Maximum frames per second to analyze (frame throttling).
  final int maxFrameRate;

  /// Whether to use the front-facing camera.
  final bool useFrontCamera;

  /// Whether to enable the flashlight/torch.
  final bool enableTorch;

  /// Serializes this configuration to a map for platform channel.
  Map<String, Object?> toMap() => {
        'scanWindowWidthRatio': scanWindowWidthRatio,
        'scanWindowHeightRatio': scanWindowHeightRatio,
        'scanWindowVerticalOffsetRatio': scanWindowVerticalOffsetRatio,
        'enableScanWindow': enableScanWindow,
        'allowedFormats': allowedFormats.map((f) => f.value).toList(),
        'enablePreprocessing': enablePreprocessing,
        'targetResolution': targetResolution.name,
        'maxFrameRate': maxFrameRate,
        'useFrontCamera': useFrontCamera,
        'enableTorch': enableTorch,
      };

  /// Creates a copy with the given fields replaced.
  ScannerConfiguration copyWith({
    double? scanWindowWidthRatio,
    double? scanWindowHeightRatio,
    double? scanWindowVerticalOffsetRatio,
    bool? enableScanWindow,
    List<BarcodeFormat>? allowedFormats,
    bool? enablePreprocessing,
    ScannerResolution? targetResolution,
    int? maxFrameRate,
    bool? useFrontCamera,
    bool? enableTorch,
  }) {
    return ScannerConfiguration(
      scanWindowWidthRatio: scanWindowWidthRatio ?? this.scanWindowWidthRatio,
      scanWindowHeightRatio:
          scanWindowHeightRatio ?? this.scanWindowHeightRatio,
      scanWindowVerticalOffsetRatio:
          scanWindowVerticalOffsetRatio ?? this.scanWindowVerticalOffsetRatio,
      enableScanWindow: enableScanWindow ?? this.enableScanWindow,
      allowedFormats: allowedFormats ?? this.allowedFormats,
      enablePreprocessing: enablePreprocessing ?? this.enablePreprocessing,
      targetResolution: targetResolution ?? this.targetResolution,
      maxFrameRate: maxFrameRate ?? this.maxFrameRate,
      useFrontCamera: useFrontCamera ?? this.useFrontCamera,
      enableTorch: enableTorch ?? this.enableTorch,
    );
  }
}

/// Camera resolution presets.
enum ScannerResolution {
  /// 640x480
  sd480,

  /// 1280x720
  hd720,

  /// 1920x1080
  fullHd1080,
}
