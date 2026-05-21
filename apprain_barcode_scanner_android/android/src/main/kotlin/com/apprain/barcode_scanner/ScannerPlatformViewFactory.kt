package com.apprain.barcode_scanner

import android.app.Activity
import android.content.Context
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.StandardMessageCodec
import io.flutter.plugin.platform.PlatformView
import io.flutter.plugin.platform.PlatformViewFactory

/**
 * Factory that creates [ScannerPlatformView] instances.
 *
 * Each Flutter widget that requests the view type "com.apprain.barcode_scanner/scanner_view"
 * will get a new [ScannerPlatformView] backed by CameraX + ML Kit.
 */
class ScannerPlatformViewFactory(
    private val messenger: BinaryMessenger,
    private val scanEventChannel: EventChannel,
    private val cameraEventChannel: EventChannel,
) : PlatformViewFactory(StandardMessageCodec.INSTANCE) {

    var activity: Activity? = null
    var activeView: ScannerPlatformView? = null
        private set

    override fun create(context: Context, viewId: Int, args: Any?): PlatformView {
        val creationParams = args as? Map<*, *>
        val view = ScannerPlatformView(
            context = context,
            activity = activity,
            viewId = viewId,
            creationParams = creationParams,
            scanEventChannel = scanEventChannel,
            cameraEventChannel = cameraEventChannel,
        )
        activeView = view
        return view
    }

    fun dispose() {
        activeView?.disposeResources()
        activeView = null
    }
}
