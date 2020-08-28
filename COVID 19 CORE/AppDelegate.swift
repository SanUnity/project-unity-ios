//
//  AppDelegate.swift
//  COVID 19 CORE
//
//  Created by Emilio Cubo Ruiz on 23/03/2020.
//  Copyright © 2020 COVID 19 CORE. All rights reserved.
//

import UIKit
import CoreData
import CoreBluetooth
import Firebase
import UserNotifications
// import Parse

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {
    
    // .entitlements
    // APS Environment:    development

    var window: UIWindow?
    var openUrl:URL?
    var pogoMM: PogoMotionManager? = nil
    var userChannel:String? = nil
    var trustKitCertificatePinning:TrustKitCertificatePinning? = nil

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {

        do {
            NotificationCenter.default.addObserver(self, selector: #selector(self.checkForReachability), name: NSNotification.Name.reachabilityChanged, object: nil)
            try NetworkManager.sharedInstance.reachability?.startNotifier()
        } catch {
            
        }

        if AppConfig.protected && UIDevice.current.isJailBroken { fatalError("Jailbreak detected!") }
        
        // MARK: Firebase
        FirebaseApp.configure()

        self.configureDatabaseManager()
        UIApplication.shared.isIdleTimerDisabled = true
            
        if let notificationPayload = launchOptions?[UIApplication.LaunchOptionsKey.remoteNotification] as? NSDictionary {
            UIApplication.shared.applicationIconBadgeNumber = max(UIApplication.shared.applicationIconBadgeNumber - 1, 0)
            // ParseManager.setBadge()
            self.notificaton(notificationPayload as! [AnyHashable: Any])
        }
        
        if String.Pinning.PUBLIC_KEY_HASHES.count > 0 {
            trustKitCertificatePinning = TrustKitCertificatePinning()
        }

        ContactTracingManager.sharedInstance.initialize(trustKitCertificatePinning: trustKitCertificatePinning)

        registerForPushNotifications()
        
        if String.General.CONTACT_TRACING_MODEL != .none, String.General.BUSINESS_DAYS_TRACING {
            self.checkForTracing()
            Timer.scheduledTimer(timeInterval: 60, target: self, selector: #selector(self.checkForTracing), userInfo: nil, repeats: true)
        }

        return true
    }
    
    @objc func checkForTracing() {
        Logger.DLog("Check for tracing")
        let today = Date()
        let hour = Calendar.current.component(.hour, from: today)
        let weekday = Calendar.current.component(.weekday, from: today)

        if AppSettings.userHasPassport && weekday > 1 && weekday < 7 {
            // Si hoy es L-V y userHasPassport es TRUE
            if hour >= 8 && hour < 22 && !AppSettings.autoActivation {
                // Si son más de las 8AM y autoActivation es FALSE
                AppSettings.autoActivation = true
                (self.window?.rootViewController as? ViewController)?.startBluetooth()
            } else if hour >= 22 && AppSettings.autoActivation {
                // Si son más de las 10PM y autoActivation es TRUE
                AppSettings.autoActivation = false
                AppSettings.dateTracingStoped = nil
                ContactTracingManager.sharedInstance.stopTracing()
            }
        } else {
            ContactTracingManager.sharedInstance.stopTracing()
        }
        
        if let webviewVC = self.window?.rootViewController as? ViewController {
            webviewVC.setBTStatus()
        }
        
    }
    
    func startAccelerometerUpdates() {
        if String.General.CONTACT_TRACING_MODEL == .centralised {
            self.pogoMM = PogoMotionManager(window: self.window)
        }
    }
    
    func stopAllMotion() {
        self.pogoMM?.stopAllMotion()
        self.pogoMM = nil
    }
    
    func application(_ application: UIApplication, shouldAllowExtensionPointIdentifier extensionPointIdentifier: UIApplication.ExtensionPointIdentifier) -> Bool {
        if extensionPointIdentifier == UIApplication.ExtensionPointIdentifier.keyboard {
            return false
        }
        return true
    }
    
    @objc func checkForReachability(notification: Notification) {
        if let webviewVC = self.window?.rootViewController as? ViewController, let reachability = NetworkManager.sharedInstance.reachability {
            switch reachability.connection {
            case .unavailable:
                webviewVC.noInternetConnection()
            default:
                NotificationCenter.default.post(name: NSNotification.Name.handleReload, object:self.openUrl)
            }
        }
    }

    
    // MARK: - Core Data stack
    lazy var persistentContainer: NSPersistentContainer = {
        /*
         The persistent container for the application. This implementation
         creates and returns a container, having loaded the store for the
         application to it. This property is optional since there are legitimate
         error conditions that could cause the creation of the store to fail.
         */
        let container = NSPersistentContainer(name: "tracer")
        container.loadPersistentStores(completionHandler: { (_, error) in
            if let error = error as NSError? {
                // Replace this implementation with code to handle the error appropriately.

                /*
                 Typical reasons for an error here include:
                 * The parent directory does not exist, cannot be created, or disallows writing.
                 * The persistent store is not accessible, due to permissions or data protection when the device is locked.
                 * The device is out of space.
                 * The store could not be migrated to the current model version.
                 Check the error message to determine what the actual problem was.
                 */
                fatalError("Unresolved error \(error), \(error.userInfo)")
            }
        })
        return container
    }()

    func configureDatabaseManager() {
        DatabaseManager.shared().persistentContainer = self.persistentContainer
    }

    func applicationDidBecomeActive(_ application: UIApplication) {
        Logger.DLog("applicationDidBecomeActive")

        if (self.window?.rootViewController as? ViewController)?.isLoadWeb ?? false {
            (self.window?.rootViewController as? ViewController)?.webview.isHidden = false
            (self.window?.rootViewController as? ViewController)?.splashImage.isHidden = true
        }

        if String.General.CONTACT_TRACING_MODEL != .none, AppSettings.bluetoothRequested {
            pogoMM?.startAccelerometerUpdates()
            ContactTracingManager.sharedInstance.sync()
        }
        
        let nextGPS = Calendar.current.date(byAdding: .day, value: 1, to: AppSettings.lastGPSData)!
        if AppSettings.gpsRequested && nextGPS > Date() {
            (self.window?.rootViewController as? ViewController)?.sendLocation()
        }

    }

    func applicationWillResignActive(_ application: UIApplication) {
        Logger.DLog("applicationWillResignActive")
        (self.window?.rootViewController as? ViewController)?.webview.isHidden = true
        (self.window?.rootViewController as? ViewController)?.splashImage.isHidden = false
    }

    func applicationDidEnterBackground(_ application: UIApplication) {
        Logger.DLog("applicationDidEnterBackground")
        UIApplication.shared.applicationIconBadgeNumber = 0

        if String.General.CONTACT_TRACING_MODEL != .none, AppSettings.bluetoothRequested {
            pogoMM?.stopAllMotion()
            if String.General.CONTACT_TRACING_MODEL == .centralised || String.General.CONTACT_TRACING_MODEL == .decentralised {
                let magicNumber = Int.random(in: 0 ... PushNotificationConstants.dailyRemPushNotifContents.count - 1)
                BlueTraceLocalNotifications.shared.triggerCalendarLocalPushNotifications(pnContent: PushNotificationConstants.dailyRemPushNotifContents[magicNumber], identifier: "appBackgroundNotifId")
            }
        }

        // ParseManager.setBadge()
    }
    
    func applicationWillEnterForeground(_ application: UIApplication) {
        Logger.DLog("applicationWillEnterForeground")
        if String.General.CONTACT_TRACING_MODEL != .none, AppSettings.bluetoothRequested {
            pogoMM?.stopAllMotion()
            BlueTraceLocalNotifications.shared.removePendingNotificationRequests()
            if String.General.CONTACT_TRACING_MODEL == .centralised {
                BluetraceUtils.removeData21DaysOld()
            }
        }
    }

    func applicationWillTerminate(_ application: UIApplication) {
        Logger.DLog("applicationWillTerminate")
        if String.General.CONTACT_TRACING_MODEL != .none, AppSettings.bluetoothRequested {
            pogoMM?.stopAllMotion()
        }
    }
    
    func application(_ app: UIApplication, open url: URL, options: [UIApplication.OpenURLOptionsKey : Any] = [:]) -> Bool {
        
        let url = url.standardized
        Logger.DLog(url.absoluteString)
        
        if url.absoluteString.contains(String.General.URL_SCHEME),
            let url2Open = URL(string: url.absoluteString.replacingOccurrences(of: "\(String.General.URL_SCHEME)://", with: String.Webapp.URL)) {
                self.openUrl = url2Open
                NotificationCenter.default.post(name: NSNotification.Name.handleOpenUrl, object:self.openUrl!)
        }
        
        return true

    }
    
    // MARK: - Push Notifications
    func registerForPushNotifications() {
        UNUserNotificationCenter.current().delegate = self
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) {
            (granted, error) in
            print("Permission granted: \(granted)")
            guard granted else { return }
            self.getNotificationSettings()
        }
    }
    
    func getNotificationSettings() {
        UNUserNotificationCenter.current().getNotificationSettings { (settings) in
            guard settings.authorizationStatus == .authorized else { return }
            DispatchQueue.main.async(execute: { () -> Void in
                UIApplication.shared.registerForRemoteNotifications()
            })
        }
    }

    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {

        let deviceTokenString = deviceToken.hexString
        AppSettings.appDeviceToken = deviceTokenString

        if AppSettings.initDeviceToken == nil && !AppSettings.isUserLogged {
            
            let urlString = "\(String.Api.BASE_URL)\(String.Api.POST_INIT_DEVICE_TOKEN)"
            if let url = URL(string: urlString) {
                
                var request = URLRequest(url: url)
                request.httpMethod = "POST"
                var dictFromJSON:[String:Any] = [
                    "devicetoken"   :   deviceTokenString,
                    "devicetype"    :   "ios"
                ]
                
                dictFromJSON["uuid"] = UUID().uuidString
                if let ifv = UIDevice.current.identifierForVendor?.uuidString {
                    dictFromJSON["ifv"] = ifv
                }
                
                if let idfa = String.identifierForAdvertising() {
                    dictFromJSON["idfa"] = idfa
                }
                
                
                let json = try! JSONSerialization.data(withJSONObject:dictFromJSON, options: [])
                request.httpBody = json
                request.addValue("application/json", forHTTPHeaderField: "content-type")
                request.addValue("ios", forHTTPHeaderField: "API-apptype")

                if let session = trustKitCertificatePinning?.session {
                    let task = session.dataTask(with: request) { data, response, error in
                        DispatchQueue.main.async(execute: { () -> Void in
                            
                            if let error = error {
                                Logger.DLog(error.localizedDescription)
                            } else if let httpResponse = response as? HTTPURLResponse {
                                switch httpResponse.statusCode {
                                case 200:
                                    Logger.DLog("Device token logged")
                                    AppSettings.initDeviceToken = deviceTokenString
                                default:
                                    Logger.DLog("Error with status code: \(httpResponse.statusCode)")
                                    print("device token: \(deviceTokenString)")

                                }
                            } else {
                                Logger.DLog("Error: no response")
                            }
                        })
                    }
                    task.resume()
                }
            }
            
        } else if AppSettings.deviceToken == nil, let token = AppSettings.userToken {
            self.setDeviceToken(token, deviceTokenString: deviceTokenString)
        } else if AppSettings.isUserLogged {
            (self.window?.rootViewController as? ViewController)?.startBluetooth()
        }
        
    }
  
    func setDeviceToken(_ token: String, deviceTokenString: String) {
        let urlString = "\(String.Api.BASE_URL)\(String.Api.POST_DEVICE_TOKEN)"
        if let url = URL(string: urlString) {
            
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            var dictFromJSON:[String:Any] = [
                "devicetoken"   :   deviceTokenString,
                "devicetype"    :   "ios"
            ]
            
            dictFromJSON["uuid"] = UUID().uuidString
            if let ifv = UIDevice.current.identifierForVendor?.uuidString {
                dictFromJSON["ifv"] = ifv
            }
            
            if let idfa = String.identifierForAdvertising() {
                dictFromJSON["idfa"] = idfa
            }
            
            
            let json = try! JSONSerialization.data(withJSONObject:dictFromJSON, options: [])
            request.httpBody = json
            request.addValue("application/json", forHTTPHeaderField: "content-type")
            request.addValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            request.addValue("ios", forHTTPHeaderField: "API-apptype")

            if let session = trustKitCertificatePinning?.session {
                let task = session.dataTask(with: request) { data, response, error in
                    DispatchQueue.main.async(execute: { () -> Void in
                        
                        (self.window?.rootViewController as? ViewController)?.startBluetooth()

                        if let error = error {
                            Logger.DLog(error.localizedDescription)
                        } else if let httpResponse = response as? HTTPURLResponse {
                            switch httpResponse.statusCode {
                            case 200:
                                Logger.DLog("Device token logged")
                                AppSettings.initDeviceToken = deviceTokenString
                                AppSettings.deviceToken = deviceTokenString
                            default:
                                Logger.DLog("Error with status code: \(httpResponse.statusCode)")
                                print("device token: \(deviceTokenString)")
                                print("user token: \(token)")

                            }
                        } else {
                            Logger.DLog("Error: no response")
                        }
                    })
                }
                task.resume()
            }
        }
    }

    func application(_ application: UIApplication, didReceiveRemoteNotification userInfo: [AnyHashable : Any], fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
        if (application.applicationState == .active) {
            self.alertMessage(userInfo)
        } else {
            completionHandler(.newData)
        }
    }

    func application(_ application: UIApplication, didReceiveRemoteNotification userInfo: [AnyHashable: Any]) {
        UIApplication.shared.applicationIconBadgeNumber = max(UIApplication.shared.applicationIconBadgeNumber - 1, 0)
        // ParseManager.setBadge()

        if (application.applicationState == UIApplication.State.inactive || application.applicationState == UIApplication.State.background) {
            self.notificaton(userInfo)
        } else if let type = userInfo["type"] as? String, type == "url", let urlString = userInfo["element"] as? String {
            let isNotification = ( self.openUrl != nil && self.openUrl!.absoluteString.contains("notification"))
            if !isNotification, self.openUrl?.absoluteString != urlString, let _ = URL(string: urlString) {
                self.alertMessage(userInfo)
            }
        } else if let aps = userInfo["aps"] as? [String:Any], let type = aps["type"] as? String, type == "url", let urlString = aps["element"] as? String {
            let isNotification = ( self.openUrl != nil && self.openUrl!.absoluteString.contains("notification"))
            if !isNotification, self.openUrl?.absoluteString != urlString, let _ = URL(string: urlString) {
                self.alertMessage(userInfo)
            }
        } else if userInfo["type"] as? String == "reminder" || (userInfo["aps"] as? [String:Any])?["type"] as? String == "reminder" {
            self.alertMessage(userInfo)
        } else if let infoapp = userInfo["infoapp"] as? [String:String] ?? (userInfo["aps"] as? [String:Any])?["infoapp"] as? [String:String],
            let type = infoapp["type"], type == "url", let urlString = infoapp["element"] {
            let isNotification = ( self.openUrl != nil && self.openUrl!.absoluteString.contains("notification"))
            if !isNotification, self.openUrl?.absoluteString != urlString, let _ = URL(string: urlString) {
                self.alertMessage(userInfo)
            }
        }
    }
    
    func alertMessage(_ userInfo: [AnyHashable: Any]) {
        print(userInfo)

        var titleMessage:String = NSLocalizedString(String.General.APP_NAME, comment: "")
        // var titleMessage:String? = Bundle.main.infoDictionary!["CFBundleName"] as? String
        var message:String? = (userInfo["aps"] as? NSDictionary)?["alert"] as? String

        if message == nil {
            if let title = ((userInfo["aps"] as? NSDictionary)?["alert"] as? NSDictionary)?["title"] as? String {
                titleMessage = title
            }
            if let mess = ((userInfo["aps"] as? NSDictionary)?["alert"] as? NSDictionary)?["body"] as? String {
                message = mess
            }
        }

        let alertController = UIAlertController(title: titleMessage, message: message, preferredStyle: .actionSheet)

        let openAction:UIAlertAction
        if (userInfo["aps"] as? NSDictionary)?["type"] as? String == "url" || (userInfo["aps"] as? NSDictionary)?["type"] as? String == "reminder" {
            openAction = UIAlertAction(title: String.General.SHOW, style: .default, handler: { (action) in
                self.notificaton(userInfo)
            })
        } else {
            openAction = UIAlertAction(title: String.General.ACCEPT, style: .default, handler: { (action) in
                self.notificaton(userInfo)
            })
        }

        let cancelAction = UIAlertAction(title: String.General.CANCEL, style: .cancel, handler: nil)
        alertController.addAction(openAction)
        alertController.addAction(cancelAction)

        DispatchQueue.main.async(execute: {
            self.window?.rootViewController?.present(alertController, animated: true, completion: nil)
        })
    }

    func convertToDictionary(text: String) -> [String: Any]? {
        if let data = text.data(using: .utf8) {
            do {
                return try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any]
            } catch {
                print(error.localizedDescription)
            }
        }
        return nil
    }

    func notificaton(_ userInfo: [AnyHashable: Any] ) {
        print(userInfo)
        
        if let type = userInfo["type"] as? String, type == "url", let urlString = userInfo["element"] as? String, let url = URL(string: urlString), self.window?.rootViewController != nil, self.window!.rootViewController!.isKind(of: ViewController.self) {
            self.openUrl = url
            NotificationCenter.default.post(name: NSNotification.Name.handleOpenUrl, object:self.openUrl!)
        } else if let aps = userInfo["aps"] as? [String:Any], let type = aps["type"] as? String, type == "url", let urlString = aps["element"] as? String, let url = URL(string: urlString), self.window?.rootViewController != nil, self.window!.rootViewController!.isKind(of: ViewController.self) {
            self.openUrl = url
            NotificationCenter.default.post(name: NSNotification.Name.handleOpenUrl, object:self.openUrl!)
        } else if userInfo["type"] as? String == "reminder" || (userInfo["aps"] as? [String:Any])?["type"] as? String == "reminder" {
            // NotificationCenter.default.post(name: NSNotification.Name.handleOnboarding, object:nil)
        } else if let infoapp = userInfo["infoapp"] as? [String:String] ?? (userInfo["aps"] as? [String:Any])?["infoapp"] as? [String:String], let type = infoapp["type"], type == "url", let urlString = infoapp["element"], let url = URL(string: urlString), self.window?.rootViewController != nil, self.window!.rootViewController!.isKind(of: ViewController.self) {
            self.openUrl = url
            NotificationCenter.default.post(name: NSNotification.Name.handleOpenUrl, object:self.openUrl!)
        } else {
            // ParseManager.handle(userInfo)
        }
        
    }
    
    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        if error._code == 3010 {
            print("Push notifications are not supported in the iOS Simulator.")
        } else {
            print("application:didFailToRegisterForRemoteNotificationsWithError: %@", error)
        }
    }
    

    // MARK: - Universal links
    func application(_ application: UIApplication, continue userActivity: NSUserActivity, restorationHandler: @escaping ([UIUserActivityRestoring]?) -> Void) -> Bool {
        if userActivity.activityType == NSUserActivityTypeBrowsingWeb, let url = userActivity.webpageURL {
            self.openUrl = url
            if self.window!.rootViewController != nil && self.window!.rootViewController!.isKind(of: ViewController.self) {
                NotificationCenter.default.post(name: Notification.Name(rawValue: "HANDLEOPENURL"), object:self.openUrl!)
            }
        }
        return true
    }

    func application(_ application: UIApplication, open url: URL, sourceApplication: String?, annotation: Any) -> Bool {
        return true
    }
    
    // MARK: - Core Data Saving support

    func saveContext () {
        let context = persistentContainer.viewContext
        if context.hasChanges {
            do {
                try context.save()
            } catch {
                // Replace this implementation with code to handle the error appropriately.
                let nserror = error as NSError
                fatalError("Unresolved error \(nserror), \(nserror.userInfo)")
            }
            
        }
    }


}

extension AppDelegate: UNUserNotificationCenterDelegate {
    
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        
        if UIApplication.shared.applicationState == .active {
            self.alertMessage(notification.request.content.userInfo)
        } else {
            completionHandler([.alert, .sound])
        }
    }
      
    // This function will be called right after user tap on the notification
    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        
        let application = UIApplication.shared
        let userInfo = response.notification.request.content.userInfo

        if response.notification.request.identifier == "exposedNotifId" {
            self.openUrl = URL(string: "\(String.Webapp.URL)exposed\(String.Webapp.PARAMS)")
            NotificationCenter.default.post(name: NSNotification.Name.handleOpenUrl, object:self.openUrl)
        } else if application.applicationState == .inactive || application.applicationState == .background {
            print("user tapped the notification bar when the app is in background")
            self.notificaton(userInfo)
        } else if application.applicationState == .active {
            print("user tapped the notification bar when the app is in foreground")
            self.alertMessage(userInfo)
        }
        /* Change root view controller to a specific viewcontroller */
        // let storyboard = UIStoryboard(name: "Main", bundle: nil)
        // let vc = storyboard.instantiateViewController(withIdentifier: "ViewControllerStoryboardID") as? ViewController
        // self.window?.rootViewController = vc
        
        completionHandler()
    }
    
}
