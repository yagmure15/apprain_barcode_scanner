import AVFoundation
import Flutter
import UIKit
import Vision

/// Native iOS view that hosts AVFoundation camera preview + Vision barcode detection.
///
/// Key design decisions:
/// - Uses AVCaptureSession for direct camera control.
/// - Vision framework VNDetectBarcodesRequest for barcode detection (iOS 11+).
/// - Frame processing on a dedicated serial queue to avoid blocking main thread.
/// - Supports ROI-based scanning via Vision's regionOfInterest.
/// - Frame throttling via configurable maxFrameRate.
class ScannerPlatformView: NSObject, FlutterPlatformView,
    AVCaptureVideoDataOutputSampleBufferDelegate {

    // MARK: - Properties

    private let previewContainer = UIView()
    private var previewLayer: AVCaptureVideoPreviewLayer?

    // Camera
    private let captureSession = AVCaptureSession()
    private var currentDevice: AVCaptureDevice?
    private var videoOutput: AVCaptureVideoDataOutput?
    private let processingQueue = DispatchQueue(label: "com.apprain.barcode_scanner.processing", qos: .userInteractive)

    // Detection
    private var barcodeRequest: VNDetectBarcodesRequest?
    private var isProcessing = false
    private var isConfiguring = false
    private var lastAnalysisTimestamp: TimeInterval = 0

    // Image preprocessing (GPU-accelerated)
    private let ciContext = CIContext(options: [.useSoftwareRenderer: false])

    // Config
    private var useFrontCamera = false
    private var enableScanWindow = true
    private var scanWindowWidthRatio: Double = 0.75
    private var scanWindowHeightRatio: Double = 0.35
    private var scanWindowVerticalOffsetRatio: Double = 0.10
    private var enablePreprocessing = true
    private var maxFrameRate = 15
    private var enableTorch = false
    private var allowedSymbologies: [VNBarcodeSymbology] = []
    private var targetResolution: String = "hd720"

    // Event sinks
    private var scanEventSink: FlutterEventSink?
    private var cameraEventSink: FlutterEventSink?

    // Stream handlers (kept alive to maintain event sink references)
    private let scanStreamHandler = _EventStreamHandler()
    private let cameraStreamHandler = _EventStreamHandler()

    // MARK: - Init

    init(
        frame: CGRect,
        viewId: Int64,
        creationParams: [String: Any]?,
        scanEventChannel: FlutterEventChannel,
        cameraEventChannel: FlutterEventChannel
    ) {
        super.init()

        previewContainer.frame = frame
        previewContainer.backgroundColor = .black

        // Scan event channel — barcode detections
        scanStreamHandler.onSinkReady = { [weak self] sink in
            self?.scanEventSink = sink
        }
        scanStreamHandler.onSinkCancelled = { [weak self] in
            self?.scanEventSink = nil
        }
        scanEventChannel.setStreamHandler(scanStreamHandler)

        // Camera event channel — lifecycle events
        cameraStreamHandler.onSinkReady = { [weak self] sink in
            self?.cameraEventSink = sink
        }
        cameraStreamHandler.onSinkCancelled = { [weak self] in
            self?.cameraEventSink = nil
        }
        cameraEventChannel.setStreamHandler(cameraStreamHandler)
    }

    func view() -> UIView {
        return previewContainer
    }

    // MARK: - Public API

    func initialize(config: [String: Any]?) {
        applyConfig(config: config)
        initBarcodeDetector(config: config)
    }

    func startCamera() {
        processingQueue.async { [weak self] in
            guard let self = self else { return }
            self.setupCamera()

            if !self.captureSession.isRunning {
                self.captureSession.startRunning()
            }

            DispatchQueue.main.async {
                self.setupPreviewLayer()
                self.sendCameraEvent(type: "ready")
            }
        }
    }

    func stopCamera() {
        processingQueue.async { [weak self] in
            guard let self = self else { return }
            // Never call stopRunning while inside a configuration block
            guard !self.isConfiguring else { return }
            if self.captureSession.isRunning {
                self.captureSession.stopRunning()
            }
        }
    }

    func disposeResources() {
        // Perform all cleanup on the processing queue to avoid
        // calling stopRunning between beginConfiguration/commitConfiguration
        processingQueue.async { [weak self] in
            guard let self = self else { return }
            if self.captureSession.isRunning {
                self.captureSession.stopRunning()
            }
            self.captureSession.inputs.forEach { self.captureSession.removeInput($0) }
            self.captureSession.outputs.forEach { self.captureSession.removeOutput($0) }

            DispatchQueue.main.async {
                self.previewLayer?.removeFromSuperlayer()
                self.previewLayer = nil
                self.scanEventSink = nil
                self.cameraEventSink = nil
            }
        }
    }

    func setTorch(enabled: Bool) {
        guard let device = currentDevice, device.hasTorch else { return }
        try? device.lockForConfiguration()
        device.torchMode = enabled ? .on : .off
        device.unlockForConfiguration()
        enableTorch = enabled
    }

    func setZoom(_ zoomLevel: CGFloat) {
        guard let device = currentDevice else { return }
        let maxZoom = min(device.activeFormat.videoMaxZoomFactor, 10.0)
        let zoom = 1.0 + zoomLevel * (maxZoom - 1.0)
        try? device.lockForConfiguration()
        device.videoZoomFactor = max(1.0, min(zoom, maxZoom))
        device.unlockForConfiguration()
    }

    func setFocusPoint(x: CGFloat, y: CGFloat) {
        guard let device = currentDevice else { return }
        guard device.isFocusPointOfInterestSupported else { return }

        let point = CGPoint(x: x, y: y)
        try? device.lockForConfiguration()
        device.focusPointOfInterest = point
        device.focusMode = .autoFocus
        if device.isExposurePointOfInterestSupported {
            device.exposurePointOfInterest = point
            device.exposureMode = .autoExpose
        }
        device.unlockForConfiguration()
    }

    func switchCamera() {
        useFrontCamera.toggle()
        if captureSession.isRunning {
            stopCamera()
            // Small delay to allow session cleanup
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [weak self] in
                self?.startCamera()
            }
        }
    }

    func updateConfig(config: [String: Any]?) {
        applyConfig(config: config)
    }

    // MARK: - Private Setup

    private func applyConfig(config: [String: Any]?) {
        guard let config = config else { return }
        useFrontCamera = config["useFrontCamera"] as? Bool ?? useFrontCamera
        enableScanWindow = config["enableScanWindow"] as? Bool ?? enableScanWindow
        scanWindowWidthRatio = config["scanWindowWidthRatio"] as? Double ?? scanWindowWidthRatio
        scanWindowHeightRatio = config["scanWindowHeightRatio"] as? Double ?? scanWindowHeightRatio
        scanWindowVerticalOffsetRatio = config["scanWindowVerticalOffsetRatio"] as? Double ?? scanWindowVerticalOffsetRatio
        enablePreprocessing = config["enablePreprocessing"] as? Bool ?? enablePreprocessing
        maxFrameRate = config["maxFrameRate"] as? Int ?? maxFrameRate
        enableTorch = config["enableTorch"] as? Bool ?? enableTorch
        targetResolution = config["targetResolution"] as? String ?? targetResolution
    }

    private func initBarcodeDetector(config: [String: Any]?) {
        let formats = (config?["allowedFormats"] as? [String]) ?? []
        allowedSymbologies = formats.compactMap { formatStringToSymbology($0) }

        barcodeRequest = VNDetectBarcodesRequest { [weak self] request, error in
            guard let self = self else { return }
            if let error = error {
                print("⚠️ Vision barcode error: \(error.localizedDescription)")
                return
            }

            guard let results = request.results as? [VNBarcodeObservation],
                  !results.isEmpty else { return }

            let scanResults: [[String: Any]] = results.compactMap { observation in
                guard let payload = observation.payloadStringValue else { return nil }

                // ROI filtering — check if barcode center is within scan window
                if self.enableScanWindow {
                    let centerX = observation.boundingBox.midX
                    let centerY = observation.boundingBox.midY

                    let windowLeft = (1.0 - self.scanWindowWidthRatio) / 2.0
                    let windowRight = 1.0 - windowLeft
                    let windowCenterY = 0.5 + self.scanWindowVerticalOffsetRatio
                    let windowTop = windowCenterY - self.scanWindowHeightRatio / 2.0
                    let windowBottom = windowCenterY + self.scanWindowHeightRatio / 2.0

                    guard centerX >= windowLeft && centerX <= windowRight &&
                          centerY >= windowTop && centerY <= windowBottom else {
                        return nil
                    }
                }

                // Convert corners from Vision coords (bottom-left origin)
                // to Flutter coords (top-left origin): flip Y axis
                let corners: [Double] = observation.topLeft.flippedXY()
                    + observation.topRight.flippedXY()
                    + observation.bottomRight.flippedXY()
                    + observation.bottomLeft.flippedXY()

                // Bounding box in normalized coords (0-1) for Flutter overlay
                let bb = observation.boundingBox
                let boundingBox: [String: Double] = [
                    "left": Double(bb.origin.x),
                    "top": Double(1.0 - bb.origin.y - bb.size.height),
                    "width": Double(bb.size.width),
                    "height": Double(bb.size.height),
                ]

                return [
                    "rawValue": payload,
                    "format": self.symbologyToString(observation.symbology),
                    "corners": corners,
                    "confidence": Double(observation.confidence),
                    "boundingBox": boundingBox,
                ]
            }

            if !scanResults.isEmpty {
                DispatchQueue.main.async {
                    self.scanEventSink?(scanResults)
                }
            }
        }

        if !allowedSymbologies.isEmpty {
            barcodeRequest?.symbologies = allowedSymbologies
        }
    }

    private func setupCamera() {
        isConfiguring = true
        captureSession.beginConfiguration()

        // Remove existing inputs/outputs
        captureSession.inputs.forEach { captureSession.removeInput($0) }
        captureSession.outputs.forEach { captureSession.removeOutput($0) }

        captureSession.sessionPreset = sessionPresetForResolution()

        // Select camera
        let position: AVCaptureDevice.Position = useFrontCamera ? .front : .back
        guard let device = AVCaptureDevice.default(
            .builtInWideAngleCamera, for: .video, position: position
        ) else {
            sendCameraEvent(type: "error", message: "Camera device not available")
            return
        }
        currentDevice = device

        // Configure device for continuous autofocus
        try? device.lockForConfiguration()
        if device.isFocusModeSupported(.continuousAutoFocus) {
            device.focusMode = .continuousAutoFocus
        }
        if device.isExposureModeSupported(.continuousAutoExposure) {
            device.exposureMode = .continuousAutoExposure
        }
        device.unlockForConfiguration()

        // Add input
        guard let input = try? AVCaptureDeviceInput(device: device) else {
            sendCameraEvent(type: "error", message: "Could not create camera input")
            return
        }

        if captureSession.canAddInput(input) {
            captureSession.addInput(input)
        }

        // Add video output
        let output = AVCaptureVideoDataOutput()
        output.alwaysDiscardsLateVideoFrames = true
        output.videoSettings = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
        ]
        output.setSampleBufferDelegate(self, queue: processingQueue)
        videoOutput = output

        if captureSession.canAddOutput(output) {
            captureSession.addOutput(output)
        }

        // Set video orientation on the output connection
        if let connection = output.connection(with: .video) {
            if connection.isVideoOrientationSupported {
                connection.videoOrientation = currentVideoOrientation()
            }
        }

        // Apply torch if needed
        if enableTorch {
            setTorch(enabled: true)
        }

        captureSession.commitConfiguration()
        isConfiguring = false
    }

    private func setupPreviewLayer() {
        previewLayer?.removeFromSuperlayer()

        let layer = AVCaptureVideoPreviewLayer(session: captureSession)
        layer.videoGravity = .resizeAspectFill
        layer.frame = previewContainer.bounds

        // Set preview orientation to match device
        if let connection = layer.connection, connection.isVideoOrientationSupported {
            connection.videoOrientation = currentVideoOrientation()
        }

        previewContainer.layer.addSublayer(layer)
        previewLayer = layer
    }

    /// Maps the current interface orientation to AVCaptureVideoOrientation.
    private func currentVideoOrientation() -> AVCaptureVideoOrientation {
        let scenes = UIApplication.shared.connectedScenes
        let windowScene = scenes.first(where: { $0 is UIWindowScene }) as? UIWindowScene
        let orientation = windowScene?.interfaceOrientation ?? .landscapeRight

        switch orientation {
        case .portrait:
            return .portrait
        case .portraitUpsideDown:
            return .portraitUpsideDown
        case .landscapeLeft:
            return .landscapeLeft
        case .landscapeRight:
            return .landscapeRight
        @unknown default:
            return .landscapeRight
        }
    }

    /// Maps device interface orientation to CGImagePropertyOrientation.
    ///
    /// Vision framework needs this to correctly interpret pixel buffer
    /// coordinates relative to the device's current screen orientation.
    /// Without this, coordinates are returned in the sensor's native
    /// portrait orientation — causing X/Y mismatch on iPad landscape.
    private func currentCGImageOrientation() -> CGImagePropertyOrientation {
        let scenes = UIApplication.shared.connectedScenes
        let windowScene = scenes.first(where: { $0 is UIWindowScene }) as? UIWindowScene
        let orientation = windowScene?.interfaceOrientation ?? .landscapeRight

        switch orientation {
        case .portrait:
            return .right
        case .portraitUpsideDown:
            return .left
        case .landscapeLeft:
            return .down
        case .landscapeRight:
            return .up
        @unknown default:
            return .up
        }
    }

    /// Maps the targetResolution config string to an AVCaptureSession.Preset.
    private func sessionPresetForResolution() -> AVCaptureSession.Preset {
        switch targetResolution {
        case "fullHd1080":
            return .hd1920x1080
        case "uhd4k":
            return .hd4K3840x2160
        default: // "hd720"
            return .hd1280x720
        }
    }

    // MARK: - AVCaptureVideoDataOutputSampleBufferDelegate

    func captureOutput(
        _ output: AVCaptureOutput,
        didOutput sampleBuffer: CMSampleBuffer,
        from connection: AVCaptureConnection
    ) {
        // Frame throttling
        let now = CACurrentMediaTime()
        let minInterval = maxFrameRate > 0 ? 1.0 / Double(maxFrameRate) : 0
        guard now - lastAnalysisTimestamp >= minInterval else { return }

        // Single-frame gate
        guard !isProcessing else { return }
        isProcessing = true
        lastAnalysisTimestamp = now

        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            isProcessing = false
            return
        }

        guard let request = barcodeRequest else {
            isProcessing = false
            return
        }

        // ── Pass 1: Raw frame ──────────────────────────────────────
        let orientation = currentCGImageOrientation()
        let rawHandler = VNImageRequestHandler(
            cvPixelBuffer: pixelBuffer,
            orientation: orientation,
            options: [:]
        )
        do {
            try rawHandler.perform([request])
            if let results = request.results, !results.isEmpty {
                // Raw frame succeeded — skip preprocessing
                isProcessing = false
                return
            }
        } catch {
            // Fall through to preprocessed pass
        }

        // ── Pass 2: Preprocessed frame ─────────────────────────────
        // Apply contrast enhancement + sharpening for small barcodes
        guard enablePreprocessing else {
            isProcessing = false
            return
        }

        if let enhancedBuffer = preprocessFrame(pixelBuffer) {
            let enhancedHandler = VNImageRequestHandler(
                cvPixelBuffer: enhancedBuffer,
                orientation: orientation,
                options: [:]
            )
            do {
                try enhancedHandler.perform([request])
            } catch {
                print("⚠️ Vision preprocessed request failed: \(error.localizedDescription)")
            }
        }

        isProcessing = false
    }

    // MARK: - Image Preprocessing

    /// Enhances the pixel buffer for better small barcode detection.
    ///
    /// Pipeline: Exposure adjust → Contrast stretch → Unsharp mask.
    /// Uses GPU-accelerated CIFilter chain for real-time performance.
    private func preprocessFrame(_ pixelBuffer: CVPixelBuffer) -> CVPixelBuffer? {
        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)

        // 1) Exposure adjustment — brighten underexposed areas
        guard let exposureFilter = CIFilter(
            name: "CIExposureAdjust",
            parameters: [
                kCIInputImageKey: ciImage,
                "inputEV": 0.3,
            ]
        ), let exposedImage = exposureFilter.outputImage else {
            return nil
        }

        // 2) Contrast enhancement — make barcode edges stand out
        guard let contrastFilter = CIFilter(
            name: "CIColorControls",
            parameters: [
                kCIInputImageKey: exposedImage,
                "inputContrast": 1.4,
                "inputSaturation": 0.0,  // Grayscale for barcode detection
            ]
        ), let contrastedImage = contrastFilter.outputImage else {
            return nil
        }

        // 3) Sharpening — enhance fine details in small codes
        guard let sharpenFilter = CIFilter(
            name: "CIUnsharpMask",
            parameters: [
                kCIInputImageKey: contrastedImage,
                "inputRadius": 2.5,
                "inputIntensity": 0.8,
            ]
        ), let sharpenedImage = sharpenFilter.outputImage else {
            return nil
        }

        // Render back to a new pixel buffer
        var outputBuffer: CVPixelBuffer?
        let width = CVPixelBufferGetWidth(pixelBuffer)
        let height = CVPixelBufferGetHeight(pixelBuffer)
        let attrs: [String: Any] = [
            kCVPixelBufferCGImageCompatibilityKey as String: true,
            kCVPixelBufferCGBitmapContextCompatibilityKey as String: true,
        ]
        CVPixelBufferCreate(
            kCFAllocatorDefault,
            width, height,
            kCVPixelFormatType_32BGRA,
            attrs as CFDictionary,
            &outputBuffer
        )

        guard let output = outputBuffer else { return nil }
        ciContext.render(sharpenedImage, to: output)
        return output
    }

    // MARK: - Helpers

    private func sendCameraEvent(type: String, message: String? = nil) {
        var event: [String: Any] = ["type": type]
        if let message = message {
            event["message"] = message
        }
        DispatchQueue.main.async { [weak self] in
            self?.cameraEventSink?(event)
        }
    }

    // MARK: - Format Mapping

    private func formatStringToSymbology(_ format: String) -> VNBarcodeSymbology? {
        switch format.uppercased() {
        case "QR_CODE": return .qr
        case "CODE_128": return .code128
        case "CODE_39": return .code39
        case "CODE_93": return .code93
        case "EAN_13": return .ean13
        case "EAN_8": return .ean8
        case "UPC_E": return .upce
        case "DATA_MATRIX": return .dataMatrix
        case "PDF417": return .pdf417
        case "AZTEC": return .aztec
        case "CODABAR": return .codabar
        case "ITF": return .itf14
        default: return nil
        }
    }

    private func symbologyToString(_ symbology: VNBarcodeSymbology) -> String {
        switch symbology {
        case .qr: return "QR_CODE"
        case .code128: return "CODE_128"
        case .code39: return "CODE_39"
        case .code93: return "CODE_93"
        case .ean13: return "EAN_13"
        case .ean8: return "EAN_8"
        case .upce: return "UPC_E"
        case .dataMatrix: return "DATA_MATRIX"
        case .pdf417: return "PDF417"
        case .aztec: return "AZTEC"
        case .codabar: return "CODABAR"
        case .itf14: return "ITF"
        default: return "UNKNOWN"
        }
    }
}

// MARK: - CGPoint Extension

private extension CGPoint {
    func asList() -> [Double] {
        return [Double(x), Double(y)]
    }

    /// Returns coordinates with Y flipped (1 - y) for Vision → Flutter conversion.
    func flippedY() -> [Double] {
        return [Double(x), Double(1.0 - y)]
    }

    /// Returns coordinates with both X and Y flipped for Vision → Flutter conversion.
    func flippedXY() -> [Double] {
        return [Double(1.0 - x), Double(1.0 - y)]
    }
}

// MARK: - Event Stream Handler

/// Lightweight FlutterStreamHandler that forwards the event sink via closures.
private class _EventStreamHandler: NSObject, FlutterStreamHandler {
    var onSinkReady: ((@escaping FlutterEventSink) -> Void)?
    var onSinkCancelled: (() -> Void)?

    func onListen(
        withArguments arguments: Any?,
        eventSink events: @escaping FlutterEventSink
    ) -> FlutterError? {
        onSinkReady?(events)
        return nil
    }

    func onCancel(withArguments arguments: Any?) -> FlutterError? {
        onSinkCancelled?()
        return nil
    }
}
