import Flutter
import UIKit
import XCTest
@testable import Runner

final class RoleAssetPreviewTests: XCTestCase {
  private var root: URL!

  override func setUpWithError() throws {
    root = FileManager.default.temporaryDirectory
      .appendingPathComponent("role-asset-preview-tests-\(UUID().uuidString)")
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
  }

  override func tearDownWithError() throws {
    try FileManager.default.removeItem(at: root)
  }

  @MainActor
  func testPreviewUsesDisplayNameAndOriginalURLWithoutChangingSource() throws {
    let source = try makeSource()
    let originalBytes = try Data(contentsOf: source)
    let inferredUTI = UIDocumentInteractionController(url: source).uti
    XCTAssertNotNil(inferredUTI)
    let presenter = UIViewController()
    var preview: UIDocumentInteractionController?
    let handler = RoleAssetPreviewHandler(findPresenter: { presenter }) { controller in
      XCTAssertTrue(Thread.isMainThread)
      preview = controller
      return true
    }
    var results: [Any?] = []

    // Deliberately different title suffix: the original URL still owns the media type.
    handler.handle(openCall(source, name: "角色动作参考.txt")) { results.append($0) }

    let controller = try XCTUnwrap(preview)
    XCTAssertEqual(controller.name, "角色动作参考.txt")
    XCTAssertEqual(controller.url, source)
    XCTAssertEqual(controller.uti, inferredUTI)
    XCTAssertTrue(controller.delegate === handler)
    XCTAssertTrue(handler.documentInteractionControllerViewControllerForPreview(controller) === presenter)
    XCTAssertTrue(results.isEmpty, "Keep the Dart request pending until preview dismissal")
    XCTAssertEqual(try Data(contentsOf: source), originalBytes)
    XCTAssertEqual(try FileManager.default.contentsOfDirectory(atPath: root.path), [source.lastPathComponent])

    handler.documentInteractionControllerDidEndPreview(controller)
    XCTAssertEqual(results.count, 1)
    XCTAssertEqual(results.first as? Bool, true)
    XCTAssertNil(controller.delegate)
  }

  @MainActor
  func testRepeatedRenameBusyAndStaleDismissalsPreserveCurrentRequest() throws {
    let source = try makeSource()
    let presenter = UIViewController()
    var previews: [UIDocumentInteractionController] = []
    let handler = RoleAssetPreviewHandler(findPresenter: { presenter }) {
      previews.append($0)
      return true
    }
    var firstResults: [Any?] = []
    var secondResults: [Any?] = []
    handler.handle(openCall(source, name: "第一版.mp4")) { firstResults.append($0) }
    let first = try XCTUnwrap(previews.first)
    handler.documentInteractionControllerDidEndPreview(first)
    handler.documentInteractionControllerDidEndPreview(first)
    XCTAssertEqual(firstResults.count, 1)

    handler.handle(openCall(source, name: "第二版.mp4")) { secondResults.append($0) }
    let second = try XCTUnwrap(previews.last)
    XCTAssertFalse(first === second)
    XCTAssertEqual(second.name, "第二版.mp4")
    XCTAssertEqual(second.url, source)
    handler.documentInteractionControllerDidEndPreview(first)
    XCTAssertTrue(secondResults.isEmpty)

    var busyResult: Any?
    handler.handle(openCall(source, name: "第三版.mp4")) { busyResult = $0 }
    XCTAssertEqual((busyResult as? FlutterError)?.code, "busy")
    XCTAssertEqual(previews.count, 2)
    XCTAssertTrue(secondResults.isEmpty)

    handler.documentInteractionControllerDidEndPreview(second)
    handler.documentInteractionControllerDidEndPreview(second)
    XCTAssertEqual(secondResults.count, 1)
    XCTAssertEqual(secondResults.first as? Bool, true)
  }

  @MainActor
  func testUnsupportedPreviewReturnsFalseAndAllowsNextRequest() throws {
    let source = try makeSource()
    let presenter = UIViewController()
    var unsupported: UIDocumentInteractionController?
    let handler = RoleAssetPreviewHandler(findPresenter: { presenter }) {
      unsupported = $0
      return false
    }
    var firstResults: [Any?] = []
    handler.handle(openCall(source)) { firstResults.append($0) }
    let controller = try XCTUnwrap(unsupported)
    XCTAssertEqual(firstResults.count, 1)
    XCTAssertEqual(firstResults.first as? Bool, false)
    XCTAssertNil(controller.delegate)
    handler.documentInteractionControllerDidEndPreview(controller)
    XCTAssertEqual(firstResults.count, 1)

    var nextResult: Any?
    handler.handle(openCall(source)) { nextResult = $0 }
    XCTAssertEqual(nextResult as? Bool, false)
  }

  @MainActor
  func testInvalidMissingAndDirectoryInputsNeverPresentAndAllowRetry() throws {
    let source = try makeSource()
    let presenter = UIViewController()
    var presentCount = 0
    let handler = RoleAssetPreviewHandler(findPresenter: { presenter }) { _ in
      presentCount += 1
      return false
    }
    let invalid: [Any?] = [
      nil,
      ["path": source.path],
      ["path": 1, "displayName": "参考.mp4"],
      ["path": "relative.mp4", "displayName": "参考.mp4"],
      ["path": source.path, "displayName": " \n"],
      ["path": source.path, "displayName": 1],
    ]
    for arguments in invalid {
      var response: Any?
      handler.handle(FlutterMethodCall(methodName: "openPreview", arguments: arguments)) { response = $0 }
      XCTAssertEqual((response as? FlutterError)?.code, "invalidArguments")
    }
    for url in [root.appendingPathComponent("missing.mp4"), root!] {
      var response: Any?
      handler.handle(openCall(url)) { response = $0 }
      XCTAssertEqual((response as? FlutterError)?.code, "fileNotFound")
    }
    XCTAssertEqual(presentCount, 0)

    var retry: Any?
    handler.handle(openCall(source)) { retry = $0 }
    XCTAssertEqual(retry as? Bool, false)
    XCTAssertEqual(presentCount, 1)
  }

  @MainActor
  func testMissingPresenterReportsErrorAndAllowsRetry() throws {
    let source = try makeSource()
    var presenter: UIViewController?
    let handler = RoleAssetPreviewHandler(findPresenter: { presenter }) { _ in false }
    var response: Any?
    handler.handle(openCall(source)) { response = $0 }
    XCTAssertEqual((response as? FlutterError)?.code, "noPresenter")

    presenter = UIViewController()
    handler.handle(openCall(source)) { response = $0 }
    XCTAssertEqual(response as? Bool, false)
  }

  func testBackgroundInvocationPresentsAndReturnsOnMainThread() throws {
    let source = try makeSource()
    let completed = expectation(description: "Preview replied on main")
    let handler = RoleAssetPreviewHandler(findPresenter: {
      XCTAssertTrue(Thread.isMainThread)
      return UIViewController()
    }) { _ in
      XCTAssertTrue(Thread.isMainThread)
      return false
    }
    let call = openCall(source)
    DispatchQueue.global().async {
      handler.handle(call) { response in
        XCTAssertTrue(Thread.isMainThread)
        XCTAssertEqual(response as? Bool, false)
        completed.fulfill()
      }
    }
    wait(for: [completed], timeout: 3)
  }

  private func makeSource() throws -> URL {
    let source = root.appendingPathComponent("immutable-asset-id.mp4")
    try Data("Asset bytes must remain unchanged".utf8).write(to: source)
    return source
  }

  private func openCall(_ source: URL, name: String = "新名称.mp4") -> FlutterMethodCall {
    FlutterMethodCall(methodName: "openPreview", arguments: [
      "path": source.path, "displayName": name,
    ])
  }
}
