import UIKit
import Flutter
import GoogleMaps

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    // Google Maps must be configured before the plugin is registered.
    GMSServices.provideAPIKey("AIzaSyDsf5hnTY2mk82eR6b3-hB7YqAIX-KkBVg")
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
  }
}
