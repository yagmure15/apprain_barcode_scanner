package com.apprain.barcode_scanner

import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/**
 * ApprainBarcodeScannerPlugin — Flutter plugin entry point for Android.
 *
 * Registers the PlatformView factory and sets up MethodChannel / EventChannel
 * communication between Flutter and native CameraX + ML Kit scanning.
 */
class ApprainBarcodeScannerPlugin : FlutterPlugin, ActivityAware, MethodChannel.MethodCallHandler {

    private lateinit var methodChannel: MethodChannel
    private lateinit var scanEventChannel: EventChannel
    private lateinit var cameraEventChannel: EventChannel
    private var scannerViewFactory: ScannerPlatformViewFactory? = null
    private var activityBinding: ActivityPluginBinding? = null

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        methodChannel = MethodChannel(binding.binaryMessenger, "com.apprain.barcode_scanner/methods")
        methodChannel.setMethodCallHandler(this)

        scanEventChannel = EventChannel(binding.binaryMessenger, "com.apprain.barcode_scanner/scan_results")
        cameraEventChannel = EventChannel(binding.binaryMessenger, "com.apprain.barcode_scanner/camera_events")

        scannerViewFactory = ScannerPlatformViewFactory(
            messenger = binding.binaryMessenger,
            scanEventChannel = scanEventChannel,
            cameraEventChannel = cameraEventChannel,
        )

        binding.platformViewRegistry.registerViewFactory(
            "com.apprain.barcode_scanner/scanner_view",
            scannerViewFactory!!,
        )
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        methodChannel.setMethodCallHandler(null)
        scannerViewFactory?.dispose()
        scannerViewFactory = null
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        val view = scannerViewFactory?.activeView
        when (call.method) {
            "initialize" -> {
                view?.initialize(call.arguments as? Map<*, *>)
                result.success(null)
            }
            "startCamera" -> {
                view?.startCamera()
                result.success(null)
            }
            "stopCamera" -> {
                view?.stopCamera()
                result.success(null)
            }
            "dispose" -> {
                view?.disposeResources()
                result.success(null)
            }
            "setTorch" -> {
                val enabled = (call.arguments as? Map<*, *>)?.get("enabled") as? Boolean ?: false
                view?.setTorch(enabled)
                result.success(null)
            }
            "setZoom" -> {
                val zoom = ((call.arguments as? Map<*, *>)?.get("zoom") as? Number)?.toFloat() ?: 0f
                view?.setZoom(zoom)
                result.success(null)
            }
            "setFocusPoint" -> {
                val args = call.arguments as? Map<*, *>
                val x = (args?.get("x") as? Number)?.toFloat() ?: 0.5f
                val y = (args?.get("y") as? Number)?.toFloat() ?: 0.5f
                view?.setFocusPoint(x, y)
                result.success(null)
            }
            "switchCamera" -> {
                view?.switchCamera()
                result.success(null)
            }
            "updateConfig" -> {
                view?.updateConfig(call.arguments as? Map<*, *>)
                result.success(null)
            }
            else -> result.notImplemented()
        }
    }

    // ── ActivityAware ────────────────────────────────────────────────────────

    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        activityBinding = binding
        scannerViewFactory?.activity = binding.activity
    }

    override fun onDetachedFromActivityForConfigChanges() {
        scannerViewFactory?.activity = null
    }

    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
        activityBinding = binding
        scannerViewFactory?.activity = binding.activity
    }

    override fun onDetachedFromActivity() {
        activityBinding = null
        scannerViewFactory?.activity = null
    }
}
