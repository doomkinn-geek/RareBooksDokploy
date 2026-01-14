import Flutter
import UIKit
import AVFoundation
import Firebase
import FirebaseMessaging
import UserNotifications

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // Configure AVAudioSession for background audio
    let audioSession = AVAudioSession.sharedInstance()
    do {
      try audioSession.setCategory(.playback, mode: .spokenAudio, options: [.allowBluetooth, .defaultToSpeaker])
      try audioSession.setActive(true)
    } catch {
      print("Failed to configure AVAudioSession: \(error)")
    }
    
    // Initialize Firebase
    print("🔥 Initializing Firebase...")
    FirebaseApp.configure()
    print("✅ Firebase initialized successfully")
    
    // Setup push notifications
    UNUserNotificationCenter.current().delegate = self
    print("✅ UNUserNotificationCenter delegate set")
    
    // Request notification permissions
    let authOptions: UNAuthorizationOptions = [.alert, .badge, .sound]
    print("📱 Requesting notification permissions...")
    UNUserNotificationCenter.current().requestAuthorization(
      options: authOptions,
      completionHandler: { granted, error in
        if granted {
          print("✅ Push notification permission GRANTED")
        } else if let error = error {
          print("❌ Push notification permission ERROR: \(error)")
        } else {
          print("❌ Push notification permission DENIED by user")
        }
      }
    )
    
    // Register for remote notifications
    print("📱 Registering for remote notifications...")
    application.registerForRemoteNotifications()
    
    // Set Firebase Messaging delegate
    Messaging.messaging().delegate = self
    print("✅ Firebase Messaging delegate set")
    
    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
  
  // Handle device token registration
  override func application(
    _ application: UIApplication,
    didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
  ) {
    // Convert token to string for logging
    let tokenParts = deviceToken.map { data in String(format: "%02.2hhx", data) }
    let token = tokenParts.joined()
    print("✅ APNs token received: \(token)")
    
    // Pass device token to Firebase
    Messaging.messaging().apnsToken = deviceToken
    print("✅ APNs token passed to Firebase Messaging")
    
    // Also pass to Flutter plugins
    super.application(application, didRegisterForRemoteNotificationsWithDeviceToken: deviceToken)
  }
  
  // Handle registration failure
  override func application(
    _ application: UIApplication,
    didFailToRegisterForRemoteNotificationsWithError error: Error
  ) {
    print("❌ Failed to register for remote notifications: \(error)")
    print("⚠️  Possible reasons:")
    print("   - Entitlements not configured")
    print("   - Push Notifications capability not enabled")
    print("   - Running on simulator (APNs doesn't work on simulator)")
    print("   - Network issues")
    super.application(application, didFailToRegisterForRemoteNotificationsWithError: error)
  }
  
  // Handle notification received while app is in foreground
  override func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    willPresent notification: UNNotification,
    withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
  ) {
    let userInfo = notification.request.content.userInfo
    print("Foreground notification received: \(userInfo)")
    
    // Show notification even when app is in foreground
    if #available(iOS 14.0, *) {
      completionHandler([.banner, .sound, .badge])
    } else {
      completionHandler([.alert, .sound, .badge])
    }
  }
  
  // Handle notification tap
  override func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    didReceive response: UNNotificationResponse,
    withCompletionHandler completionHandler: @escaping () -> Void
  ) {
    let userInfo = response.notification.request.content.userInfo
    print("Notification tapped: \(userInfo)")
    
    // Let Flutter handle the navigation
    super.userNotificationCenter(center, didReceive: response, withCompletionHandler: completionHandler)
  }
  
  // Handle background/silent notifications
  override func application(
    _ application: UIApplication,
    didReceiveRemoteNotification userInfo: [AnyHashable: Any],
    fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void
  ) {
    print("📥 Remote notification received (background/silent)")
    print("   State: \(application.applicationState.rawValue)")
    print("   UserInfo: \(userInfo)")
    
    // Pass to Firebase Messaging
    Messaging.messaging().appDidReceiveMessage(userInfo)
    
    // Let Flutter plugins handle it
    super.application(application, didReceiveRemoteNotification: userInfo, fetchCompletionHandler: { result in
      print("✅ Background notification processed: \(result.rawValue)")
      completionHandler(result)
    })
  }
}

// MARK: - Firebase Messaging Delegate
extension AppDelegate: MessagingDelegate {
  func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
    if let token = fcmToken {
      print("✅ FCM registration token received: \(token)")
      print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
      print("🎉 PUSH NOTIFICATIONS ARE READY!")
      print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
    } else {
      print("❌ FCM token is nil!")
      print("⚠️  Check Firebase Console APNs key configuration")
    }
    
    // Send token to Flutter side via notification
    let dataDict: [String: String] = ["token": fcmToken ?? ""]
    NotificationCenter.default.post(
      name: Notification.Name("FCMToken"),
      object: nil,
      userInfo: dataDict
    )
  }
}
