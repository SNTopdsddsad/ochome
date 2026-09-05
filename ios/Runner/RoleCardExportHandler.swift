import Flutter
import Foundation
import ImageIO
import Photos

/// The only native export operation is saving a completed, application-owned PNG job.
final class RoleCardExportHandler {
  static let shared = RoleCardExportHandler()
  static let channelName = "com.xuwudi.ochome/role_card_export"

  private let fileQueue = DispatchQueue(label: "com.xuwudi.ochome.role-card-files")
  // Accessed only on main. The identifier also ignores an unexpected stale callback.
  private var pendingSave: (id: UUID, result: FlutterResult)?

  func register(with messenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(name: Self.channelName, binaryMessenger: messenger)
    channel.setMethodCallHandler { [self] call, result in
      DispatchQueue.main.async { self.handle(call, result: result) }
    }
  }

  private func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard call.method == "saveImages" else {
      result(FlutterMethodNotImplemented)
      return
    }
    guard pendingSave == nil else {
      result(FlutterError(code: "busy", message: "正在保存角色卡，请稍候", details: nil))
      return
    }
    let id = UUID()
    pendingSave = (id, result)
    fileQueue.async {
      do {
        let urls = try RoleCardExportFiles.validatedURLs(arguments: call.arguments)
        DispatchQueue.main.async { self.authorizeAndSave(urls, id: id) }
      } catch {
        self.finish(id, value: FlutterError(
          code: "invalidFiles", message: "角色卡图片不完整，请重新生成后再保存", details: nil
        ))
      }
    }
  }

  private func authorizeAndSave(_ urls: [URL], id: UUID) {
    // This method is reached only from an explicit save call, after every file validates.
    let status = PHPhotoLibrary.authorizationStatus(for: .addOnly)
    if status == .notDetermined {
      PHPhotoLibrary.requestAuthorization(for: .addOnly) { status in
        DispatchQueue.main.async { self.save(urls, authorization: status, id: id) }
      }
    } else {
      save(urls, authorization: status, id: id)
    }
  }

  private func save(_ urls: [URL], authorization: PHAuthorizationStatus, id: UUID) {
    switch authorization {
    case .authorized, .limited:
      // One transaction prevents a failed continuation page from leaving a partial set.
      PHPhotoLibrary.shared().performChanges {
        for url in urls {
          let request = PHAssetCreationRequest.forAsset()
          let options = PHAssetResourceCreationOptions()
          options.shouldMoveFile = false
          request.addResource(with: .photo, fileURL: url, options: options)
        }
      } completionHandler: { success, _ in
        if success {
          self.finish(id, value: ["status": "saved", "count": urls.count])
        } else {
          self.finish(id, value: FlutterError(
            code: "saveFailed", message: "角色卡未能保存到相册，请稍后重试", details: nil
          ))
        }
      }
    case .denied:
      finish(id, value: FlutterError(
        code: "permissionDenied",
        message: "未获得相册保存权限，可在系统设置中允许添加照片，或使用分享",
        details: nil
      ))
    case .restricted:
      finish(id, value: FlutterError(
        code: "restricted", message: "系统限制了相册保存，可尝试使用分享", details: nil
      ))
    case .notDetermined:
      finish(id, value: FlutterError(
        code: "permissionDenied", message: "未获得相册保存权限，请重新尝试", details: nil
      ))
    @unknown default:
      finish(id, value: FlutterError(
        code: "saveFailed", message: "暂时无法访问相册，请稍后重试", details: nil
      ))
    }
  }

  private func finish(_ id: UUID, value: Any) {
    DispatchQueue.main.async {
      guard let pending = self.pendingSave, pending.id == id else { return }
      self.pendingSave = nil
      pending.result(value)
    }
  }
}

enum RoleCardExportFileError: Error {
  case invalidFiles
}

enum RoleCardExportFiles {
  static let folderName = "role-card-exports"

  static func validatedURLs(arguments: Any?) throws -> [URL] {
    guard let args = arguments as? [String: Any], let paths = args["paths"] as? [String] else {
      throw RoleCardExportFileError.invalidFiles
    }
    let fm = FileManager.default
    // path_provider's getTemporaryDirectory uses NSCachesDirectory on Apple platforms.
    let roots = (fm.urls(for: .cachesDirectory, in: .userDomainMask) + [fm.temporaryDirectory])
      .map { $0.appendingPathComponent(folderName, isDirectory: true) }
    return try validate(paths: paths, allowedRoots: roots)
  }

  static func validate(paths: [String], allowedRoots: [URL]) throws -> [URL] {
    guard !paths.isEmpty else { throw RoleCardExportFileError.invalidFiles }
    let roots = Set(allowedRoots.map { $0.resolvingSymlinksInPath().standardizedFileURL.path })
    let fm = FileManager.default
    var urls: [URL] = []
    var seen = Set<String>()
    var jobDirectory: URL?
    for path in paths {
      guard (path as NSString).isAbsolutePath else { throw RoleCardExportFileError.invalidFiles }
      let url = URL(fileURLWithPath: path).resolvingSymlinksInPath().standardizedFileURL
      let parent = url.deletingLastPathComponent()
      guard url.pathExtension.lowercased() == "png",
        roots.contains(parent.deletingLastPathComponent().path),
        jobDirectory == nil || jobDirectory == parent,
        seen.insert(url.path).inserted,
        fm.isReadableFile(atPath: url.path)
      else { throw RoleCardExportFileError.invalidFiles }
      let values = try url.resourceValues(forKeys: [.isRegularFileKey, .fileSizeKey])
      guard values.isRegularFile == true, (values.fileSize ?? 0) > 8 else {
        throw RoleCardExportFileError.invalidFiles
      }
      let validPNG = autoreleasepool {
        guard let source = CGImageSourceCreateWithURL(
          url as CFURL, [kCGImageSourceShouldCache: false] as CFDictionary
        ), CGImageSourceGetType(source) as String? == "public.png",
          CGImageSourceGetCount(source) == 1,
          CGImageSourceGetStatus(source) == .statusComplete,
          CGImageSourceCopyPropertiesAtIndex(source, 0, nil) != nil
        else { return false }
        return true
      }
      guard validPNG else { throw RoleCardExportFileError.invalidFiles }
      jobDirectory = parent
      urls.append(url)
    }
    return urls
  }
}
