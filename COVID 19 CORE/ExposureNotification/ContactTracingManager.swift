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
        // DP3TManager.sharedInstance.initialize(trustKitCertificatePinning: trustKitCertificatePinning)
    }
    
    func stopTracing() {
        // DP3TManager.sharedInstance.stopTracing()
    }

    func startTracing() {
        // DP3TManager.sharedInstance.startTracing()
    }
    
    func getBTStatus(completion:@escaping (Int) -> ()) {
//        DP3TManager.sharedInstance.getBTStatus { (status) in
//            completion(status)
//        }
    }

    func sync(_ viewContoller: UIViewController? = nil) {
        // DP3TManager.sharedInstance.sync(viewContoller)
    }
    
    func setExposed(completion:@escaping (Bool) -> ()) {
//        DP3TManager.sharedInstance.setExposed { (success) in
//            completion(success)
//        }
    }
    
    func resetTracing() {
        // DP3TManager.sharedInstance.resetTracing()
    }
    
    func cancelTracing() {
        // DP3TManager.sharedInstance.cancelTracing()
    }
    
}
