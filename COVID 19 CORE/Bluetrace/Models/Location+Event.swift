//
//  Location+Event.swift
//  COVID 19 CORE
//
//  Created by Emilio Cubo Ruiz on 23/03/2020.
//  Copyright © 2020 COVID 19 CORE. All rights reserved.
//

import UIKit
import CoreData

extension Location {
    
    static func saveLocationWithCurrentTime(latitude: Double, longitude: Double, accuracy: Double?) {
        DispatchQueue.main.async {
            guard let appDelegate =
                UIApplication.shared.delegate as? AppDelegate else {
                    return
            }
            let managedContext = appDelegate.persistentContainer.viewContext
            let entity = NSEntityDescription.entity(forEntityName: "Location", in: managedContext)!
            let location = Location(entity: entity, insertInto: managedContext)
            location.latitude = NSNumber(value: latitude)
            location.longitude = NSNumber(value: longitude)
            location.accuracy = accuracy as NSNumber?
            location.timestamp = Date()
            do {
                try managedContext.save()
            } catch {
                print("Could not save. \(error)")
            }
        }
    }
    
}
