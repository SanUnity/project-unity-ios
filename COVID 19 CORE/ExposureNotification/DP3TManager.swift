//
//  DP3TManager.swift
//  COVID 19 CORE
//
//  Created by Emilio Cubo Ruiz on 05/06/2020.
//  Copyright © 2020 COVID 19 CORE. All rights reserved.
//

import UIKit
import DP3TSDK
import FirebaseAnalytics
import ExposureNotification

struct ConfigurationEN: Codable {
    let minimumRiskScore:Int
    let attenuationLevelValues: [Int]
    let daysSinceLastExposureLevelValues: [Int]
    let durationLevelValues: [Int]
    let transmissionRiskLevelValues: [Int]
    let lowerThreshold: Int
    let higherThreshold: Int
    let factorLow: Double
    let factorHigh: Double
    let triggerThreshold: Int
    let alert: AlertExposed
}

struct AlertExposed: Codable {
    let title: String
    let body: String
}

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
    public var initialized: Bool = false
    public var trackingState: AppTracingState = .inactive

    func getConfiguration() {
        if let url = URL(string: "\(String.Api.BASE_URL)\(String.Api.GET_EXPOSED_CONFIG)"), let session = (UIApplication.shared.delegate as? AppDelegate)?.trustKitCertificatePinning?.session {
            var request = URLRequest(url: url)
            request.httpMethod = "GET"
            if let token = AppSettings.userToken {
                request.addValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            }
            request.addValue("ios", forHTTPHeaderField: "API-apptype")

            let task = session.dataTask(with: request) { data, response, error in
                DispatchQueue.main.async(execute: { () -> Void in
                    AppSettings.configurationEN = data
                })
            }
            task.resume()
        }
    }
    
    func initialize(trustKitCertificatePinning: TrustKitCertificatePinning?) {
        if let appId = Bundle.main.bundleIdentifier, let baseUrl = URL(string: String.Api.BASE_URL) {
            self.getConfiguration()
            let decoder = JSONDecoder()
            if let configurationData = AppSettings.configurationEN, let configurationEN = try? decoder.decode(ConfigurationEN.self, from: configurationData) {
                let configuration = ENExposureConfiguration()
                configuration.minimumRiskScore = ENRiskScore(configurationEN.minimumRiskScore)
                configuration.attenuationLevelValues = configurationEN.attenuationLevelValues.map { (attenuationLevelValue) -> NSNumber in
                    return NSNumber(integerLiteral: attenuationLevelValue)
                }
                configuration.daysSinceLastExposureLevelValues = configurationEN.daysSinceLastExposureLevelValues.map { (daysSinceLastExposureLevelValue) -> NSNumber in
                    return NSNumber(integerLiteral: daysSinceLastExposureLevelValue)
                }
                configuration.durationLevelValues = configurationEN.durationLevelValues.map { (durationLevelValue) -> NSNumber in
                    return NSNumber(integerLiteral: durationLevelValue)
                }
                configuration.transmissionRiskLevelValues = configurationEN.transmissionRiskLevelValues.map { (transmissionRiskLevelValue) -> NSNumber in
                    return NSNumber(integerLiteral: transmissionRiskLevelValue)
                }
                configuration.metadata = ["attenuationDurationThresholds": [configurationEN.lowerThreshold, configurationEN.higherThreshold]]
                
                self.initialize(appId: appId, url: baseUrl, trustKitCertificatePinning: trustKitCertificatePinning, configuration: configuration, factorLow: configurationEN.factorLow, factorHigh: configurationEN.factorHigh, triggerThreshold: configurationEN.triggerThreshold)
            } else {
                self.initialize(appId: appId, url: baseUrl, trustKitCertificatePinning: trustKitCertificatePinning)
            }
        }
    }
    
    func initialize(appId: String, url: URL, trustKitCertificatePinning: TrustKitCertificatePinning?, configuration: ENExposureConfiguration? = nil, factorLow: Double? = nil, factorHigh: Double? = nil, triggerThreshold: Int? = nil) {
        if !self.initialized {
            // let descriptor = ApplicationDescriptor(appId: appId, bucketBaseUrl: url, reportBaseUrl: url, jwtPublicKey: nil, mode: .production)

            let descriptor = ApplicationDescriptor(appId: appId, bucketBaseUrl: url, reportBaseUrl: url, jwtPublicKey: Data.General.JWT_PUBLIC_KEY, mode: .production)
            do {
                try DP3TTracing.initialize(with: descriptor,
                                           urlSession: trustKitCertificatePinning?.session ?? URLSession.shared,
                                           backgroundHandler:  nil,
                                           configuration: configuration,
                                           factorLow: factorLow,
                                           factorHigh: factorHigh,
                                           triggerThreshold: triggerThreshold)
                self.initialized = true
                DP3TTracing.delegate = self
                if String.General.CONTACT_TRACING_MODEL != .none, AppSettings.bluetoothRequested {
                    self.startTracing()
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
                            case .networkingError, .cancelled, .userAlreadyMarkedAsInfected:
                                self.trackingState = .inactive
                            case .caseSynchronizationError(let errors):
                                print(errors.count)
                                self.trackingState = .inactive
                            case .exposureNotificationError(let error):
                                if error.localizedDescription == "ENErrorCodeNotAuthorized (User denied)" {
                                    self.trackingState = .permissonError
                                } else {
                                    self.trackingState = .notCompatible
                                }
                            case .databaseError(let error):
                                print(error?.localizedDescription ?? "no error")
                                self.trackingState = .inactive
                            }
                        case .stopped:
                            self.trackingState = .stopped
                        }
                    case .failure:
                        break
                    }

                    if #available(iOS 13.5, *), UIDevice.current.model == "iPhone" {
                        switch self.trackingState {
                        case .inactive, .stopped:
                            completion(0)
                        case .notCompatible:
                            completion(5)
                        case .active:
                            completion(1)
                        case .bluetoothOff:
                            completion(2)
                        case .permissonError:
                            completion(3)
                        }
                    } else {
                        completion(5)
                    }

                }

            }
        }
    }
    
    func stopTracing() {
        if self.initialized {
            DP3TTracing.stopTracing()
            DP3TTracing.delegate = nil
            started = false
            Analytics.logEvent("stop_bluetooth", parameters: nil)
        }
    }
    
    func startTracing() {
        if self.initialized {
            if !started {
                do {
                    Logger.DLog("Start BT tracing")
                    try DP3TTracing.startTracing()
                    started = true
                    Analytics.logEvent("start_bluetooth", parameters: nil)
                } catch {
                    Logger.DLog("DP3TTracing Start failed")
                }
            }
        }
    }
    
    func sync(_ viewContoller: UIViewController? = nil) {
        if self.initialized {
            DP3TTracing.sync { [weak self] result in
                switch result {
                case let .failure(error):
                    let ac = UIAlertController(title: String.General.ERROR, message: error.localizedDescription, preferredStyle: .alert)
                    ac.addAction(.init(title: String.General.RETRY, style: .default) { _ in self?.sync(viewContoller) })
                    ac.addAction(.init(title: String.General.CANCEL, style: .destructive))
                    viewContoller?.present(ac, animated: true)
                default:
                    break
                }
            }
        }
    }
    
    func setExposed(completion:@escaping (Bool) -> ()) {
        if self.initialized, let token = AppSettings.userToken {
            DP3TTracing.iWasExposed(onset: Date(timeIntervalSinceNow: -60 * 60 * 24 * 14), authentication: .HTTPAuthorizationBearer(token: token)) { _ in
                DP3TTracing.status { result in
                    switch result {
                    case let .success(state):
                        // ContactTracingManager.sharedInstance.resetTracing()
                        Logger.DLog("exposed succeded \(state)")
                        completion(true)
                    case .failure:
                        Logger.DLog("exposed failed")
                        completion(false)
                    }
                }
            }
        } else {
            Logger.DLog("exposed failed")
            completion(false)
        }
    }
    
    func resetTracing() {
        if self.initialized {
            do {
                try DP3TTracing.reset()
                AppSettings.lastExposedNotificationDate = Date(timeIntervalSince1970: 0)
                UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ["exposedNotifId"])
                self.initialize(trustKitCertificatePinning: (UIApplication.shared.delegate as? AppDelegate)?.trustKitCertificatePinning)
            } catch {}
        }
    }
    
    func cancelTracing() {
        if self.initialized {
            do {
                try DP3TTracing.reset()
                AppSettings.lastExposedNotificationDate = Date(timeIntervalSince1970: 0)
            } catch {}
        }
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
            case .networkingError, .cancelled, .userAlreadyMarkedAsInfected:
                self.trackingState = .inactive
            case .caseSynchronizationError(let errors):
                print(errors.count)
                self.trackingState = .inactive
            case .exposureNotificationError(let error):
                if error.localizedDescription == "ENErrorCodeNotAuthorized (User denied)" {
                    self.trackingState = .permissonError
                } else {
                    self.trackingState = .notCompatible
                }
            case .databaseError(let error):
                print(error?.localizedDescription ?? "no error")
                self.trackingState = .inactive
            }
        case .stopped:
            self.trackingState = .stopped
        }
        
        if currentTracing != self.trackingState {
            NotificationCenter.default.post(name: NSNotification.Name.handleUpdateStateTracing, object:nil)
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
            if AppSettings.lastExposedNotificationDate.addingTimeInterval(60 * 60) < Date() {
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
        content.sound = .default
        content.badge = 1

        let json: [AnyHashable: Any]
        let decoder = JSONDecoder()
        if let configurationData = AppSettings.configurationEN, let configurationEN = try? decoder.decode(ConfigurationEN.self, from: configurationData) {
            content.title = configurationEN.alert.title
            content.body = configurationEN.alert.body
            json = [
                "aps":  [
                    "alert":   [
                        "title":    configurationEN.alert.title,
                        "body":     configurationEN.alert.body,
                    ],
                    "sound":        "default",
                    "type":         "url",
                    "element":      "\(String.Webapp.URL)main/faq/exposed\(String.Webapp.PARAMS)"
                ]
            ]
        } else {
            content.body = String.Push.EXPOSED_BODY
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
                        "element":      "\(String.Webapp.URL)main/faq/exposed\(String.Webapp.PARAMS)"
                    ]
                ]
            } else {
                json = [
                    "aps":  [
                        "alert":   String.Push.EXPOSED_BODY,
                        "sound" : "default",
                        "type":     "url",
                        "element":  "\(String.Webapp.URL)exposed\(String.Webapp.PARAMS)"
                    ]
                ]
            }
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
