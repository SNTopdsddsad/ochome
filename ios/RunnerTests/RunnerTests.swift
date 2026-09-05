import Flutter
import UIKit
import XCTest
@testable import Runner

class RunnerTests: XCTestCase {
  private let fm = FileManager.default
  private var root: URL!
  private var job: URL!

  override func setUpWithError() throws {
    root = fm.temporaryDirectory.appendingPathComponent("role-card-tests-\(UUID().uuidString)")
    job = root.appendingPathComponent("job")
    try fm.createDirectory(at: job, withIntermediateDirectories: true)
  }

  override func tearDownWithError() throws {
    try fm.removeItem(at: root)
  }

  func testValidJobPreservesPageOrderAndSourceFiles() throws {
    let first = try makePNG("first.png")
    let second = try makePNG("second.png")
    let urls = try RoleCardExportFiles.validate(
      paths: [second.path, first.path], allowedRoots: [root]
    )
    XCTAssertEqual(urls.map(\.lastPathComponent), ["second.png", "first.png"])
    XCTAssertTrue(fm.fileExists(atPath: first.path))
    XCTAssertTrue(fm.fileExists(atPath: second.path))
  }

  func testRejectsEmptyMissingAndNonPNGInputs() throws {
    XCTAssertThrowsError(try RoleCardExportFiles.validate(paths: [], allowedRoots: [root]))
    XCTAssertThrowsError(try RoleCardExportFiles.validate(
      paths: [job.appendingPathComponent("missing.png").path], allowedRoots: [root]
    ))
    let corrupt = job.appendingPathComponent("corrupt.png")
    try Data("not a valid PNG image".utf8).write(to: corrupt)
    XCTAssertThrowsError(try RoleCardExportFiles.validate(
      paths: [corrupt.path], allowedRoots: [root]
    ))
    let renamed = try makePNG("image.jpg")
    XCTAssertThrowsError(try RoleCardExportFiles.validate(
      paths: [renamed.path], allowedRoots: [root]
    ))
  }

  func testRejectsDuplicatesAndMixedJobs() throws {
    let first = try makePNG("first.png")
    XCTAssertThrowsError(try RoleCardExportFiles.validate(
      paths: [first.path, first.path], allowedRoots: [root]
    ))
    let otherJob = root.appendingPathComponent("other-job")
    try fm.createDirectory(at: otherJob, withIntermediateDirectories: false)
    let second = otherJob.appendingPathComponent("second.png")
    try fm.copyItem(at: first, to: second)
    XCTAssertThrowsError(try RoleCardExportFiles.validate(
      paths: [first.path, second.path], allowedRoots: [root]
    ))
  }

  func testRejectsOutsideRootAndSymlinkEscape() throws {
    let outside = root.appendingPathComponent("outside.png")
    try fm.copyItem(at: makePNG("first.png"), to: outside)
    XCTAssertThrowsError(try RoleCardExportFiles.validate(
      paths: [outside.path], allowedRoots: [root]
    ))
    let link = job.appendingPathComponent("linked.png")
    try fm.createSymbolicLink(at: link, withDestinationURL: outside)
    XCTAssertThrowsError(try RoleCardExportFiles.validate(
      paths: [link.path], allowedRoots: [root]
    ))
  }

  func testRejectsMalformedChannelArguments() {
    XCTAssertThrowsError(try RoleCardExportFiles.validatedURLs(arguments: nil))
    XCTAssertThrowsError(try RoleCardExportFiles.validatedURLs(arguments: ["paths": [1, 2]]))
    XCTAssertThrowsError(try RoleCardExportFiles.validatedURLs(arguments: ["paths": []]))
  }

  private func makePNG(_ name: String) throws -> URL {
    let url = job.appendingPathComponent(name)
    let data = try XCTUnwrap(Data(base64Encoded:
      "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+aWoQAAAAASUVORK5CYII="
    ))
    try data.write(to: url)
    return url
  }
}
