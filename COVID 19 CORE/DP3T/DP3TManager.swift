//
//  DP3TManager.swift
//  COVID 19 CORE
//
//  Created by Emilio Cubo Ruiz on 05/06/2020.
//  Copyright © 2020 COVID 19 CORE. All rights reserved.
//

import UIKit
import FirebaseAnalytics
// import DP3TSDK

enum AppTracingState {
    case active
    case inactive
    case bluetoothOff
    case permissonError
    case stopped
    case notCompatible
}

class DP3TManager {
    
    static let sharedInstance: DP3TManager = { return DP3TManager() }()
    public var started: Bool = false
    public var trackingState: AppTracingState = .inactive

    func initialize(trustKitCertificatePinning: TrustKitCertificatePinning?) {
        if let appId = Bundle.main.bundleIdentifier, let url = URL(string: String.Api.BASE_URL) {
            let descriptor = ApplicationDescriptor(appId: appId, bucketBaseUrl: url, reportBaseUrl: url, jwtPublicKey: nil)
            // let descriptor = ApplicationDescriptor(appId: appId, bucketBaseUrl: url, reportBaseUrl: url, jwtPublicKey: Data.General.JWT_PUBLIC_KEY)
            do {
                try DP3TTracing.initialize(with: .manual(descriptor), urlSession: trustKitCertificatePinning?.session ?? URLSession.shared, mode: .production)
                DP3TTracing.delegate = self
                if AppSettings.bluetoothRequested {
                    if BluetraceManager.shared.isBluetoothAuthorized() {
                        self.startTracing()
                    }
                }
            } catch {
                Logger.DLog("DP3TTracing Initialize failed")
            }
        }
    }
    
    func getBTStatus(completion:@escaping (Int) -> ()) {
        DP3TManager.sharedInstance.checkNotificationAuthorization { (success) in
            if !success {
                completion(4)
            } else {
                DP3TTracing.status { result in
                    switch result {
                    case let .success(state):
                        switch state.trackingState {
                        case .active:
                            self.trackingState = .active
                        case .inactive(let inactiveError):
                            switch inactiveError {
                            case .bluetoothTurnedOff:
                                self.trackingState = .bluetoothOff
                            case .permissonError:
                                self.trackingState = .permissonError
                            case .networkingError, .userAlreadyMarkedAsInfected:
                                self.trackingState = .inactive
                            case .caseSynchronizationError(let errors):
                                print(errors.count)
                                self.trackingState = .inactive
                            case .databaseError(let error):
                                print(error?.localizedDescription ?? "no error")
                                self.trackingState = .inactive
                            default:
                                self.trackingState = .inactive
                            }
                        case .stopped:
                            self.trackingState = .stopped
                        }
                    case .failure:
                        break
                    }

                    switch self.trackingState {
                    case .inactive, .stopped: // parado o inactivo
                        completion(0)
                    case .notCompatible: // incompatible con BT
                        completion(5)
                    case .active: // BT activo
                        completion(1)
                    case .bluetoothOff: // BT apagado
                        completion(2)
                    case .permissonError: // Sin permisos de BT para la app
                        completion(3)
                    }

                }
            }
        }
    }

    func stopTracing() {
        DP3TTracing.stopTracing()
        DP3TTracing.delegate = nil
        started = false
        Analytics.logEvent("stop_bluetooth", parameters: nil)
    }
    
    func startTracing() {
        if !started {
            do {
                try DP3TTracing.startTracing()
                Logger.DLog("Start BT tracing")
                started = true
                Analytics.logEvent("start_bluetooth", parameters: nil)
            } catch {
                Logger.DLog("DP3TTracing Start failed")
            }
        }
    }
    
    func sync(_ viewContoller: UIViewController? = nil) {
        DP3TTracing.sync { [weak self] result in
            switch result {
            case let .failure(error):
                let ac = UIAlertController(title: String.General.ERROR, message: error.localizedDescription, preferredStyle: .alert)
                ac.addAction(.init(title: String.General.RETRY, style: .default) { _ in self?.sync(viewContoller) })
                ac.addAction(.init(title: String.General.CANCEL, style: .destructive))
                viewContoller?.present(ac, animated: true)
            default:
                let date = "\(Date().timeIntervalSince1970 * 1000)"
                var logs = AppSettings.logs
                logs.append("\(date) - Server sync")
                AppSettings.logs = logs
                Analytics.logEvent("sync_bluetooth", parameters: nil)
                break
            }
        }
    }
    
    func setExposed(completion:@escaping (Bool) -> ()) {
        if let token = AppSettings.userToken {
            var onFinish: Bool = false
            for i in 0...Default.shared.parameters.crypto.numberOfDaysToKeepMatchedContacts - 1 {
                DP3TTracing.iWasExposed(onset: Date(timeIntervalSinceNow: TimeInterval(-60 * 60 * 24 * i)), authentication: .HTTPAuthorizationBearer(token: token)) { _ in
                    DP3TTracing.status { result in
                        switch result {
                        case let .success(state):
                            if onFinish {
                                onFinish = false
                                ContactTracingManager.sharedInstance.resetTracing()
                                Logger.DLog("exposed succeded \(state)")
                                completion(true)
                            }
                        case .failure:
                            Logger.DLog("exposed failed")
                            completion(false)
                        }
                    }
                }
            }
            onFinish = true
        } else {
            Logger.DLog("exposed failed")
            completion(false)
        }
    }
    
    func resetTracing() {
        do {
            try DP3TTracing.reset()
            AppSettings.lastExposedNotificationDate = Date(timeIntervalSince1970: 0)
            UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ["exposedNotifId"])
            self.initialize(trustKitCertificatePinning: (UIApplication.shared.delegate as? AppDelegate)?.trustKitCertificatePinning)
        } catch {}
    }
    
    func cancelTracing() {
        do {
            try DP3TTracing.reset()
            AppSettings.lastExposedNotificationDate = Date(timeIntervalSince1970: 0)
        } catch {}
    }

}

extension DP3TManager: DP3TTracingDelegate {
    
    func DP3TTracingStateChanged(_ state: TracingState) {

        /// - numberOfHandshakes: The number of handshakes with other phones
        /// - numberOfContacts: The number of encounters with other people
        /// - trackingState (active, stopped, inactive): The tracking state of the bluetooth and the other networking api
        /// - lastSync: The last syncronization when the list of infected people was fetched
        /// - infectionStatus: The infection status of the user
        /// - backgroundRefreshState: Indicates if the user has enabled backgorundRefresh
        
        let currentTracing = self.trackingState
        
        switch state.trackingState {
        case .active:
            self.trackingState = .active
        case .inactive(let inactiveError):
            switch inactiveError {
            case .bluetoothTurnedOff:
                self.trackingState = .bluetoothOff
            case .permissonError:
                self.trackingState = .permissonError
            case .networkingError, .userAlreadyMarkedAsInfected:
                self.trackingState = .inactive
            case .caseSynchronizationError(let errors):
                print(errors.count)
                self.trackingState = .inactive
//            case .exposureNotificationError(let error):
//                if error.localizedDescription == "ENErrorCodeNotAuthorized (User denied)" {
//                    self.trackingState = .permissonError
//                } else {
//                    self.trackingState = .notCompatible
//                }
            case .databaseError(let error):
                print(error?.localizedDescription ?? "no error")
                self.trackingState = .inactive
            default:
                self.trackingState = .inactive
            }
        case .stopped:
            self.trackingState = .stopped
        }

        if currentTracing != self.trackingState {
            NotificationCenter.default.post(name: NSNotification.Name.handleUpdateStateTracing, object:nil)
            
            let date = "\(Date().timeIntervalSince1970 * 1000)"
            var logs = AppSettings.logs
            if self.trackingState == .active {
                logs.append("\(date) - Active CT")
                Analytics.logEvent("active_ct", parameters: nil)
            } else {
                logs.append("\(date) - Disable CT")
                Analytics.logEvent("disable_ct", parameters: nil)
            }
            AppSettings.logs = logs
        }

        switch state.infectionStatus {
        case .healthy:
            print("InfectionStatus: HEALTHY")
        case let .exposed(matches):
            print("InfectionStatus: EXPOSED")
            print("Exposed matches: \(matches.count)")
            for i in 0..<matches.count {
                let match = matches[i]
                print(match.identifier)
                print(match.exposedDate)
                print(match.reportDate)
            }
            if AppSettings.lastExposedNotificationDate.addingTimeInterval(20 * 60) < Date() {
                AppSettings.lastExposedNotificationDate = Date()
                self.sendExposureNotification()
            }
        /*
        case .exposed:
            print("InfectionStatus: EXPOSED")

            if AppSettings.lastExposedNotificationDate.addingTimeInterval(20 * 60) < Date() {
                AppSettings.lastExposedNotificationDate = Date()
                self.sendExposureNotification()
            }
        */
        case .infected:
            print("InfectionStatus: INFECTED")
        }
        
    }
    
    func checkNotificationAuthorization(completion: @escaping (_ granted: Bool) -> Void) {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
            DispatchQueue.main.async {
                completion(granted)
            }
        }
    }

    func sendExposureNotification() {
        
        let notificationCenter = UNUserNotificationCenter.current()
        notificationCenter.delegate = UIApplication.shared.delegate as? AppDelegate
        let content = UNMutableNotificationContent()
        content.body = String.Push.EXPOSED_BODY
        content.sound = .default
        content.badge = 1
        let json: [AnyHashable: Any]
        if String.Push.EXPOSED_TITLE != "" {
            content.title = String.Push.EXPOSED_TITLE
            json = [
                "aps":  [
                    "alert":   [
                        "title":    String.Push.EXPOSED_TITLE,
                        "body":     String.Push.EXPOSED_BODY,
                    ],
                    "sound":        "default",
                    "type":         "url",
                    "element":      "\(String.Webapp.URL)exposed\(String.Webapp.PARAMS)"
                ]
            ]
        } else {
            json = [
                "aps":  [
                    "alert":   String.Push.EXPOSED_BODY,
                    "sound":   "default",
                    "type":    "url",
                    "element": "\(String.Webapp.URL)exposed\(String.Webapp.PARAMS)"
                ]
            ]
        }
        content.userInfo = json
        
        notificationCenter.removePendingNotificationRequests(withIdentifiers: ["exposedNotifId"])
        notificationCenter.add(UNNotificationRequest(identifier: "exposedNotifId",
                              content: content,
                              trigger: UNTimeIntervalNotificationTrigger(timeInterval: 5, repeats: false)
        )) { (error) in
            if let error = error {
                Logger.DLog("Notification error: \(error.localizedDescription)")
            }
        }

    }
    
}
