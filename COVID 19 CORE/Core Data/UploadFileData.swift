//
//  UploadFileData.swift
//  OpenTrace

import Foundation

struct UploadFileData: Encodable {

    // var token: String
    
    // NEW ATTRS
    var manufacturer: String
    var model: String
    var todayDate: String

    var records: [Encounter]
    // var events: [Encounter]

}

struct LocationFileData: Encodable {

    // var token: String
    
    // NEW ATTRS
    var manufacturer: String
    var model: String
    var todayDate: String

    var records: [Location]
    // var events: [Encounter]

}
