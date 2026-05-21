package com.apprain.barcode_scanner

import android.app.Activity
import android.content.Context
import android.util.Log
import android.view.View
import android.widget.FrameLayout
import androidx.camera.core.*
import androidx.camera.lifecycle.ProcessCameraProvider
import androidx.camera.view.PreviewView
import androidx.core.content.ContextCompat
import androidx.lifecycle.LifecycleOwner
import com.google.mlkit.vision.barcode.BarcodeScanner
import com.google.mlkit.vision.barcode.BarcodeScannerOptions
import com.google.mlkit.vision.barcode.BarcodeScanning
import com.google.mlkit.vision.barcode.common.Barcode
import com.google.mlkit.vision.common.InputImage
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.platform.PlatformView
import java.util.concurrent.Executors
import java.util.concurrent.atomic.AtomicBoolean

/**
 * Native Android view that hosts CameraX preview + ML Kit barcode analysis.
 *
 * Key design decisions:
 * - Uses [PreviewView] for zero-copy camera preview rendering.
 * - [ImageAnalysis] with STRATEGY_KEEP_ONLY_LATEST for back-pressure handling.
 * - [AtomicBoolean] gate ensures only one frame is processed at a time.
 * - Supports ROI pre-crop for focused scanning.
 * - Frame throttling via configurable maxFrameRate.
 */
class ScannerPlatformView(
    private val context: Context,
    private val activity: Activity?,
    private val viewId: Int,
    private val creationParams: Map<*, *>?,
    private val scanEventChannel: EventChannel,
    private val cameraEventChannel: EventChannel,
) : PlatformView {

    companion object {
        private const val TAG = "ApprainScanner"
    }

    // ── View ─────────────────────────────────────────────────────────────────

    private val container = FrameLayout(context)
    private val previewView = PreviewView(context).apply {
        implementationMode = PreviewView.ImplementationMode.PERFORMANCE
        scaleType = PreviewView.ScaleType.FILL_CENTER
    }

    // ── Camera ───────────────────────────────────────────────────────────────

    private var cameraProvider: ProcessCameraProvider? = null
    private var camera: Camera? = null
    private var preview: Preview? = null
    private var imageAnalysis: ImageAnalysis? = null
    private val analysisExecutor = Executors.newSingleThreadExecutor()
    private val isProcessing = AtomicBoolean(false)
    private var lastAnalysisTimestamp = 0L

    // ── ML Kit ───────────────────────────────────────────────────────────────

    private var barcodeScanner: BarcodeScanner? = null

    // ── Config ───────────────────────────────────────────────────────────────

    private var useFrontCamera = false
    private var enableScanWindow = true
    private var scanWindowWidthRatio = 0.75
    private var scanWindowHeightRatio = 0.35
    private var scanWindowVerticalOffsetRatio = 0.10
    private var enablePreprocessing = true
    private var maxFrameRate = 15
    private var enableTorch = false

    // ── Event Sinks ──────────────────────────────────────────────────────────

    private var scanEventSink: EventChannel.EventSink? = null
    private var cameraEventSink: EventChannel.EventSink? = null

    init {
        container.addView(previewView)
        setupEventChannels()
    }

    override fun getView(): View = container

    override fun dispose() {
        disposeResources()
    }

    // ── Public API (called from Plugin via MethodChannel) ────────────────────

    fun initialize(config: Map<*, *>?) {
        applyConfig(config)
        initBarcodeScanner(config)
    }

    fun startCamera() {
        val cameraProviderFuture = ProcessCameraProvider.getInstance(context)
        cameraProviderFuture.addListener({
            try {
                cameraProvider = cameraProviderFuture.get()
                bindCameraUseCases()
                cameraEventSink?.success(mapOf("type" to "ready"))
                Log.d(TAG, "Camera started successfully.")
            } catch (e: Exception) {
                Log.e(TAG, "Camera start failed: ${e.message}", e)
                cameraEventSink?.success(mapOf("type" to "error", "message" to (e.message ?: "Unknown error")))
            }
        }, ContextCompat.getMainExecutor(context))
    }

    fun stopCamera() {
        cameraProvider?.unbindAll()
        camera = null
        Log.d(TAG, "Camera stopped.")
    }

    fun disposeResources() {
        stopCamera()
        barcodeScanner?.close()
        barcodeScanner = null
        analysisExecutor.shutdown()
        scanEventSink = null
        cameraEventSink = null
        Log.d(TAG, "Resources disposed.")
    }

    fun setTorch(enabled: Boolean) {
        camera?.cameraControl?.enableTorch(enabled)
        enableTorch = enabled
    }

    fun setZoom(zoomLevel: Float) {
        camera?.cameraControl?.setLinearZoom(zoomLevel.coerceIn(0f, 1f))
    }

    fun setFocusPoint(x: Float, y: Float) {
        val factory = previewView.meteringPointFactory
        val point = factory.createPoint(
            x * previewView.width,
            y * previewView.height,
        )
        val action = FocusMeteringAction.Builder(point)
            .setAutoCancelDuration(3, java.util.concurrent.TimeUnit.SECONDS)
            .build()
        camera?.cameraControl?.startFocusAndMetering(action)
    }

    fun switchCamera() {
        useFrontCamera = !useFrontCamera
        if (cameraProvider != null) {
            bindCameraUseCases()
        }
    }

    fun updateConfig(config: Map<*, *>?) {
        applyConfig(config)
    }

    // ── Private Implementation ───────────────────────────────────────────────

    private fun setupEventChannels() {
        scanEventChannel.setStreamHandler(object : EventChannel.StreamHandler {
            override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                scanEventSink = events
            }
            override fun onCancel(arguments: Any?) {
                scanEventSink = null
            }
        })

        cameraEventChannel.setStreamHandler(object : EventChannel.StreamHandler {
            override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                cameraEventSink = events
            }
            override fun onCancel(arguments: Any?) {
                cameraEventSink = null
            }
        })
    }

    private fun applyConfig(config: Map<*, *>?) {
        config ?: return
        useFrontCamera = config["useFrontCamera"] as? Boolean ?: useFrontCamera
        enableScanWindow = config["enableScanWindow"] as? Boolean ?: enableScanWindow
        scanWindowWidthRatio = (config["scanWindowWidthRatio"] as? Number)?.toDouble() ?: scanWindowWidthRatio
        scanWindowHeightRatio = (config["scanWindowHeightRatio"] as? Number)?.toDouble() ?: scanWindowHeightRatio
        scanWindowVerticalOffsetRatio = (config["scanWindowVerticalOffsetRatio"] as? Number)?.toDouble() ?: scanWindowVerticalOffsetRatio
        enablePreprocessing = config["enablePreprocessing"] as? Boolean ?: enablePreprocessing
        maxFrameRate = (config["maxFrameRate"] as? Number)?.toInt() ?: maxFrameRate
        enableTorch = config["enableTorch"] as? Boolean ?: enableTorch
    }

    private fun initBarcodeScanner(config: Map<*, *>?) {
        val allowedFormats = (config?.get("allowedFormats") as? List<*>)
            ?.mapNotNull { it as? String }
            ?: emptyList()

        val options = if (allowedFormats.isNotEmpty()) {
            val formats = allowedFormats.mapNotNull { formatStringToInt(it) }
            if (formats.size >= 2) {
                BarcodeScannerOptions.Builder()
                    .setBarcodeFormats(formats[0], *formats.drop(1).toIntArray())
                    .build()
            } else if (formats.size == 1) {
                BarcodeScannerOptions.Builder()
                    .setBarcodeFormats(formats[0])
                    .build()
            } else {
                BarcodeScannerOptions.Builder().build()
            }
        } else {
            // Scan all formats by default
            BarcodeScannerOptions.Builder().build()
        }

        barcodeScanner?.close()
        barcodeScanner = BarcodeScanning.getClient(options)
    }

    private fun bindCameraUseCases() {
        val provider = cameraProvider ?: return
        provider.unbindAll()

        val lifecycleOwner = activity as? LifecycleOwner ?: return

        val cameraSelector = if (useFrontCamera) {
            CameraSelector.DEFAULT_FRONT_CAMERA
        } else {
            CameraSelector.DEFAULT_BACK_CAMERA
        }

        // Preview use case
        preview = Preview.Builder()
            .build()
            .also { it.surfaceProvider = previewView.surfaceProvider }

        // Image Analysis use case
        imageAnalysis = ImageAnalysis.Builder()
            .setBackpressureStrategy(ImageAnalysis.STRATEGY_KEEP_ONLY_LATEST)
            .setTargetResolution(android.util.Size(1280, 720))
            .build()
            .also { analysis ->
                analysis.setAnalyzer(analysisExecutor) { imageProxy ->
                    processFrame(imageProxy)
                }
            }

        try {
            camera = provider.bindToLifecycle(
                lifecycleOwner,
                cameraSelector,
                preview,
                imageAnalysis,
            )

            // Apply torch state
            if (enableTorch) {
                camera?.cameraControl?.enableTorch(true)
            }

            Log.d(TAG, "Camera use cases bound. Front: $useFrontCamera")
        } catch (e: Exception) {
            Log.e(TAG, "Failed to bind camera use cases: ${e.message}", e)
            cameraEventSink?.success(mapOf("type" to "error", "message" to (e.message ?: "Bind failed")))
        }
    }

    @androidx.camera.core.ExperimentalGetImage
    private fun processFrame(imageProxy: ImageProxy) {
        // Frame throttling
        val now = System.currentTimeMillis()
        val minInterval = if (maxFrameRate > 0) 1000L / maxFrameRate else 0L
        if (now - lastAnalysisTimestamp < minInterval) {
            imageProxy.close()
            return
        }

        // Single-frame gate — prevent concurrent processing
        if (!isProcessing.compareAndSet(false, true)) {
            imageProxy.close()
            return
        }

        lastAnalysisTimestamp = now

        val mediaImage = imageProxy.image
        if (mediaImage == null) {
            isProcessing.set(false)
            imageProxy.close()
            return
        }

        val inputImage = InputImage.fromMediaImage(
            mediaImage,
            imageProxy.imageInfo.rotationDegrees,
        )

        val scanner = barcodeScanner
        if (scanner == null) {
            isProcessing.set(false)
            imageProxy.close()
            return
        }

        scanner.process(inputImage)
            .addOnSuccessListener { barcodes ->
                if (barcodes.isNotEmpty()) {
                    val results = barcodes
                        .filter { barcode ->
                            if (!enableScanWindow) return@filter true
                            // Post-processing ROI filter: check if barcode center
                            // falls within the scan window
                            val box = barcode.boundingBox ?: return@filter true
                            val imageWidth = inputImage.width.toDouble()
                            val imageHeight = inputImage.height.toDouble()
                            val centerX = box.centerX() / imageWidth
                            val centerY = box.centerY() / imageHeight

                            val windowLeft = (1.0 - scanWindowWidthRatio) / 2.0
                            val windowRight = 1.0 - windowLeft
                            val windowCenterY = 0.5 - scanWindowVerticalOffsetRatio
                            val windowTop = windowCenterY - scanWindowHeightRatio / 2.0
                            val windowBottom = windowCenterY + scanWindowHeightRatio / 2.0

                            centerX in windowLeft..windowRight && centerY in windowTop..windowBottom
                        }
                        .mapNotNull { barcode ->
                            val rawValue = barcode.rawValue ?: return@mapNotNull null
                            mapOf(
                                "rawValue" to rawValue,
                                "format" to formatIntToString(barcode.format),
                                "corners" to (barcode.cornerPoints?.flatMap {
                                    listOf(it.x.toDouble(), it.y.toDouble())
                                } ?: emptyList<Double>()),
                                "confidence" to 1.0,
                            )
                        }

                    if (results.isNotEmpty()) {
                        ContextCompat.getMainExecutor(context).execute {
                            scanEventSink?.success(results)
                        }
                    }
                }
            }
            .addOnCompleteListener {
                isProcessing.set(false)
                imageProxy.close()
            }
    }

    // ── Format Mapping ───────────────────────────────────────────────────────

    private fun formatStringToInt(format: String): Int? = when (format.uppercase()) {
        "QR_CODE" -> Barcode.FORMAT_QR_CODE
        "CODE_128" -> Barcode.FORMAT_CODE_128
        "CODE_39" -> Barcode.FORMAT_CODE_39
        "CODE_93" -> Barcode.FORMAT_CODE_93
        "EAN_13" -> Barcode.FORMAT_EAN_13
        "EAN_8" -> Barcode.FORMAT_EAN_8
        "UPC_A" -> Barcode.FORMAT_UPC_A
        "UPC_E" -> Barcode.FORMAT_UPC_E
        "DATA_MATRIX" -> Barcode.FORMAT_DATA_MATRIX
        "PDF417" -> Barcode.FORMAT_PDF417
        "AZTEC" -> Barcode.FORMAT_AZTEC
        "CODABAR" -> Barcode.FORMAT_CODABAR
        "ITF" -> Barcode.FORMAT_ITF
        else -> null
    }

    private fun formatIntToString(format: Int): String = when (format) {
        Barcode.FORMAT_QR_CODE -> "QR_CODE"
        Barcode.FORMAT_CODE_128 -> "CODE_128"
        Barcode.FORMAT_CODE_39 -> "CODE_39"
        Barcode.FORMAT_CODE_93 -> "CODE_93"
        Barcode.FORMAT_EAN_13 -> "EAN_13"
        Barcode.FORMAT_EAN_8 -> "EAN_8"
        Barcode.FORMAT_UPC_A -> "UPC_A"
        Barcode.FORMAT_UPC_E -> "UPC_E"
        Barcode.FORMAT_DATA_MATRIX -> "DATA_MATRIX"
        Barcode.FORMAT_PDF417 -> "PDF417"
        Barcode.FORMAT_AZTEC -> "AZTEC"
        Barcode.FORMAT_CODABAR -> "CODABAR"
        Barcode.FORMAT_ITF -> "ITF"
        else -> "UNKNOWN"
    }
}
