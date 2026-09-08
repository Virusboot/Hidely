import Flutter
import UIKit
import GoogleMaps

@UIApplicationMain
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    let mapsApiKey = (Bundle.main.object(forInfoDictionaryKey: "GOOGLE_MAPS_API_KEY") as? String)?
      .trimmingCharacters(in: .whitespacesAndNewlines)

    if let key = mapsApiKey, !key.isEmpty, !key.hasPrefix("$(") {
      GMSServices.provideAPIKey(key)
    } else if let envKey = ProcessInfo.processInfo.environment["GOOGLE_MAPS_API_KEY"]?.trimmingCharacters(in: .whitespacesAndNewlines), !envKey.isEmpty {
      GMSServices.provideAPIKey(envKey)
    }

    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}

