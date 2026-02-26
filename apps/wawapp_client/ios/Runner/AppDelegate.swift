import Flutter
import UIKit
import Firebase
import GoogleMaps

@main
@objc class AppDelegate: FlutterAppDelegate {
    override func application(
          _ application: UIApplication,
          didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
          FirebaseApp.configure()
                    GMSServices.provideAPIKey("AIzaSyCHEUg-xyto3FAwRhP0BM5zR6E4JUP_I-A")
          GeneratedPluginRegistrant.register(with: self)
          application.registerForRemoteNotifications()
          return super.application(application, didFinishLaunchingWithOptions: launchOptions)
    }

    // MARK: - APNs Token Registration

    override func application(
          _ application: UIApplication,
          didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
          Auth.auth().setAPNSToken(deviceToken, type: .unknown)
    }

    override func application(
          _ application: UIApplication,
          didFailToRegisterForRemoteNotificationsWithError error: Error
    ) {
          print("Failed to register for remote notifications: \(error.localizedDescription)")
    }

    // MARK: - Silent Push for Firebase Phone Auth

    override func application(
          _ application: UIApplication,
          didReceiveRemoteNotification userInfo: [AnyHashable: Any],
          fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void
    ) {
          if Auth.auth().canHandleNotification(userInfo) {
                  completionHandler(.noData)
                  return
          }
          completionHandler(.newData)
    }
}
