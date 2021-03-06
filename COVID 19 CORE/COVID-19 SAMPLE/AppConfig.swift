//
//  AppConfig.swift
//  COVID 19 CORE
//
//  Created by Emilio Cubo Ruiz on 23/03/2020.
//  Copyright © 2020 COVID 19 CORE. All rights reserved.
//

import UIKit

extension Data {
    
    struct General {
        public static var JWT_PUBLIC_KEY: Data? {
            return Data(base64Encoded: "LS0tLS1CRUdJTiBQVUJMSUMgS0VZLS0tLS0KTUZrd0V3WUhLb1pJemowQ0FRWUlLb1pJemowREFRY0RRZ0FFbXRQb3NheERoRFRxMjltQ3pKblpMem85Wm4veQpnREp4SHRUcHFMc3RDMTZzYVFySEkzL1ByKzQ4MUVEcDJ6eDREakJVSjBVdWFZWWFDWWhaOHZvSVFnPT0KLS0tLS1FTkQgUFVCTElDIEtFWS0tLS0t") // *** YOUR JWT PUBLIC KEY HERE ***
        }
    }
    
}

enum Environment {
    case dev
    case pro
}

struct AppConfig {
    static let environment: Environment = .dev
    static let protected: Bool = true
    static let reduceContactTracingSync: Bool = false
}

extension String {

    struct General {
        public static let APP_NAME = Bundle.main.infoDictionary?[kCFBundleNameKey as String] as? String ?? "COVID-19 SAMPLE"
        public static let ACCEPT = NSLocalizedString("Done", comment: "")
        public static let CANCEL = NSLocalizedString("Cancel", comment: "")
        public static let RETRY = NSLocalizedString("Retry", comment: "")
        public static let ERROR = NSLocalizedString("Error", comment: "")
        public static let SHOW = NSLocalizedString("Show", comment: "")
        public static let OrgID = "ES_PU"
        public static let CONTACT_TRACING_MODEL: ContactTracingModel = .none
        public static let BUSINESS_DAYS_TRACING: Bool = false
        public static let HAS_ONBOARDING: Bool = true
        public static let EXTERNAL_URLS: [String] = []
        public static let PASSPORT_NEEDED: Bool = false
        public static let URL_SCHEME: String = "covid-sample"
    }

    // WEBAPP URL
    struct Webapp {
        public static var HOST: String {
            return AppConfig.environment == .dev ? "app-unity.byglob.com" : "app-unity.byglob.com" // "*** YOUR DEV FRONT DOMAIN HERE ***" : "*** YOUR PRO FRONT DOMAIN HERE ***"
        }
        public static var HOSTS: [String] {
            return AppConfig.environment == .dev ? ["app-unity.byglob.com"] : ["app-unity.byglob.com"] // ["*** YOUR DEV DOMAIN / DOMAINS IN APP HERE ***"] : ["*** YOUR PRO DOMAIN / DOMAINS IN APP HERE ***"]
        }
        public static let URL = "https://\(String.Webapp.HOST)/"
        public static let PARAMS = "?so=iOS&v=\(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "")"
    }

    // API URL & METHODS
    struct Api {
        public static var HOST: String {
            return AppConfig.environment == .dev ? "back-unity.byglob.com" : "back-unity.byglob.com" // "*** YOUR DEVELOP FRONT DOMAIN HERE ***" : "*** YOUR PRODUCTION FRONT DOMAIN HERE ***"
        }
        public static let BASE_URL = "https://\(String.Api.HOST)/api/"
        public static let GET_TEMPIDS = "users/bluetrace/tempIDs"
        public static let POST_RECORDS = "users/bluetrace"
        public static let POST_LOCATIONS = "users/locations"
        public static let POST_DEVICE_TOKEN = "users/devicetoken"
        public static let POST_INIT_DEVICE_TOKEN = "devicetoken"
        public static let GET_EXPOSED_CONFIG = "exposed/config"
        public static let POST_EXPOSED_END = "exposed/end"
    }

    // SSL PINNING
    struct Pinning {
        public static var PUBLIC_KEY_HASHES: [String] {
            return AppConfig.protected ? ["47DEQpj8HBSa+/TImW+5JCeuQeRkm5NMpJWZG3hSuFU=","Y9mvm0exBk1JoQ57f9Vm28jKo5lFm/woKcVxrYxu80o="] : [] // ["*** YOUR PUBLIC HEY HASH HERE ***","*** YOUR OTHER PUBLIC HASH HERE ***"] : []
        }
    }

    // PUSH: PARSE CONFIGURATION & MESSAGES
    struct Push {
        public static let STATUS_TITLE = NSLocalizedString("Turned Bluetooth off by mistake?", comment: "")
        public static let REMINDER_TITLE = NSLocalizedString("We need you!", comment: "")
        public static let PUSH_BODY = NSLocalizedString("Help stop the spread of COVID-19 by keeping your phone’s Bluetooth on until the outbreak is over.", comment: "")
        public static let EXPOSED_TITLE = NSLocalizedString("", comment: "")
        public static let EXPOSED_BODY = NSLocalizedString("You have received a contact notification.", comment: "")
        
        public static let ONBOARDING_TITLE_1 = String(format: NSLocalizedString("%@ needs to be keep open to work", comment: ""), NSLocalizedString(String.General.APP_NAME, comment: ""))
        public static let ONBOARDING_BODY_1 = NSLocalizedString("To access power saver mode turn your phone down or keep it upside down in your pocket", comment: "")
        public static let ONBOARDING_TITLE_2 = NSLocalizedString("Meetings", comment: "")
        public static let ONBOARDING_BODY_2 = String(format: NSLocalizedString("Open %@ and turn your phone down on the table to keep open.", comment: ""), NSLocalizedString(String.General.APP_NAME, comment: ""))
        public static let ONBOARDING_TITLE_3 = NSLocalizedString("Meals", comment: "")
        public static let ONBOARDING_BODY_3 = String(format: NSLocalizedString("Open %@ and turn your phone down on the table to keep open.", comment: ""), NSLocalizedString(String.General.APP_NAME, comment: ""))
        public static let ONBOARDING_TITLE_4 = NSLocalizedString("Movement", comment: "")
        public static let ONBOARDING_BODY_4 = String(format: NSLocalizedString("Open %@ and keep your phone upside down in your pocket.", comment: ""), NSLocalizedString(String.General.APP_NAME, comment: ""))
    }

    // SHARE APP INFO
    struct Share {
        public static let URL = "*** YOUR URL TO SHARE HERE ***"
        public static let TITLE = String.General.APP_NAME
        public static let DESCRIPTION = NSLocalizedString("Help stop the spread of COVID-19.", comment: "")
    }

    // BLUETOOTH ALERTS
    struct Bluetooth {
        public static let ALERT_TITLE = NSLocalizedString("App restart required for Bluetooth to restart!", comment: "")
        public static let ALERT_MESSAGE = NSLocalizedString("Press Ok to exit the app!", comment: "")
    }

    static func identifierForAdvertising() -> String? {
        return nil
    }

}
