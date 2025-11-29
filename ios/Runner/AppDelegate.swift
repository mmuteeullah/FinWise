import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)

    // Set up method channel for SMS messages
    let controller = window?.rootViewController as! FlutterViewController
    let smsChannel = FlutterMethodChannel(
      name: "com.mmuteeullah.finwise/sms",
      binaryMessenger: controller.binaryMessenger
    )

    smsChannel.setMethodCallHandler { [weak self] (call, result) in
      switch call.method {
      case "getMessages":
        let messages = SharedStorageManager.shared.getAllMessages()
        let messagesArray = messages.map { message in
          return [
            "id": message.id,
            "text": message.text,
            "sender": message.sender,
            "receivedAt": message.receivedAt
          ]
        }
        result(messagesArray)

      case "clearMessages":
        SharedStorageManager.shared.clearMessages()
        result(nil)

      default:
        result(FlutterMethodNotImplemented)
      }
    }

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
