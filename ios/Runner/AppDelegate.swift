import Flutter
import UIKit

/// The channel between Dart and [CuePlayer], matching MainActivity on Android
/// method for method.
///
/// Nothing here decides anything. Dart sends the whole cue list and the player
/// plays it, which is why a workout carries on when the UI is gone.
@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private var channel: FlutterMethodChannel?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)

    let channel = FlutterMethodChannel(
      name: "com.anvuman.talking_stopwatch/cues",
      binaryMessenger: engineBridge.applicationRegistrar.messenger()
    )
    self.channel = channel

    let player = CuePlayer.shared
    player.onFired = { key in channel.invokeMethod("fired", arguments: key) }
    player.onStopped = { channel.invokeMethod("stopped", arguments: nil) }
    player.onPaused = { paused in channel.invokeMethod("paused", arguments: paused) }

    channel.setMethodCallHandler { call, result in
      Self.handle(call, result: result, player: player)
    }
  }

  private static func handle(
    _ call: FlutterMethodCall,
    result: @escaping FlutterResult,
    player: CuePlayer
  ) {
    let arguments = call.arguments as? [String: Any] ?? [:]

    switch call.method {
    case "available":
      result(player.isAvailable)

    case "warm":
      let phrases = arguments["phrases"] as? [String: String] ?? [:]
      player.warm(phrases) { failed in result(failed) }

    case "schedule":
      let at = arguments["at"] as? [Int] ?? []
      let keys = arguments["keys"] as? [String] ?? []
      guard at.count == keys.count else {
        result(FlutterError(code: "bad_args", message: "at and keys must match", details: nil))
        return
      }
      player.schedule(
        cues: zip(at, keys).map { (at: $0, key: $1) },
        leadMs: arguments["leadMs"] as? Int ?? 0,
        title: arguments["title"] as? String ?? "Workout",
        detail: arguments["text"] as? String ?? "",
        countUp: arguments["countUp"] as? Bool ?? false
      )
      result(0)

    case "cancel":
      player.cancel()
      result(nil)

    case "pause":
      player.pause()
      result(nil)

    case "resume":
      player.resume()
      result(nil)

    case "isPaused":
      result(player.isPaused())

    case "elapsed":
      result(player.elapsedMs())

    case "describe":
      player.describe(
        title: arguments["title"] as? String ?? "Workout",
        detail: arguments["text"] as? String ?? ""
      )
      result(nil)

    case "keepAwake":
      UIApplication.shared.isIdleTimerDisabled = arguments["on"] as? Bool ?? false
      result(nil)

    // Android only: there is no notification here to ask permission for, to
    // check, or to send anyone to a settings screen for. The lock-screen
    // controls come with the audio session. `canNotify` answering nil is what
    // tells Dart the question does not apply here, so the settings screen
    // never offers to fix a permission that does not exist.
    case "askToNotify", "canNotify", "openNotifySettings":
      result(nil)

    default:
      result(FlutterMethodNotImplemented)
    }
  }
}
