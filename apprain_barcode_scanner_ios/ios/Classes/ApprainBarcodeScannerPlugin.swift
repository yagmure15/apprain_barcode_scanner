import Flutter
import UIKit

/// Entry point for the Apprain Barcode Scanner iOS plugin.
///
/// Registers the platform view factory and sets up MethodChannel / EventChannel
/// communication between Flutter and native AVFoundation + Vision scanning.
public class ApprainBarcodeScannerPlugin: NSObject, FlutterPlugin {

    private var scannerViewFactory: ScannerPlatformViewFactory?

    public static func register(with registrar: FlutterPluginRegistrar) {
        let instance = ApprainBarcodeScannerPlugin()

        // Method channel for control commands
        let methodChannel = FlutterMethodChannel(
            name: "com.apprain.barcode_scanner/methods",
            binaryMessenger: registrar.messenger()
        )

        // Event channels for scan results and camera events
        let scanEventChannel = FlutterEventChannel(
            name: "com.apprain.barcode_scanner/scan_results",
            binaryMessenger: registrar.messenger()
        )
        let cameraEventChannel = FlutterEventChannel(
            name: "com.apprain.barcode_scanner/camera_events",
            binaryMessenger: registrar.messenger()
        )

        let factory = ScannerPlatformViewFactory(
            messenger: registrar.messenger(),
            scanEventChannel: scanEventChannel,
            cameraEventChannel: cameraEventChannel
        )
        instance.scannerViewFactory = factory

        registrar.register(factory, withId: "com.apprain.barcode_scanner/scanner_view")
        registrar.addMethodCallDelegate(instance, channel: methodChannel)
    }

    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let view = scannerViewFactory?.activeView else {
            result(FlutterError(
                code: "NO_VIEW",
                message: "Camera is not available — scanner view not created yet",
                details: "Method: \(call.method)"
            ))
            return
        }

        switch call.method {
        case "initialize":
            let config = call.arguments as? [String: Any]
            view.initialize(config: config)
            result(nil)

        case "startCamera":
            view.startCamera()
            result(nil)

        case "stopCamera":
            view.stopCamera()
            result(nil)

        case "dispose":
            view.disposeResources()
            result(nil)

        case "setTorch":
            let args = call.arguments as? [String: Any]
            let enabled = args?["enabled"] as? Bool ?? false
            view.setTorch(enabled: enabled)
            result(nil)

        case "setZoom":
            let args = call.arguments as? [String: Any]
            let zoom = (args?["zoom"] as? NSNumber)?.floatValue ?? 0.0
            view.setZoom(CGFloat(zoom))
            result(nil)

        case "setFocusPoint":
            let args = call.arguments as? [String: Any]
            let x = (args?["x"] as? NSNumber)?.floatValue ?? 0.5
            let y = (args?["y"] as? NSNumber)?.floatValue ?? 0.5
            view.setFocusPoint(x: CGFloat(x), y: CGFloat(y))
            result(nil)

        case "switchCamera":
            view.switchCamera()
            result(nil)

        case "updateConfig":
            let config = call.arguments as? [String: Any]
            view.updateConfig(config: config)
            result(nil)

        default:
            result(FlutterMethodNotImplemented)
        }
    }
}
