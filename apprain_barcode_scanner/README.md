# apprain_barcode_scanner

[![License: Apache-2.0](https://img.shields.io/badge/License-Apache%202.0-blue.svg)](https://opensource.org/licenses/Apache-2.0)
[![pub.dev](https://img.shields.io/pub/v/apprain_barcode_scanner.svg)](https://pub.dev/packages/apprain_barcode_scanner)

High-performance native barcode/QR scanner for Flutter with CameraX (Android) and AVFoundation + Vision (iOS). Includes customizable scan window overlay, perspective-aware barcode bounding box, and tap-to-focus support.

---

## ✨ Features

- 📸 **Native Camera Preview** — CameraX (Android) & AVFoundation (iOS) via PlatformView
- 🎯 **ROI Scan Window** — Configurable region-of-interest for focused scanning
- 🔲 **Perspective-Aware Overlay** — Barcode bounding box follows real-world perspective
- 🔦 **Torch / Flash** — Programmatic flashlight control
- 🔍 **Zoom & Focus** — Tap-to-focus with animated indicator + pinch-to-zoom
- 📱 **Camera Switching** — Front/back camera toggle
- 🔄 **Duplicate Filter** — Optional deduplication of scanned values
- 🎨 **Customizable UI** — Border type (box/corners), colors, radius, corner length
- 🖼 **Image Preprocessing** — GPU-accelerated contrast + sharpening for small barcodes (iOS)
- ⚡ **Frame Throttling** — Configurable max FPS to balance performance vs. battery

## 📦 Architecture

This package follows Flutter's [federated plugin](https://docs.flutter.dev/packages-and-plugins/developing-packages#federated-plugins) architecture:

```
apprain_barcode_scanner/                  ← App-facing package (you import this)
apprain_barcode_scanner_platform_interface/ ← Shared types + platform contract
apprain_barcode_scanner_android/           ← Android: Kotlin (CameraX + ML Kit)
apprain_barcode_scanner_ios/               ← iOS: Swift (AVFoundation + Vision)
```

## 🚀 Getting Started

### Installation

```yaml
dependencies:
  apprain_barcode_scanner:
    path: ../apprain_barcode_scanner/apprain_barcode_scanner
```

> When published to pub.dev, use the standard `apprain_barcode_scanner: ^1.0.0` syntax.

### Platform Setup

#### Android

Add camera permission to `AndroidManifest.xml`:

```xml
<uses-permission android:name="android.permission.CAMERA" />
<uses-feature android:name="android.hardware.camera" android:required="true" />
```

Minimum SDK: **26** (Android 8.0)

#### iOS

Add camera usage description to `Info.plist`:

```xml
<key>NSCameraUsageDescription</key>
<string>This app needs camera access to scan barcodes.</string>
```

Minimum iOS: **15.5**

## 📖 Usage

### Basic Example

```dart
import 'package:apprain_barcode_scanner/apprain_barcode_scanner.dart';
import 'package:flutter/material.dart';

class ScannerPage extends StatefulWidget {
  @override
  State<ScannerPage> createState() => _ScannerPageState();
}

class _ScannerPageState extends State<ScannerPage> {
  late final ApprainScannerController _controller;

  @override
  void initState() {
    super.initState();
    _controller = ApprainScannerController(
      config: const ScannerConfiguration(
        allowedFormats: [BarcodeFormat.qrCode, BarcodeFormat.code128, BarcodeFormat.ean13],
      ),
      onDetect: (results) {
        for (final result in results) {
          debugPrint('Scanned: ${result.rawValue} (${result.format})');
        }
      },
      onError: (message) => debugPrint('Error: $message'),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: ApprainScannerWidget(
        controller: _controller,
        config: const ApprainScannerConfig(
          scanWindowWidthRatio: 0.75,
          scanWindowHeightRatio: 0.35,
          scanWindowBorderType: ScanWindowBorderType.corners,
          barcodeOverlayBorderType: ScanWindowBorderType.corners,
        ),
        topWidget: const SafeArea(
          child: Padding(
            padding: EdgeInsets.all(16),
            child: Text('Scan a barcode', style: TextStyle(color: Colors.white)),
          ),
        ),
      ),
    );
  }
}
```

## 🎛 API Reference

### `ApprainScannerController`

| Property/Method | Type | Description |
|---|---|---|
| `config` | `ScannerConfiguration` | Current scanner configuration |
| `isInitialized` | `bool` | Whether the controller is initialized |
| `isRunning` | `bool` | Whether the camera is running |
| `isFrontCamera` | `bool` | Whether front camera is active |
| `barcodeCorners` | `ValueNotifier<List<List<Offset>>>` | Detected barcode corners (normalized) |
| `onDetect` | `void Function(List<NativeScanResult>)?` | Callback for detected barcodes |
| `onError` | `void Function(String)?` | Callback for camera errors |
| `enableDuplicateFilter` | `bool` | Whether to filter duplicate scans |
| `initialize()` | `Future<void>` | Initialize native scanner |
| `start()` | `Future<void>` | Start camera + detection |
| `stop()` | `Future<void>` | Stop camera |
| `dispose()` | `Future<void>` | Release all resources |
| `setTorch(enabled:)` | `Future<void>` | Toggle flashlight |
| `setZoom(level)` | `Future<void>` | Set zoom (0.0 – 1.0) |
| `setFocusPoint(x, y)` | `Future<void>` | Set focus point (normalized) |
| `switchCamera()` | `Future<void>` | Toggle front/back camera |
| `updateConfig(config)` | `Future<void>` | Update config at runtime |
| `resetScannedValues()` | `void` | Clear duplicate filter cache |

### `ScannerConfiguration`

| Property | Type | Default | Description |
|---|---|---|---|
| `scanWindowWidthRatio` | `double` | `0.75` | Scan window width ratio |
| `scanWindowHeightRatio` | `double` | `0.35` | Scan window height ratio |
| `scanWindowVerticalOffsetRatio` | `double` | `0.10` | Vertical offset from center |
| `enableScanWindow` | `bool` | `true` | Enable ROI-based scanning |
| `allowedFormats` | `List<BarcodeFormat>` | `[]` | Barcode formats to detect (empty = all) |
| `enablePreprocessing` | `bool` | `true` | Enable image preprocessing |
| `targetResolution` | `ScannerResolution` | `hd720` | Camera resolution |
| `maxFrameRate` | `int` | `15` | Max frames per second |
| `useFrontCamera` | `bool` | `false` | Use front camera |
| `enableTorch` | `bool` | `false` | Enable torch on start |

### `ApprainScannerConfig`

| Property | Type | Default | Description |
|---|---|---|---|
| `showScanWindow` | `bool` | `true` | Show scan window overlay |
| `scanWindowBorderType` | `ScanWindowBorderType` | `corners` | Border type (box/corners) |
| `scanWindowBorderWidth` | `double` | `2.5` | Border width |
| `scanWindowBorderRadius` | `BorderRadius` | `16` | Corner radius |
| `scanWindowBorderColor` | `Color` | `white` | Border color |
| `scanWindowOverlayColor` | `Color` | `white` | Dimmed overlay color |
| `scanWindowCornerLength` | `double` | `28` | Corner accent length |
| `barcodeOverlayColor` | `Color` | `0xFFFA8C16` | Barcode overlay color |
| `barcodeOverlayBorderType` | `ScanWindowBorderType` | `corners` | Barcode border type |
| `barcodeOverlayBorderWidth` | `double` | `3` | Barcode border width |
| `barcodeOverlayCornerRadius` | `double` | `6` | Barcode corner radius |
| `barcodeOverlayCornerLength` | `double` | `18` | Barcode corner length |

### Supported Barcode Formats

| Format | Android (ML Kit) | iOS (Vision) |
|---|---|---|
| `QR_CODE` | ✅ | ✅ |
| `CODE_128` | ✅ | ✅ |
| `CODE_39` | ✅ | ✅ |
| `CODE_93` | ✅ | ✅ |
| `EAN_13` | ✅ | ✅ |
| `EAN_8` | ✅ | ✅ |
| `UPC_A` | ✅ | ❌ |
| `UPC_E` | ✅ | ✅ |
| `DATA_MATRIX` | ✅ | ✅ |
| `PDF417` | ✅ | ✅ |
| `AZTEC` | ✅ | ✅ |
| `CODABAR` | ✅ | ✅ |
| `ITF` | ✅ | ✅ |

### `NativeScanResult`

| Property | Type | Description |
|---|---|---|
| `rawValue` | `String` | Decoded barcode string |
| `format` | `BarcodeFormat` | Barcode format enum |
| `corners` | `List<double>` | Corner points [x1,y1,...,x4,y4] |
| `confidence` | `double` | Detection confidence (0.0 – 1.0) |
| `boundingBox` | `Rect?` | Normalized bounding box |
| `cornerOffsets` | `List<Offset>` | Parsed corner offsets |

## 📝 License

```
Copyright 2026 yagmure15

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0
```
