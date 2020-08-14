//
//  ContactTracingManager.swift
//  COVID 19 CORE
//
//  Created by Emilio Cubo Ruiz on 23/03/2020.
//  Copyright © 2020 COVID 19 CORE. All rights reserved.
//

import UIKit
import CoreData
import UserNotifications

public enum ContactTracingModel {
    case none
    case centralised
    case decentralised
    case exposure_notification
}

class ContactTracingManager {
    
    static let sharedInstance: ContactTracingManager = { return ContactTracingManager() }()

    func initialize(trustKitCertificatePinning: TrustKitCertificatePinning?) {
        
        if String.General.CONTACT_TRACING_MODEL == .exposure_notification {
            if #available(iOS 13.5, *) {
                DP3TManager.sharedInstance.initialize(trustKitCertificatePinning: trustKitCertificatePinning)
            }
        } else if String.General.CONTACT_TRACING_MODEL == .decentralised {
            DP3TManager.sharedInstance.initialize(trustKitCertificatePinning: trustKitCertificatePinning)
        } else if String.General.CONTACT_TRACING_MODEL == .centralised, AppSettings.bluetoothRequested {
            if BluetraceManager.shared.isBluetoothAuthorized() {
                BluetraceManager.shared.turnOn()
            }
            EncounterMessageManager.shared.setup()
            BlueTraceLocalNotifications.shared.initialConfiguration()
        }

    }
    
    func stopTracing() {
        if String.General.CONTACT_TRACING_MODEL == .exposure_notification {
            if #available(iOS 13.5, *) {
                DP3TManager.sharedInstance.stopTracing()
            }
        } else if String.General.CONTACT_TRACING_MODEL == .decentralised {
            DP3TManager.sharedInstance.stopTracing()
        } else if String.General.CONTACT_TRACING_MODEL == .centralised {
            BluetraceManager.shared.turnOff()
        }
    }

    func startTracing() {
        if String.General.CONTACT_TRACING_MODEL == .exposure_notification {
            if #available(iOS 13.5, *) {
                DP3TManager.sharedInstance.startTracing()
            }
        } else if String.General.CONTACT_TRACING_MODEL == .decentralised {
            DP3TManager.sharedInstance.startTracing()
        } else if String.General.CONTACT_TRACING_MODEL == .centralised {
            BluetraceManager.shared.turnOn()
        }
    }

    func getBTStatus(completion:@escaping (Int) -> ()) {
        DP3TManager.sharedInstance.getBTStatus { (status) in
            completion(status)
        }
    }

    func sync(_ viewContoller: UIViewController? = nil) {
        if String.General.CONTACT_TRACING_MODEL == .exposure_notification {
            if #available(iOS 13.5, *) {
                DP3TManager.sharedInstance.sync(viewContoller)
            }
        } else if String.General.CONTACT_TRACING_MODEL == .decentralised {
            DP3TManager.sharedInstance.sync(viewContoller)
        }
    }
    
    func setExposed(completion:@escaping (Bool) -> ()) {
        if String.General.CONTACT_TRACING_MODEL == .exposure_notification {
            if #available(iOS 13.5, *) {
                DP3TManager.sharedInstance.setExposed { (success) in
                    completion(success)
                }
            } else {
                completion(false)
            }
        } else if String.General.CONTACT_TRACING_MODEL == .decentralised {
            DP3TManager.sharedInstance.setExposed { (success) in
                completion(success)
            }
        } else if String.General.CONTACT_TRACING_MODEL == .centralised {
            self.sendReport { (success) in
                completion(success)
            }
        } else {
            completion(false)
        }
    }
    
    func resetTracing() {
        if String.General.CONTACT_TRACING_MODEL == .exposure_notification {
            if #available(iOS 13.5, *) {
                DP3TManager.sharedInstance.resetTracing()
            }
        } else if String.General.CONTACT_TRACING_MODEL == .decentralised {
            DP3TManager.sharedInstance.resetTracing()
        }
    }
    
    func cancelTracing() {
        if String.General.CONTACT_TRACING_MODEL == .exposure_notification {
            if #available(iOS 13.5, *) {
                DP3TManager.sharedInstance.cancelTracing()
            }
        } else if String.General.CONTACT_TRACING_MODEL == .decentralised {
            DP3TManager.sharedInstance.cancelTracing()
        }
    }
    
    func sendReport(completion:@escaping (Bool) -> ()) {
        if String.General.CONTACT_TRACING_MODEL == .centralised, let token = AppSettings.userToken {
            self.sendReport(token: token) { (success) in
                if success {
                    BluetraceUtils.removeAllData()
                }
                completion(success)
            }
        } else {
            completion(false)
        }
    }
    
    func sendReport(token: String, _ result: @escaping (Bool) -> Void) {
        let manufacturer = "Apple"
        let model = DeviceInfo.getModel().replacingOccurrences(of: " ", with: "")

        let date: Date = Date()
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        let todayDate = dateFormatter.string(from: date)

        guard let appDelegate = UIApplication.shared.delegate as? AppDelegate else {
            result(false)
            return
        }

        let managedContext = appDelegate.persistentContainer.viewContext

        let recordsFetchRequest: NSFetchRequest<Encounter> = Encounter.fetchRequestForRecords()
        
        managedContext.perform {
            
            guard let records = try? recordsFetchRequest.execute() else {
                Logger.DLog("Error fetching records")
                result(false)
                return
            }

            let data = UploadFileData(manufacturer: manufacturer, model: model, todayDate: todayDate, records: records)

            let encoder = JSONEncoder()
            guard let json = try? encoder.encode(data) else {
                Logger.DLog("Error serializing data")
                result(false)
                return
            }
            
            let jsonString = String(data: json, encoding: .utf8)
            Logger.DLog("JSON to send: \(String(describing: jsonString))")

            let urlString = "\(String.Api.BASE_URL)\(String.Api.POST_RECORDS)"

            guard let url = URL(string: urlString) else {
                Logger.DLog("Error api URL")
                result(false)
                return
            }

            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.httpBody = json
            request.addValue("application/json", forHTTPHeaderField: "content-type")
            request.addValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            request.addValue("ios", forHTTPHeaderField: "API-apptype")
            
            if let session = (UIApplication.shared.delegate as? AppDelegate)?.trustKitCertificatePinning?.session {
                let task = session.dataTask(with: request) { data, response, error in
                    DispatchQueue.main.async(execute: { () -> Void in
                        if let error = error {
                            print(error.localizedDescription)
                            result(false)
                        } else if let httpResponse = response as? HTTPURLResponse {
                            switch httpResponse.statusCode {
                            case 200:
                                result(true)
                            default:
                                print(httpResponse.statusCode)
                                result(false)
                            }
                        } else {
                            result(false)
                        }
                    })
                }
                task.resume()
            }
        }
    }

}
