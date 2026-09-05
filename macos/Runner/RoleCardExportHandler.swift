import AppKit
import Darwin
import FlutterMacOS
import Foundation
import ImageIO

final class RoleCardExportHandler {
  static let shared = RoleCardExportHandler()
  static let channelName = "com.xuwudi.ochome/role_card_export"

  private weak var window: NSWindow?
  private var savePanel: NSOpenPanel?
  private let fileQueue = DispatchQueue(label: "com.xuwudi.ochome.role-card-files")
  // All operation and panel state stays on main; file work runs on fileQueue.
  private var pendingSave: (id: UUID, result: FlutterResult)?

  func register(with messenger: FlutterBinaryMessenger, window: NSWindow) {
    self.window = window
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
        DispatchQueue.main.async { self.chooseDirectory(for: urls, id: id) }
      } catch {
        self.finish(id, value: FlutterError(
          code: "invalidFiles", message: "角色卡图片不完整，请重新生成后再保存", details: nil
        ))
      }
    }
  }

  private func chooseDirectory(for urls: [URL], id: UUID) {
    guard let window = window else {
      finish(id, value: FlutterError(
        code: "saveFailed", message: "暂时无法打开保存位置，请重新尝试", details: nil
      ))
      return
    }
    let panel = NSOpenPanel()
    panel.title = "保存角色卡"
    panel.message = "选择文件夹，角色卡会保存在一个新的独立文件夹中"
    panel.prompt = "保存到这里"
    panel.canChooseDirectories = true
    panel.canChooseFiles = false
    panel.allowsMultipleSelection = false
    panel.canCreateDirectories = true
    savePanel = panel
    panel.beginSheetModal(for: window) { response in
      self.savePanel = nil
      guard response == .OK, let directory = panel.url else {
        self.finish(id, value: ["status": "cancelled", "count": 0])
        return
      }
      // A panel URL may already carry a sandbox grant. A false return does not
      // necessarily mean access was denied; let the actual file operation decide.
      let accessed = directory.startAccessingSecurityScopedResource()
      self.fileQueue.async {
        defer { if accessed { directory.stopAccessingSecurityScopedResource() } }
        do {
          let destination = try RoleCardExportFiles.copyJob(urls: urls, to: directory)
          self.finish(id, value: [
            "status": "saved", "count": urls.count, "directory": destination.path,
          ])
        } catch {
          self.finish(id, value: FlutterError(
            code: "saveFailed", message: "角色卡未能保存到所选文件夹，请检查可用空间或换个位置重试",
            details: nil
          ))
        }
      }
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
    // path_provider appends the bundle identifier to macOS NSCachesDirectory,
    // including when NSCachesDirectory is already within the app sandbox.
    var roots = [fm.temporaryDirectory.appendingPathComponent(folderName, isDirectory: true)]
    if let bundleID = Bundle.main.bundleIdentifier {
      roots += fm.urls(for: .cachesDirectory, in: .userDomainMask).map {
        $0.appendingPathComponent(bundleID, isDirectory: true)
          .appendingPathComponent(folderName, isDirectory: true)
      }
    }
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

  /// Stage the entire ordered job, then rename within the chosen directory.
  /// FileManager refuses an existing destination; no user file is replaced.
  static func copyJob(urls: [URL], to directory: URL) throws -> URL {
    guard !urls.isEmpty else { throw RoleCardExportFileError.invalidFiles }
    let fm = FileManager.default
    let jobID = UUID().uuidString.lowercased()
    let staging = directory.appendingPathComponent(".zaidang-card-\(jobID).partial", isDirectory: true)
    let destination = directory.appendingPathComponent("崽档角色卡-\(jobID)", isDirectory: true)
    // mkdir is exclusive: even a name collision cannot make cleanup own an
    // existing directory (createDirectory may succeed for an existing directory).
    guard mkdir(staging.path, 0o700) == 0 else {
      throw NSError(domain: NSPOSIXErrorDomain, code: Int(errno))
    }
    var committed = false
    defer { if !committed { try? fm.removeItem(at: staging) } }
    for (index, source) in urls.enumerated() {
      let filename = String(format: "zaidang-card-%03d.png", index + 1)
      try fm.copyItem(at: source, to: staging.appendingPathComponent(filename))
    }
    try fm.moveItem(at: staging, to: destination)
    committed = true
    return destination
  }
}
