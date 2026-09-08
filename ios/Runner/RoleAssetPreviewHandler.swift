import Flutter
import UIKit

/// Keeps the system file preview while separating its title from immutable storage names.
final class RoleAssetPreviewHandler: NSObject, UIDocumentInteractionControllerDelegate {
  static let shared = RoleAssetPreviewHandler()
  static let channelName = "com.xuwudi.ochome/role_asset_preview"

  private let findPresenter: () -> UIViewController?
  private let presentPreview: (UIDocumentInteractionController) -> Bool
  // All request state and UIKit work is confined to the main thread.
  private var pending: (
    controller: UIDocumentInteractionController,
    presenter: UIViewController,
    result: FlutterResult
  )?

  init(
    findPresenter: @escaping () -> UIViewController? = RoleAssetPreviewHandler.activePresenter,
    presentPreview: @escaping (UIDocumentInteractionController) -> Bool = {
      $0.presentPreview(animated: true)
    }
  ) {
    self.findPresenter = findPresenter
    self.presentPreview = presentPreview
    super.init()
  }

  func register(with messenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(name: Self.channelName, binaryMessenger: messenger)
    channel.setMethodCallHandler { [self] call, result in
      handle(call, result: result)
    }
  }

  func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard Thread.isMainThread else {
      DispatchQueue.main.async { self.handle(call, result: result) }
      return
    }
    guard call.method == "openPreview" else {
      result(FlutterMethodNotImplemented)
      return
    }
    guard pending == nil else {
      result(FlutterError(code: "busy", message: "正在预览资产，请关闭后重试", details: nil))
      return
    }
    guard let args = call.arguments as? [String: Any],
      let path = args["path"] as? String,
      (path as NSString).isAbsolutePath,
      !path.contains("\0"),
      let displayName = args["displayName"] as? String,
      !displayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    else {
      result(FlutterError(code: "invalidArguments", message: "资产预览参数不完整", details: nil))
      return
    }
    let url = URL(fileURLWithPath: path)
    guard FileManager.default.isReadableFile(atPath: path),
      let values = try? url.resourceValues(forKeys: [.isRegularFileKey]),
      values.isRegularFile == true
    else {
      result(FlutterError(code: "fileNotFound", message: "资产文件不存在或无法读取", details: nil))
      return
    }
    guard let presenter = findPresenter() else {
      result(FlutterError(code: "noPresenter", message: "暂时无法显示资产预览，请重试", details: nil))
      return
    }

    let controller = UIDocumentInteractionController(url: url)
    let originalUTI = controller.uti
    controller.name = displayName
    // A title with a different suffix must not change the source's format routing.
    controller.uti = originalUTI
    controller.delegate = self
    pending = (controller, presenter, result)
    if !presentPreview(controller) {
      finish(controller, value: false)
    }
  }

  func documentInteractionControllerViewControllerForPreview(
    _ controller: UIDocumentInteractionController
  ) -> UIViewController {
    // UIKit requests this synchronously while presenting the retained controller.
    guard let pending, pending.controller === controller else { return UIViewController() }
    return pending.presenter
  }

  func documentInteractionControllerDidEndPreview(_ controller: UIDocumentInteractionController) {
    finish(controller, value: true)
  }

  private func finish(_ controller: UIDocumentInteractionController, value: Bool) {
    guard Thread.isMainThread else {
      DispatchQueue.main.async { self.finish(controller, value: value) }
      return
    }
    guard let request = pending, request.controller === controller else { return }
    // Release before delivering the result, so a following request cannot be ended twice.
    request.controller.delegate = nil
    pending = nil
    request.result(value)
  }

  private static func activePresenter() -> UIViewController? {
    let window = UIApplication.shared.connectedScenes
      .compactMap { $0 as? UIWindowScene }
      .filter { $0.activationState == .foregroundActive }
      .flatMap(\.windows)
      .first { $0.isKeyWindow }
    guard var presenter = window?.rootViewController else { return nil }
    while let presented = presenter.presentedViewController {
      guard !presented.isBeingDismissed else { return nil }
      presenter = presented
    }
    guard !presenter.isBeingPresented, !presenter.isBeingDismissed else { return nil }
    return presenter
  }
}
