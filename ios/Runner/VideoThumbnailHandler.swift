import AVFoundation
import Foundation
import ImageIO

#if canImport(Flutter)
import Flutter
#elseif canImport(FlutterMacOS)
import FlutterMacOS
#endif

/// Shared AVFoundation path for iOS and macOS, independently testable without Flutter.
enum VideoThumbnailFrame {
  static func write(source: URL, destination: URL, maxDimension: Int) throws {
    guard source.isFileURL, destination.isFileURL, (1...1024).contains(maxDimension) else {
      throw NSError(domain: "VideoThumbnail", code: 1)
    }
    let generator = AVAssetImageGenerator(asset: AVURLAsset(url: source))
    generator.appliesPreferredTrackTransform = true
    generator.maximumSize = CGSize(width: CGFloat(maxDimension), height: CGFloat(maxDimension))
    generator.requestedTimeToleranceBefore = .zero
    generator.requestedTimeToleranceAfter = .zero
    let image = try generator.copyCGImage(at: .zero, actualTime: nil)
    guard let output = CGImageDestinationCreateWithURL(
      destination as CFURL, "public.jpeg" as CFString, 1, nil
    ) else { throw NSError(domain: "VideoThumbnail", code: 2) }
    CGImageDestinationAddImage(output, image, [
      kCGImageDestinationLossyCompressionQuality: 0.82
    ] as CFDictionary)
    guard CGImageDestinationFinalize(output) else {
      throw NSError(domain: "VideoThumbnail", code: 3)
    }
  }
}

/// Shared duration extraction for iOS and macOS, independently testable without Flutter.
enum VideoMetadata {
  static func durationMilliseconds(source: URL) -> Int64? {
    guard source.isFileURL else { return nil }
    let seconds = CMTimeGetSeconds(AVURLAsset(url: source).duration)
    guard seconds.isFinite, seconds > 0 else { return nil }
    let milliseconds = (seconds * 1_000).rounded()
    guard milliseconds >= 1, milliseconds <= Double(Int64.max) else { return nil }
    return Int64(milliseconds)
  }
}

#if canImport(Flutter) || canImport(FlutterMacOS)
final class VideoThumbnailHandler {
  static let shared = VideoThumbnailHandler()
  private let queue = DispatchQueue(label: "com.xuwudi.ochome.video-thumbnails", qos: .utility)

  func register(with messenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(name: "com.xuwudi.ochome/video_thumbnail", binaryMessenger: messenger)
    channel.setMethodCallHandler { [self] call, result in
      guard call.method == "firstFrame" || call.method == "duration" else {
        result(FlutterMethodNotImplemented)
        return
      }
      guard let args = call.arguments as? [String: Any],
        let source = args["videoPath"] as? String,
        (source as NSString).isAbsolutePath
      else {
        if call.method == "firstFrame" {
          result(false)
        } else {
          result(nil)
        }
        return
      }
      if call.method == "duration" {
        queue.async {
          let duration = autoreleasepool {
            VideoMetadata.durationMilliseconds(source: URL(fileURLWithPath: source))
          }
          DispatchQueue.main.async { result(duration) }
        }
        return
      }
      guard let destination = args["thumbnailPath"] as? String,
        let dimension = args["maxDimension"] as? Int,
        (destination as NSString).isAbsolutePath
      else {
        result(false)
        return
      }
      queue.async {
        let success: Bool = autoreleasepool {
          do {
            try VideoThumbnailFrame.write(
              source: URL(fileURLWithPath: source),
              destination: URL(fileURLWithPath: destination), maxDimension: dimension
            )
            return true
          } catch { return false }
        }
        DispatchQueue.main.async { result(success) }
      }
    }
  }
}
#endif
