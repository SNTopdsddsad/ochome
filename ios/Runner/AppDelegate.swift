import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    BackupV3ChannelHandler.shared.register(with: engineBridge.applicationRegistrar.messenger())
    RoleCardExportHandler.shared.register(with: engineBridge.applicationRegistrar.messenger())
    RoleAssetPreviewHandler.shared.register(with: engineBridge.applicationRegistrar.messenger())
    VideoThumbnailHandler.shared.register(with: engineBridge.applicationRegistrar.messenger())
  }
}
