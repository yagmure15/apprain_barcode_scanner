/// Supported barcode symbology formats.
///
/// These correspond to ML Kit (Android) and Vision (iOS) barcode formats.
/// The [value] property contains the platform channel string representation
/// used for communication with native code.
enum BarcodeFormat {
  /// QR Code (ISO 18004)
  qrCode('QR_CODE'),

  /// Code 128 (ISO 15417)
  code128('CODE_128'),

  /// Code 39 (ISO 16388)
  code39('CODE_39'),

  /// Code 93
  code93('CODE_93'),

  /// EAN-13 (International Article Number)
  ean13('EAN_13'),

  /// EAN-8 (International Article Number)
  ean8('EAN_8'),

  /// UPC-A (Universal Product Code)
  upcA('UPC_A'),

  /// UPC-E (Universal Product Code)
  upcE('UPC_E'),

  /// Data Matrix (ISO 16022)
  dataMatrix('DATA_MATRIX'),

  /// PDF417 (ISO 15438)
  pdf417('PDF417'),

  /// Aztec (ISO 24778)
  aztec('AZTEC'),

  /// Codabar (NW-7)
  codabar('CODABAR'),

  /// ITF (Interleaved 2 of 5)
  itf('ITF'),

  /// Unknown or unsupported format.
  unknown('UNKNOWN');

  const BarcodeFormat(this.value);

  /// Platform channel string representation (e.g. 'QR_CODE', 'CODE_128').
  final String value;

  /// Parses a platform channel string into a [BarcodeFormat].
  ///
  /// Returns [BarcodeFormat.unknown] for unrecognized strings.
  static BarcodeFormat fromString(String value) {
    return BarcodeFormat.values.firstWhere(
      (format) => format.value == value.toUpperCase(),
      orElse: () => BarcodeFormat.unknown,
    );
  }
}
