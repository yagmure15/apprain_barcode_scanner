import Flutter
import UIKit

/// Factory that creates ScannerPlatformView instances for Flutter embedding.
class ScannerPlatformViewFactory: NSObject, FlutterPlatformViewFactory {

    private let messenger: FlutterBinaryMessenger
    private let scanEventChannel: FlutterEventChannel
    private let cameraEventChannel: FlutterEventChannel

    private(set) var activeView: ScannerPlatformView?

    init(
        messenger: FlutterBinaryMessenger,
        scanEventChannel: FlutterEventChannel,
        cameraEventChannel: FlutterEventChannel
    ) {
        self.messenger = messenger
        self.scanEventChannel = scanEventChannel
        self.cameraEventChannel = cameraEventChannel
        super.init()
    }

    func create(
        withFrame frame: CGRect,
        viewIdentifier viewId: Int64,
        arguments args: Any?
    ) -> FlutterPlatformView {
        let creationParams = args as? [String: Any]
        let view = ScannerPlatformView(
            frame: frame,
            viewId: viewId,
            creationParams: creationParams,
            scanEventChannel: scanEventChannel,
            cameraEventChannel: cameraEventChannel
        )
        activeView = view
        return view
    }

    func createArgsCodec() -> FlutterMessageCodec & NSObjectProtocol {
        return FlutterStandardMessageCodec.sharedInstance()
    }

    func dispose() {
        activeView?.disposeResources()
        activeView = nil
    }
}
