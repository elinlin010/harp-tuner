import Flutter
import UIKit
import AVFoundation

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

    // Register a mic-permission channel using AVAudioSession, which works on iOS 26
    // (AVCaptureDevice.requestAccessForMediaType(.audio) is broken on iOS 26 simulator)
    guard let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "MicPermission") else {
      return
    }
    let channel = FlutterMethodChannel(
      name: "com.harptuner/mic_permission",
      binaryMessenger: registrar.messenger()
    )
    channel.setMethodCallHandler { call, result in
      switch call.method {
      case "checkPermission":
        result(AVAudioSession.sharedInstance().recordPermission == .granted)
      case "requestPermission":
        AVAudioSession.sharedInstance().requestRecordPermission { granted in
          DispatchQueue.main.async { result(granted) }
        }
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }
}
