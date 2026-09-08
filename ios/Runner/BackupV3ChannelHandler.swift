#if os(iOS)
import Flutter
#else
import FlutterMacOS
#endif
import Foundation
import CloudKit

/// Thin Flutter shell, shared by both Apple targets. File I/O and CloudKit waits
/// run on one worker. Cancellation reaches tokens immediately from the UI queue.
final class BackupV3ChannelHandler: NSObject, FlutterStreamHandler {
  static let shared = BackupV3ChannelHandler()
  private let queue = DispatchQueue(label: "com.xuwudi.ochome.backup-v3", qos: .utility)
  private let transport = BackupV3Transport()
  private var tokens: [String: BackupV3Cancellation] = [:] // main queue only
  private var sink: FlutterEventSink?
  private var observers: [NSObjectProtocol] = []
  private var methodChannel: FlutterMethodChannel?
  private var eventChannel: FlutterEventChannel?

  func register(with messenger: FlutterBinaryMessenger) {
    methodChannel = FlutterMethodChannel(name: "com.xuwudi.ochome/backup_v3", binaryMessenger: messenger)
    eventChannel = FlutterEventChannel(name: "com.xuwudi.ochome/backup_v3/events", binaryMessenger: messenger)
    eventChannel?.setStreamHandler(self)
    methodChannel?.setMethodCallHandler { [weak self] call, reply in self?.handle(call, reply: reply) }
    transport.emit = { [weak self] event in DispatchQueue.main.async { self?.sink?(event) } }
    if observers.isEmpty {
      for name in [Notification.Name.CKAccountChanged, NSNotification.Name.NSUbiquityIdentityDidChange] {
        observers.append(NotificationCenter.default.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
          guard let self = self else { return }
          let operations = Array(self.tokens.keys)
          for token in self.tokens.values { token.cancel() }
          self.queue.async { self.transport.accountChanged(operations: operations) }
        })
      }
    }
  }
  private func handle(_ call: FlutterMethodCall, reply: @escaping FlutterResult) {
    let args = call.arguments as? [String: Any] ?? [:]
    let operation = args["operationId"] as? String ?? "metadata-\(UUID().uuidString)"
    if call.method == "cancel" {
      guard let id = args["operationId"] as? String else {
        reply(FlutterError(code: "invalid_arguments", message: "缺少操作标识", details: nil)); return
      }
      tokens[id]?.cancel()
      queue.async {
        // Every writer queued before cancellation has exited here. The token
        // remains cancelled so a late callback cannot start another write.
        DispatchQueue.main.async { reply(nil) }
      }
      return
    }
    if call.method == "abandonUpload", let abandoned = args["abandonedOperationId"] as? String {
      // Also enforce local draining when resuming a pending abandon after a
      // lifecycle interruption. Cleanup itself receives a different token.
      if let old = tokens[abandoned] { old.cancel() }
      else { let fence = BackupV3Cancellation(); fence.cancel(); tokens[abandoned] = fence }
    }
    let token: BackupV3Cancellation
    if call.method == "release" {
      // Cancellation has drained previous work before Dart releases its lease.
      // Permit this metadata-only cleanup without reviving the writer token.
      token = BackupV3Cancellation()
    } else if let existing = tokens[operation] { token = existing }
    else { token = BackupV3Cancellation(); tokens[operation] = token }
    queue.async {
      do {
        let value = try self.transport.perform(call.method, arguments: args, token: token)
        DispatchQueue.main.async {
          if args["operationId"] == nil { self.tokens.removeValue(forKey: operation) }
          reply(value)
        }
      } catch {
        let problem = BackupV3Transport.error(error)
        DispatchQueue.main.async {
          if args["operationId"] == nil { self.tokens.removeValue(forKey: operation) }
          reply(FlutterError(code: problem.code, message: problem.message, details: nil))
        }
      }
    }
  }
  func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
    sink = events; return nil
  }
  func onCancel(withArguments arguments: Any?) -> FlutterError? { sink = nil; return nil }
}
