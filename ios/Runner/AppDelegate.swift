import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // Let plugins register themselves via GeneratedPluginRegistrant
    GeneratedPluginRegistrant.register(with: self)

    // Register security plugin for jailbreak detection
    let controller = window?.rootViewController as! FlutterViewController
    SecurityPlugin.register(with: self.registrar(forPlugin: "SecurityPlugin")!)

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  // Handle deep links / callbacks (including Paymob return URLs)
  override func application(_ app: UIApplication, open url: URL, options: [UIApplication.OpenURLOptionsKey : Any] = [:]) -> Bool {
    // Pass the URL to the Flutter engine for further handling
    return super.application(app, open: url, options: options) || self.application(app, open: url, sourceApplication: options[UIApplication.OpenURLOptionsKey.sourceApplication] as? String, annotation: options[UIApplication.OpenURLOptionsKey.annotation])
  }
}