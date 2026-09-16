import Flutter
import UIKit
import nitro_type_coverage

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate, FlutterSceneLifeCycleDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    // Native-initiated background job demo: `xcrun simctl openurl booted
    // "nitrobg://run?text=hello"` runs the Dart entry `bgPersist` in a headless
    // FlutterEngine (no Dart submitter); the app's card shows the persisted line.
    // UIScene apps deliver URL opens through the scene, not the app delegate,
    // so listen as a scene life-cycle delegate (covers cold and warm launches).
    engineBridge.pluginRegistry.registrar(forPlugin: "NitroBgUrl")?.addSceneDelegate(self)
  }

  func scene(_ scene: UIScene, willConnectTo session: UISceneSession,
             options connectionOptions: UIScene.ConnectionOptions?) -> Bool {
    // `true` = handled: otherwise Flutter relays the launch URL back to the
    // system, which re-enters via openURLContexts and runs the job twice.
    return runBgJobs(connectionOptions?.urlContexts ?? [])
  }

  func scene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) -> Bool {
    return runBgJobs(URLContexts)
  }

  private func runBgJobs(_ contexts: Set<UIOpenURLContext>) -> Bool {
    var handled = false
    for context in contexts where context.url.scheme == "nitrobg" {
      let query = URLComponents(url: context.url, resolvingAgainstBaseURL: false)?.queryItems ?? []
      let text = query.first { $0.name == "text" }?.value ?? "from-url"
      let entry = query.first { $0.name == "entry" }?.value ?? "bgPersist"
      NitroTypeCoverageBackground.run(entry: entry, text: text) { jobId, error in
        NSLog("NitroBgJob: %@ job %lld done: %@", entry, jobId, error ?? "ok")
      }
      handled = true
    }
    return handled
  }
}
