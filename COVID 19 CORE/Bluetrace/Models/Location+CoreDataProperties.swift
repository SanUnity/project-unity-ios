//
//  Location+CoreDataProperties.swift
//  COVID 19 CORE
//
//  Created by Emilio Cubo Ruiz on 23/03/2020.
//  Copyright © 2020 COVID 19 CORE. All rights reserved.
//

import Foundation
import CoreData
import UIKit
import CoreBluetooth

extension Location {

    enum CodingKeys: String, CodingKey {
        case timestamp
        case latitude
        case longitude
        case accuracy
    }

    @nonobjc public class func fetchRequest() -> NSFetchRequest<Location> {
        return NSFetchRequest<Location>(entityName: "Location")
    }

    @nonobjc public class func fetchRequestForLocations() -> NSFetchRequest<Location> {
        let fetchRequest = NSFetchRequest<Location>(entityName: "Location")
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: "timestamp", ascending: true)]
        return fetchRequest
    }

    @NSManaged public var timestamp: Date
    @NSManaged public var latitude: NSNumber
    @NSManaged public var longitude: NSNumber
    @NSManaged public var accuracy: NSNumber?

    // MARK: - Encodable
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(Int(timestamp.timeIntervalSince1970), forKey: .timestamp)
        try container.encode(latitude.doubleValue, forKey: .latitude)
        try container.encode(longitude.doubleValue, forKey: .longitude)
        try container.encode(accuracy?.doubleValue, forKey: .accuracy)
    }

}
