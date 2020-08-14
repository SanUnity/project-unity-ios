//
//  BlueTraceLocalNotifications.swift
//  OpenTrace

import Foundation
import UIKit

class BlueTraceLocalNotifications: NSObject {

    static let shared = BlueTraceLocalNotifications()

    func initialConfiguration() {
        UNUserNotificationCenter.current().delegate = self
        setupBluetoothPNStatusCallback()
    }

    // Future update - we have a variable here that stores the permissions state at any point. This variable can be updated everytime app launches / comes into foreground by calling the checkAuthorization (if onboarding has been finished)
    func checkAuthorization(completion: @escaping (_ granted: Bool) -> Void) {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
            print("PNS permission granted: \(granted)")
            DispatchQueue.main.async {
                completion(granted)
            }
        }
    }

    func setupBluetoothPNStatusCallback() {

        let btStatusMagicNumber = Int.random(in: 0 ... PushNotificationConstants.btStatusPushNotifContents.count - 1)

        BluetraceManager.shared.bluetoothDidUpdateStateCallback = { [unowned self] state in
            if UserDefaults.standard.bool(forKey: "completedBluetoothOnboarding") && !BluetraceManager.shared.isBluetoothOn() {
                if !UserDefaults.standard.bool(forKey: "sentBluetoothStatusNotif") {
                    UserDefaults.standard.set(true, forKey: "sentBluetoothStatusNotif")
                    self.triggerIntervalLocalPushNotifications(pnContent: PushNotificationConstants.btStatusPushNotifContents[btStatusMagicNumber], identifier: "bluetoothStatusNotifId")
                }
            }
        }
    }

    func triggerCalendarLocalPushNotifications(pnContent: [String: String], identifier: String) {
        let today = Date()
        let hour = Calendar.current.component(.hour, from: today)
        let weekday = Calendar.current.component(.weekday, from: today)
        let center = UNUserNotificationCenter.current()

        if (weekday > 1 && weekday < 6) || (weekday == 6 && hour < 9) || (weekday == 1 && hour > 9) {
            let content = UNMutableNotificationContent()
            content.title = pnContent["contentTitle"]!
            content.body = pnContent["contentBody"]!
            content.sound = .default
            content.userInfo = [
                "aps":  [
                    "alert":   [
                        "title":    pnContent["contentTitle"]!,
                        "body":     pnContent["contentBody"]!,
                    ],
                    "sound":        "default",
                    "type":         "reminder"
                ]
            ]

            var dateComponents = DateComponents()
            dateComponents.hour = 9

            let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)

            let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
            center.add(request)
        }
    }

    func triggerIntervalLocalPushNotifications(pnContent: [String: String], identifier: String) {

        let center = UNUserNotificationCenter.current()

        let content = UNMutableNotificationContent()
        content.title = pnContent["contentTitle"]!
        content.body = pnContent["contentBody"]!
        content.sound = .default

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)

        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
        center.add(request)
    }

    func removePendingNotificationRequests() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ["appBackgroundNotifId"])
    }
}

@available(iOS 10, *)
extension BlueTraceLocalNotifications: UNUserNotificationCenterDelegate {

    // When user receives the notification when app is in foreground
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification,
                                withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.alert, .badge, .sound])
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        if response.notification.request.identifier == "bluetoothStatusNotifId" && !BluetraceManager.shared.isBluetoothAuthorized() {
            UIApplication.shared.open(URL(string: UIApplication.openSettingsURLString)!)
        }
        completionHandler()
    }
}

struct PushNotificationConstants {
    // Bluetooth Status
    static let btStatusPushNotifContents = [
        [
            "contentTitle": String.Push.STATUS_TITLE,
            "contentBody": String.Push.PUSH_BODY
        ]
    ]

    // Daily Reminders
    static let dailyRemPushNotifContents = [
        [
            "contentTitle": String.Push.REMINDER_TITLE,
            "contentBody": String.Push.PUSH_BODY
        ]
        /*
        ,
        [
            "contentTitle": String.Push.ONBOARDING_TITLE_1,
            "contentBody": String.Push.ONBOARDING_BODY_1
        ],
        [
            "contentTitle": String.Push.ONBOARDING_TITLE_2,
            "contentBody": String.Push.ONBOARDING_BODY_2
        ],
        [
            "contentTitle": String.Push.ONBOARDING_TITLE_3,
            "contentBody": String.Push.ONBOARDING_BODY_3
        ],
        [
            "contentTitle": String.Push.ONBOARDING_TITLE_4,
            "contentBody": String.Push.ONBOARDING_BODY_4
        ]*/
    ]
}
