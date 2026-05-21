import 'dart:ui';

/// Scan result returned from native barcode detection.
///
/// Contains the raw barcode value, its format, bounding box corners,
/// and a confidence score.
class NativeScanResult {
  /// Creates a [NativeScanResult] with the given values.
  const NativeScanResult({
    required this.rawValue,
    required this.format,
    this.corners = const [],
    this.confidence = 1.0,
    this.boundingBox,
  });

  /// Creates a [NativeScanResult] from a map received via platform channel.
  factory NativeScanResult.fromMap(Map<Object?, Object?> map) {
    return NativeScanResult(
      rawValue: map['rawValue']! as String,
      format: map['format'] as String? ?? 'unknown',
      corners: _parseCorners(map['corners']),
      confidence: (map['confidence'] as num?)?.toDouble() ?? 1.0,
      boundingBox: _parseBoundingBox(map['boundingBox']),
    );
  }

  /// The raw decoded barcode string value.
  final String rawValue;

  /// Barcode symbology format (e.g. 'QR_CODE', 'CODE_128', 'EAN_13').
  final String format;

  /// Bounding box corners as [x1,y1, x2,y2, x3,y3, x4,y4].
  ///
  /// Coordinates are in the camera preview coordinate space.
  final List<double> corners;

  /// Detection confidence score (0.0 – 1.0).
  final double confidence;

  /// Normalized bounding box (0.0 – 1.0) relative to camera frame.
  ///
  /// Used by the scanner widget to draw detection overlays.
  final Rect? boundingBox;

  /// Parses [corners] into a list of 4 `Offset` points.
  ///
  /// Returns empty list if corners data is incomplete.
  List<Offset> get cornerOffsets {
    if (corners.length < 8) return const [];
    return [
      Offset(corners[0], corners[1]),
      Offset(corners[2], corners[3]),
      Offset(corners[4], corners[5]),
      Offset(corners[6], corners[7]),
    ];
  }

  /// Serializes this result to a map for platform channel communication.
  Map<String, Object?> toMap() => {
        'rawValue': rawValue,
        'format': format,
        'corners': corners,
        'confidence': confidence,
      };

  static List<double> _parseCorners(Object? value) {
    if (value is List) {
      return value.whereType<num>().map((n) => n.toDouble()).toList();
    }
    return const [];
  }

  static Rect? _parseBoundingBox(Object? value) {
    if (value is Map) {
      final left = (value['left'] as num?)?.toDouble() ?? 0;
      final top = (value['top'] as num?)?.toDouble() ?? 0;
      final width = (value['width'] as num?)?.toDouble() ?? 0;
      final height = (value['height'] as num?)?.toDouble() ?? 0;
      return Rect.fromLTWH(left, top, width, height);
    }
    return null;
  }
}
