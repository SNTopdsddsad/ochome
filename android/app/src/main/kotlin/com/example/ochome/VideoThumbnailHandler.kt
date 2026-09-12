package com.example.ochome

import android.graphics.Bitmap
import android.media.MediaMetadataRetriever
import android.os.Build
import android.os.Handler
import android.os.Looper
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.util.concurrent.Executors
import kotlin.math.roundToInt

class VideoThumbnailHandler(messenger: BinaryMessenger) {
    private val worker = Executors.newSingleThreadExecutor()
    private val main = Handler(Looper.getMainLooper())
    private val channel = MethodChannel(messenger, "com.xuwudi.ochome/video_thumbnail")

    init {
        channel.setMethodCallHandler { call, result ->
            when (call.method) {
                "firstFrame" -> {
                    val source = call.argument<String>("videoPath")
                    val destination = call.argument<String>("thumbnailPath")
                    val size = call.argument<Int>("maxDimension") ?: 320
                    if (source == null || destination == null || size !in 1..1024 ||
                        !File(source).isAbsolute || !File(destination).isAbsolute) {
                        result.success(false)
                    } else {
                        worker.execute {
                            val success = firstFrame(source, destination, size)
                            main.post { result.success(success) }
                        }
                    }
                }
                "duration" -> {
                    val source = call.argument<String>("videoPath")
                    if (source == null || !File(source).isAbsolute) {
                        result.success(null)
                    } else {
                        worker.execute {
                            val duration = durationMilliseconds(source)
                            main.post { result.success(duration) }
                        }
                    }
                }
                else -> result.notImplemented()
            }
        }
    }

    fun dispose() {
        channel.setMethodCallHandler(null)
        worker.shutdown()
    }

    private fun firstFrame(source: String, destination: String, size: Int): Boolean {
        val retriever = MediaMetadataRetriever()
        var original: Bitmap? = null
        var scaled: Bitmap? = null
        return try {
            retriever.setDataSource(source)
            original = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O_MR1) {
                retriever.getScaledFrameAtTime(0, MediaMetadataRetriever.OPTION_CLOSEST, size, size)
            } else {
                retriever.getFrameAtTime(0, MediaMetadataRetriever.OPTION_CLOSEST)
            }
            val frame = original ?: return false
            val ratio = minOf(1.0, size.toDouble() / maxOf(frame.width, frame.height))
            scaled = if (ratio < 1.0) Bitmap.createScaledBitmap(
                frame, maxOf(1, (frame.width * ratio).roundToInt()),
                maxOf(1, (frame.height * ratio).roundToInt()), true
            ) else frame
            File(destination).outputStream().use { scaled!!.compress(Bitmap.CompressFormat.JPEG, 82, it) }
        } catch (_: Exception) {
            false
        } catch (_: OutOfMemoryError) {
            false
        } finally {
            if (scaled !== original) scaled?.recycle()
            original?.recycle()
            try { retriever.release() } catch (_: Exception) { }
        }
    }

    private fun durationMilliseconds(source: String): Long? {
        val retriever = MediaMetadataRetriever()
        return try {
            retriever.setDataSource(source)
            retriever.extractMetadata(MediaMetadataRetriever.METADATA_KEY_DURATION)
                ?.toLongOrNull()
                ?.takeIf { it > 0L }
        } catch (_: Exception) {
            null
        } finally {
            try { retriever.release() } catch (_: Exception) { }
        }
    }
}
