import Cocoa
import FlutterMacOS
import XCTest
@testable import ochome

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

  func testCopiesAllPagesInOrderWithoutMovingSources() throws {
    let first = try makePNG("first.png")
    let second = try makePNG("second.png")
    // The copy layer has already received validated pages. Distinct bytes make
    // this test detect reversed order independently of image validation.
    try Data("second page".utf8).write(to: second)
    let destination = try RoleCardExportFiles.copyJob(urls: [second, first], to: root)
    let files = try fm.contentsOfDirectory(atPath: destination.path).sorted()
    XCTAssertEqual(files, ["zaidang-card-001.png", "zaidang-card-002.png"])
    XCTAssertEqual(try Data(contentsOf: destination.appendingPathComponent(files[0])),
      try Data(contentsOf: second))
    XCTAssertTrue(fm.fileExists(atPath: first.path))
    XCTAssertTrue(fm.fileExists(atPath: second.path))
    XCTAssertFalse(try fm.contentsOfDirectory(atPath: root.path).contains { $0.hasSuffix(".partial") })
  }

  func testRepeatedSaveCreatesIndependentDirectories() throws {
    let first = try makePNG("first.png")
    let firstSave = try RoleCardExportFiles.copyJob(urls: [first], to: root)
    let secondSave = try RoleCardExportFiles.copyJob(urls: [first], to: root)
    XCTAssertNotEqual(firstSave, secondSave)
    XCTAssertTrue(fm.fileExists(atPath: firstSave.appendingPathComponent("zaidang-card-001.png").path))
    XCTAssertTrue(fm.fileExists(atPath: secondSave.appendingPathComponent("zaidang-card-001.png").path))
  }

  func testCopyFailureRemovesOnlyItsOwnStagingDirectory() throws {
    let first = try makePNG("first.png")
    let userFile = root.appendingPathComponent("keep.txt")
    let contents = Data("user file".utf8)
    try contents.write(to: userFile)
    let before = Set(try fm.contentsOfDirectory(atPath: root.path))
    XCTAssertThrowsError(try RoleCardExportFiles.copyJob(
      urls: [first, job.appendingPathComponent("missing.png")], to: root
    ))
    XCTAssertEqual(Set(try fm.contentsOfDirectory(atPath: root.path)), before)
    XCTAssertEqual(try Data(contentsOf: userFile), contents)
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
