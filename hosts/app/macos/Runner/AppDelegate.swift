import Cocoa
import FlutterMacOS
import FirebaseCore

@main
class AppDelegate: FlutterAppDelegate {
  override func applicationDidFinishLaunching(_ notification: Notification) {
    // Initialize Firebase
    FirebaseApp.configure()
    print("✅ Firebase configured for macOS")
  }
  
  override func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
    return true
  }

  override func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
    return true
  }
  
  // Handle URL opening for Google Sign-In and other OAuth flows
  override func application(_ application: NSApplication, open urls: [URL]) {
    for url in urls {
      print("🔗 Opening URL: \(url)")
    }
  }
}
