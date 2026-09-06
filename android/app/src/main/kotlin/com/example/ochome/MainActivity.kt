package com.example.ochome

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

class MainActivity : FlutterActivity() {
    private var videoThumbnails: VideoThumbnailHandler? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        videoThumbnails = VideoThumbnailHandler(flutterEngine.dartExecutor.binaryMessenger)
    }

    override fun cleanUpFlutterEngine(flutterEngine: FlutterEngine) {
        videoThumbnails?.dispose()
        videoThumbnails = null
        super.cleanUpFlutterEngine(flutterEngine)
    }
}
