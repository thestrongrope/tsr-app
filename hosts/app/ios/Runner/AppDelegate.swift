import Flutter
import UIKit
import FirebaseCore
import FirebaseMessaging

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // Initialize Firebase
    // Note: We're using FirebaseAppDelegateProxyEnabled = false in Info.plist
    // This gives us more control over the Firebase initialization
    FirebaseApp.configure()
    
    // Register plugins
    GeneratedPluginRegistrant.register(with: self)
    
    // Register for remote notifications
    if #available(iOS 10.0, *) {
      UNUserNotificationCenter.current().delegate = self
    }
    
    // Set FCM messaging delegate
    Messaging.messaging().delegate = self
    
    // Request notification permissions will be handled by Flutter plugin
    // But we register for remote notifications here
    application.registerForRemoteNotifications()
    
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
  
  // Handle registration for remote notifications
  override func application(_ application: UIApplication,
                           didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
    // Pass device token to FCM
    Messaging.messaging().apnsToken = deviceToken
    #if DEBUG
    print("📱 APNs token registered with FCM")
    #endif
  }
  
  // Handle failure to register for remote notifications
  override func application(_ application: UIApplication,
                           didFailToRegisterForRemoteNotificationsWithError error: Error) {
    #if DEBUG
    print("❌ Failed to register for remote notifications: \(error.localizedDescription)")
    #endif
  }
  
  // Handle URL opening for Google Sign-In and other OAuth flows
  override func application(
    _ app: UIApplication,
    open url: URL,
    options: [UIApplication.OpenURLOptionsKey : Any] = [:]
  ) -> Bool {
    return super.application(app, open: url, options: options)
  }
}

// MARK: - Firebase Messaging Delegate
extension AppDelegate: MessagingDelegate {
  // Handle FCM token refresh
  func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
    #if DEBUG
    print("🔄 FCM token refreshed: \(fcmToken ?? "nil")")
    #endif
    
    // Send token to Flutter side if needed
    let tokenDict = ["token": fcmToken ?? ""]
    NotificationCenter.default.post(
      name: Notification.Name("FCMToken"),
      object: nil,
      userInfo: tokenDict
    )
  }
}

// MARK: - User Notification Center Delegate (iOS 10+)
@available(iOS 10, *)
extension AppDelegate {
  // Handle notification when app is in foreground
  override func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    willPresent notification: UNNotification,
    withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
  ) {
    #if DEBUG
    print("📨 Notification received in foreground")
    #endif
    
    // Forward to FlutterAppDelegate so the registered plugins (notably
    // firebase_messaging) see the message and onMessage fires. Its
    // presentation options are discarded via the throwaway handler because
    // this app always shows foreground notifications; the real handler is
    // called below exactly once.
    super.userNotificationCenter(center, willPresent: notification) { _ in }
    
    // Show notification even when app is in foreground
    if #available(iOS 14.0, *) {
      completionHandler([[.banner, .sound, .badge]])
    } else {
      completionHandler([[.alert, .sound, .badge]])
    }
  }
  
  // Handle notification tap
  override func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    didReceive response: UNNotificationResponse,
    withCompletionHandler completionHandler: @escaping () -> Void
  ) {
    #if DEBUG
    print("👆 Notification tapped")
    #endif
    
    let userInfo = response.notification.request.content.userInfo
    #if DEBUG
    print("📩 User info: \(userInfo)")
    #endif
    
    // Forward to FlutterAppDelegate so the registered plugins (notably
    // firebase_messaging) see the tap and onMessageOpenedApp fires. super
    // invokes completionHandler, so it must not be called here as well.
    super.userNotificationCenter(
      center,
      didReceive: response,
      withCompletionHandler: completionHandler
    )
  }
}
