import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)

    RegisterGeneratedPlugins(registry: flutterViewController)
    BackupV3ChannelHandler.shared.register(with: flutterViewController.engine.binaryMessenger)
    VideoThumbnailHandler.shared.register(with: flutterViewController.engine.binaryMessenger)
    RoleCardExportHandler.shared.register(
      with: flutterViewController.engine.binaryMessenger, window: self
    )

    super.awakeFromNib()
  }
}
