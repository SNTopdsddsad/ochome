// Run with:
// swiftc ios/Runner/VideoThumbnailHandler.swift test/native/video_thumbnail_test.swift -o /tmp/video-thumbnail-test
// /tmp/video-thumbnail-test
import AVFoundation
import CoreGraphics
import Foundation
import ImageIO

@main
struct VideoThumbnailTest {
  static func main() throws {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: root) }
    for rotated in [false, true] {
      let source = root.appendingPathComponent(rotated ? "portrait.mov" : "landscape.mov")
      try makeVideo(source, rotated: rotated)
      guard let duration = VideoMetadata.durationMilliseconds(source: source) else {
        fatalError("Readable video must have a duration")
      }
      precondition((1_990...2_010).contains(duration), "Duration must come from the media timeline")
      let destination = source.appendingPathExtension("jpg")
      try VideoThumbnailFrame.write(source: source, destination: destination, maxDimension: 32)
      guard let imageSource = CGImageSourceCreateWithURL(destination as CFURL, nil),
        let image = CGImageSourceCreateImageAtIndex(imageSource, 0, nil) else {
        fatalError("Thumbnail is not a readable image")
      }
      precondition(image.width == (rotated ? 16 : 32))
      precondition(image.height == (rotated ? 32 : 16))
      var rgba = [UInt8](repeating: 0, count: 4)
      let context = CGContext(data: &rgba, width: 1, height: 1, bitsPerComponent: 8,
        bytesPerRow: 4, space: CGColorSpaceCreateDeviceRGB(),
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
      context.draw(image, in: CGRect(x: 0, y: 0, width: 1, height: 1))
      precondition(rgba[0] > 180 && rgba[2] < 80, "Must extract red first frame, not later blue frame")
      precondition(FileManager.default.fileExists(atPath: source.path))
    }
    let broken = root.appendingPathComponent("broken.mp4")
    try Data("broken video".utf8).write(to: broken)
    do {
      try VideoThumbnailFrame.write(source: broken, destination: root.appendingPathComponent("broken.jpg"), maxDimension: 32)
      fatalError("Broken video must fail")
    } catch { }
    precondition(VideoMetadata.durationMilliseconds(source: broken) == nil)
    print("PASS: first frame, duration, aspect ratio, portrait rotation, source retention and invalid video")
  }

  static func makeVideo(_ url: URL, rotated: Bool) throws {
    let writer = try AVAssetWriter(outputURL: url, fileType: .mov)
    let input = AVAssetWriterInput(mediaType: .video, outputSettings: [
      AVVideoCodecKey: AVVideoCodecType.h264, AVVideoWidthKey: 64, AVVideoHeightKey: 32
    ])
    if rotated { input.transform = CGAffineTransform(rotationAngle: .pi / 2) }
    let adaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: input,
      sourcePixelBufferAttributes: [
        kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32ARGB,
        kCVPixelBufferWidthKey as String: 64, kCVPixelBufferHeightKey as String: 32,
        kCVPixelBufferCGImageCompatibilityKey as String: true,
        kCVPixelBufferCGBitmapContextCompatibilityKey as String: true
      ])
    writer.add(input)
    guard writer.startWriting() else {
      throw writer.error ?? NSError(domain: "VideoFixture", code: 1)
    }
    writer.startSession(atSourceTime: .zero)
    for index in 0..<2 {
      var buffer: CVPixelBuffer?
      let result = CVPixelBufferCreate(kCFAllocatorDefault, 64, 32, kCVPixelFormatType_32ARGB, nil, &buffer)
      precondition(result == kCVReturnSuccess)
      let pixels = buffer!
      CVPixelBufferLockBaseAddress(pixels, [])
      let base = CVPixelBufferGetBaseAddress(pixels)!.assumingMemoryBound(to: UInt8.self)
      let stride = CVPixelBufferGetBytesPerRow(pixels)
      for y in 0..<32 {
        for x in 0..<64 {
          let offset = y * stride + x * 4
          base[offset] = 255
          base[offset + 1] = index == 0 ? 255 : 0
          base[offset + 2] = 0
          base[offset + 3] = index == 0 ? 0 : 255
        }
      }
      CVPixelBufferUnlockBaseAddress(pixels, [])
      let deadline = Date().addingTimeInterval(5)
      while !input.isReadyForMoreMediaData && Date() < deadline { Thread.sleep(forTimeInterval: 0.01) }
      precondition(input.isReadyForMoreMediaData)
      precondition(adaptor.append(pixels, withPresentationTime: CMTime(value: Int64(index), timescale: 1)))
    }
    input.markAsFinished()
    writer.endSession(atSourceTime: CMTime(value: 2, timescale: 1))
    let done = DispatchSemaphore(value: 0)
    writer.finishWriting { done.signal() }
    precondition(done.wait(timeout: .now() + 10) == .success)
    precondition(writer.status == .completed, "Video fixture encoding failed")
  }
}
