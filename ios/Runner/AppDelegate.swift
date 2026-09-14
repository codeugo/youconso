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

    // Expose au Dart l'identifiant réel de l'App Group (voir Shared/AppGroup.swift),
    // pour que home_widget écrive là où l'extension widget lit.
    let channel = FlutterMethodChannel(
      name: "fr.youconso.youconso/app_group",
      binaryMessenger: engineBridge.applicationRegistrar.messenger())
    channel.setMethodCallHandler { call, result in
      switch call.method {
      case "appGroupId":
        result(AppGroup.identifier)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }
}
