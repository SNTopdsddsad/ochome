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

#if canImport(Flutter) || canImport(FlutterMacOS)
final class VideoThumbnailHandler {
  static let shared = VideoThumbnailHandler()
  private let queue = DispatchQueue(label: "com.xuwudi.ochome.video-thumbnails", qos: .utility)

  func register(with messenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(name: "com.xuwudi.ochome/video_thumbnail", binaryMessenger: messenger)
    channel.setMethodCallHandler { [self] call, result in
      guard call.method == "firstFrame" else {
        result(FlutterMethodNotImplemented)
        return
      }
      guard let args = call.arguments as? [String: Any],
        let source = args["videoPath"] as? String,
        let destination = args["thumbnailPath"] as? String,
        let dimension = args["maxDimension"] as? Int,
        (source as NSString).isAbsolutePath,
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
