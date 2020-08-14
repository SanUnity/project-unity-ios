//
//  AppSettings.swift
//  COVID 19 CORE
//
//  Created by Emilio Cubo Ruiz on 23/03/2020.
//  Copyright © 2020 COVID 19 CORE. All rights reserved.
//

import Foundation
import SwiftKeychainWrapper
import TrustKit
import Photos

enum Environment {
    case dev
    case pre    
    case pro
}

extension String {
    struct Settings {
        public static let SETTINGS_TITLE = NSLocalizedString("Settings", comment: "")
        public static let SETTINGS_MESSAGE = String(format: NSLocalizedString("%@ does not have access permissions to Contacts", comment: ""), String.General.APP_NAME)
        public static let SETTINGS_BUTTON = NSLocalizedString("Go to Settings?", comment: "")
    }
}

struct AppSettings {
    
    static let environment: Environment = .pre
    static let protected: Bool = true
    static let reduceContactTracingSync: Bool = false

    static var userId: String? {
        get {
            return KeychainWrapper.standard.string(forKey: "USERID")
        }
        set {
            if let newValue = newValue {
                KeychainWrapper.standard.set(newValue, forKey: "USERID")
            } else {
                KeychainWrapper.standard.removeObject(forKey: "USERID")
            }
        }
    }

    static var userToken: String? {
        get {
            return KeychainWrapper.standard.string(forKey: "TOKEN")
        }
        set {
            if let newValue = newValue {
                AppSettings.isUserLogged = true
                KeychainWrapper.standard.set(newValue, forKey: "TOKEN")
            } else {
                AppSettings.isUserLogged = false
                KeychainWrapper.standard.removeObject(forKey: "TOKEN")
            }
        }
    }
    
    static var isUserLogged: Bool {
        get {
            return UserDefaults.standard.bool(forKey: "USER_LOGGED")
        }
        set {
            UserDefaults.standard.set(newValue, forKey: "USER_LOGGED")
        }
    }
    
    static var isShowOnboarding: Bool {
        get {
            return UserDefaults.standard.bool(forKey: "ONBOARDING_SHOWED")
        }
        set {
            UserDefaults.standard.set(newValue, forKey: "ONBOARDING_SHOWED")
        }
    }

    static var appDeviceToken: String? {
        get {
            return UserDefaults.standard.string(forKey: "APP_DEVICE_TOKEN")
        }
        set {
            UserDefaults.standard.set(newValue, forKey: "APP_DEVICE_TOKEN")
        }
    }

    static var deviceToken: String? {
        get {
            return UserDefaults.standard.string(forKey: "DEVICE_TOKEN")
        }
        set {
            UserDefaults.standard.set(newValue, forKey: "DEVICE_TOKEN")
        }
    }

    static var initDeviceToken: String? {
        get {
            return UserDefaults.standard.string(forKey: "INIT_DEVICE_TOKEN")
        }
        set {
            UserDefaults.standard.set(newValue, forKey: "INIT_DEVICE_TOKEN")
        }
    }

    static var lastExposedNotificationDate:Date {
        get {
            let timeInterval = UserDefaults.standard.integer(forKey: "LAST_EXPOSED_NOTIFICATION_DATE")
            return Date(timeIntervalSince1970: TimeInterval(timeInterval))
        }
        set {
            UserDefaults.standard.set(Int(newValue.timeIntervalSince1970), forKey: "LAST_EXPOSED_NOTIFICATION_DATE")
        }
    }

    static var autoActivation: Bool {
        get {
            return UserDefaults.standard.bool(forKey: "AUTO_ACTIVATION")
        }
        set {
            UserDefaults.standard.set(newValue, forKey: "AUTO_ACTIVATION")
        }
    }

    static var userHasPassport: Bool {
        get {
            return UserDefaults.standard.bool(forKey: "HAS_PASSPORT")
        }
        set {
            UserDefaults.standard.set(newValue, forKey: "HAS_PASSPORT")
        }
    }

    static var dateTracingStoped: Date? {
        get {
            return UserDefaults.standard.object(forKey: "DATE_TRACING_STOPPED") as? Date
        }
        set {
            UserDefaults.standard.set(newValue, forKey: "DATE_TRACING_STOPPED")
        }
    }

    static var bluetoothRequested: Bool {
        get {
            return UserDefaults.standard.bool(forKey: "BT_REQUESTED")
        }
        set {
            UserDefaults.standard.set(newValue, forKey: "BT_REQUESTED")
        }
    }

    static var configurationEN: Data? {
        get {
            return UserDefaults.standard.object(forKey: "CONFIGURATION_EN") as? Data
        }
        set {
            UserDefaults.standard.set(newValue, forKey: "CONFIGURATION_EN")
        }
    }
    
    static var exposedLength: Int {
        get {
            return UserDefaults.standard.integer(forKey: "EXPOSED_LENGTH")
        }
        set {
            UserDefaults.standard.set(newValue, forKey: "EXPOSED_LENGTH")
        }
    }

    static var windowLength: Int {
        get {
            return UserDefaults.standard.integer(forKey: "WINDOW_LENGTH")
        }
        set {
            UserDefaults.standard.set(newValue, forKey: "WINDOW_LENGTH")
        }
    }

    static var appData: String {
        get {
            return UserDefaults.standard.string(forKey: "APP_DATA") ?? "{}"
        }
        set {
            UserDefaults.standard.set(newValue, forKey: "APP_DATA")
        }
    }
    
    static var logs: [String] {
        get {
            return UserDefaults.standard.object(forKey: "APP_LOGS") as? [String] ?? [String]()
        }
        set {
            UserDefaults.standard.set(newValue, forKey: "APP_LOGS")
        }
    }
    static func logOut() {
        AppSettings.userId = nil
        AppSettings.userToken = nil
        if #available(iOS 13.5, *), UIDevice.current.model == "iPhone", AppSettings.bluetoothRequested, String.General.CONTACT_TRACING_MODEL != .none {
            AppSettings.bluetoothRequested = false
            ContactTracingManager.sharedInstance.stopTracing()
        }
        let initDeviceToken = AppSettings.initDeviceToken
        let defs: UserDefaults = UserDefaults.standard
        let dict:NSDictionary = defs.dictionaryRepresentation() as NSDictionary
        for key in dict {
            defs.removeObject(forKey: key.key as! String)
        }
        defs.synchronize()

        AppSettings.isShowOnboarding = true
        if let initDeviceToken = initDeviceToken {
            AppSettings.initDeviceToken = initDeviceToken
        }
    }

}

private struct JailBrokenHelper {
    //check if cydia is installed (using URI Scheme)
    static func hasCydiaInstalled() -> Bool {
        return UIApplication.shared.canOpenURL(URL(string: "cydia://")!)
    }
    
    //Check if suspicious apps (Cydia, FakeCarrier, Icy etc.) is installed
    static func isContainsSuspiciousApps() -> Bool {
        for path in suspiciousAppsPathToCheck {
            if FileManager.default.fileExists(atPath: path) {
                return true
            }
        }
        return false
    }
    
    //Check if system contains suspicious files
    static func isSuspiciousSystemPathsExists() -> Bool {
        for path in suspiciousSystemPathsToCheck {
            if FileManager.default.fileExists(atPath: path) {
                return true
            }
        }
        return false
    }
    
    //Check if app can edit system files
    static func canEditSystemFiles() -> Bool {
        let jailBreakText = "Developer Insider"
        do {
            try jailBreakText.write(toFile: jailBreakText, atomically: true, encoding: .utf8)
            return true
        } catch {
            return false
        }
    }
    
    //suspicious apps path to check
    static var suspiciousAppsPathToCheck: [String] {
        return ["/Applications/Cydia.app",
                "/Applications/blackra1n.app",
                "/Applications/FakeCarrier.app",
                "/Applications/Icy.app",
                "/Applications/IntelliScreen.app",
                "/Applications/MxTube.app",
                "/Applications/RockApp.app",
                "/Applications/SBSettings.app",
                "/Applications/WinterBoard.app"
        ]
    }
    
    //suspicious system paths to check
    static var suspiciousSystemPathsToCheck: [String] {
        return ["/Library/MobileSubstrate/DynamicLibraries/LiveClock.plist",
                "/Library/MobileSubstrate/DynamicLibraries/Veency.plist",
                "/private/var/lib/apt",
                "/private/var/lib/apt/",
                "/private/var/lib/cydia",
                "/private/var/mobile/Library/SBSettings/Themes",
                "/private/var/stash",
                "/private/var/tmp/cydia.log",
                "/System/Library/LaunchDaemons/com.ikey.bbot.plist",
                "/System/Library/LaunchDaemons/com.saurik.Cydia.Startup.plist",
                "/usr/bin/sshd",
                "/usr/libexec/sftp-server",
                "/usr/sbin/sshd",
                "/etc/apt",
                "/bin/bash",
                "/Library/MobileSubstrate/MobileSubstrate.dylib"
        ]
    }
}

extension Bundle {

    var bluetoothPermission: String? {
        return object(forInfoDictionaryKey: "NSBluetoothAlwaysUsageDescription") as? String
    }
    
    var locationPermission: String? {
        return object(forInfoDictionaryKey: "NSLocationAlwaysAndWhenInUseUsageDescription") as? String
    }

    var contactPermission: String? {
        return object(forInfoDictionaryKey: "NSContactsUsageDescription") as? String
    }

}

extension Notification.Name {
    static let handleActive = Notification.Name("handleActive")
    static let handleOpenUrl = Notification.Name("handleOpenUrl")
    static let handleReload = Notification.Name("handleReload")
    static let handleOnboarding = Notification.Name("handleOnboarding")
    static let handleUpdateStateTracing = Notification.Name("handleUpdateStateTracing")
}

extension PHPhotoLibrary {
    
    func savePhoto(image:UIImage, albumName:String, completion:((PHAsset?)->())? = nil) {
        func save() {
            if let album = PHPhotoLibrary.shared().findAlbum(albumName: albumName) {
                PHPhotoLibrary.shared().saveImage(image: image, album: album, completion: completion)
            } else {
                PHPhotoLibrary.shared().createAlbum(albumName: albumName, completion: { (collection) in
                    if let collection = collection {
                        PHPhotoLibrary.shared().saveImage(image: image, album: collection, completion: completion)
                    } else {
                        completion?(nil)
                    }
                })
            }
        }
        
        if PHPhotoLibrary.authorizationStatus() == .authorized {
            save()
        } else {
            PHPhotoLibrary.requestAuthorization({ (status) in
                if status == .authorized {
                    save()
                } else {
                    completion?(nil)
                }
            })
        }
    }
    
    func saveVideo(urlData:NSData, albumName:String, completion:((PHAsset?)->())? = nil) {
        func save() {
            if let album = PHPhotoLibrary.shared().findAlbum(albumName: albumName) {
                PHPhotoLibrary.shared().saveVideo(urlData, album: album, completion: completion)
            } else {
                PHPhotoLibrary.shared().createAlbum(albumName: albumName, completion: { (collection) in
                    if let collection = collection {
                        PHPhotoLibrary.shared().saveVideo(urlData, album: collection, completion: completion)
                    } else {
                        completion?(nil)
                    }
                })
            }
        }
        
        if PHPhotoLibrary.authorizationStatus() == .authorized {
            save()
        } else {
            PHPhotoLibrary.requestAuthorization({ (status) in
                if status == .authorized {
                    save()
                } else {
                    completion?(nil)
                }
            })
        }
    }
    
    fileprivate func findAlbum(albumName: String) -> PHAssetCollection? {
        let fetchOptions = PHFetchOptions()
        fetchOptions.predicate = NSPredicate(format: "title = %@", albumName)
        let fetchResult : PHFetchResult = PHAssetCollection.fetchAssetCollections(with: .album, subtype: .any, options: fetchOptions)
        guard let photoAlbum = fetchResult.firstObject else {
            return nil
        }
        return photoAlbum
    }
    
    fileprivate func createAlbum(albumName: String, completion: @escaping (PHAssetCollection?)->()) {
        var albumPlaceholder: PHObjectPlaceholder?
        PHPhotoLibrary.shared().performChanges({
            let createAlbumRequest = PHAssetCollectionChangeRequest.creationRequestForAssetCollection(withTitle: albumName)
            albumPlaceholder = createAlbumRequest.placeholderForCreatedAssetCollection
        }, completionHandler: { success, error in
            if success {
                guard let placeholder = albumPlaceholder else {
                    completion(nil)
                    return
                }
                let fetchResult = PHAssetCollection.fetchAssetCollections(withLocalIdentifiers: [placeholder.localIdentifier], options: nil)
                guard let album = fetchResult.firstObject else {
                    completion(nil)
                    return
                }
                completion(album)
            } else {
                completion(nil)
            }
        })
    }
    
    fileprivate func saveImage(image: UIImage, album: PHAssetCollection, completion:((PHAsset?)->())? = nil) {
        var placeholder: PHObjectPlaceholder?
        PHPhotoLibrary.shared().performChanges({
            let createAssetRequest = PHAssetChangeRequest.creationRequestForAsset(from: image)
            guard let albumChangeRequest = PHAssetCollectionChangeRequest(for: album),
                let photoPlaceholder = createAssetRequest.placeholderForCreatedAsset else { return }
            placeholder = photoPlaceholder
            let fastEnumeration = NSArray(array: [photoPlaceholder] as [PHObjectPlaceholder])
            albumChangeRequest.addAssets(fastEnumeration)
        }, completionHandler: { success, error in
            guard let placeholder = placeholder else {
                completion?(nil)
                return
            }
            if success {
                let assets:PHFetchResult<PHAsset> =  PHAsset.fetchAssets(withLocalIdentifiers: [placeholder.localIdentifier], options: nil)
                let asset:PHAsset? = assets.firstObject
                completion?(asset)
            } else {
                completion?(nil)
            }
        })
    }
    
    fileprivate func saveVideo(_ urlData: NSData, album: PHAssetCollection, completion:((PHAsset?)->())? = nil) {
        let documentsPath = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)[0];
        let filePath="\(documentsPath)/tempFile.mp4"
        urlData.write(toFile: filePath, atomically: true)
        var placeholder: PHObjectPlaceholder?
        PHPhotoLibrary.shared().performChanges({
            let createAssetRequest = PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: URL(fileURLWithPath: filePath))
            guard let albumChangeRequest = PHAssetCollectionChangeRequest(for: album),
                let photoPlaceholder = createAssetRequest?.placeholderForCreatedAsset else { return }
            placeholder = photoPlaceholder
            let fastEnumeration = NSArray(array: [photoPlaceholder] as [PHObjectPlaceholder])
            albumChangeRequest.addAssets(fastEnumeration)
        }, completionHandler: { success, error in
            guard let placeholder = placeholder else {
                completion?(nil)
                return
            }
            if success {
                let assets:PHFetchResult<PHAsset> =  PHAsset.fetchAssets(withLocalIdentifiers: [placeholder.localIdentifier], options: nil)
                let asset:PHAsset? = assets.firstObject
                completion?(asset)
            } else if let error = error {
                print("Failure: %@", error.localizedDescription)
                completion?(nil)
            } else {
                print("Failure")
                completion?(nil)
            }
        })
    }
    
}

extension UIViewController {

    func showError(title: String = String.General.APP_NAME, message: String, okTitle: String? = String.General.ACCEPT, okHandler: (() -> Void)? = nil, action: (title: String, handler: (() -> Void)?)? = nil) {
        let alertController = UIAlertController(
            title: title,
            message: message,
            preferredStyle: .alert
        )
        alertController.addAction(UIAlertAction(title: okTitle, style: .cancel, handler: { _ in okHandler?() }))
        action.flatMap({ action in alertController.addAction(UIAlertAction(title: action.title, style: .default, handler: { _ in action.handler?() })) })
        present(alertController, animated: true)
    }

}

extension Data {
    var hexString: String {
        let hexString = map { String(format: "%02.2hhx", $0) }.joined()
        return hexString
    }
}


extension UIDevice {
    var isSimulator: Bool {
        return TARGET_OS_SIMULATOR != 0
    }
    
    var isJailBroken: Bool {
        get {
            if UIDevice.current.isSimulator { return false }
            if JailBrokenHelper.hasCydiaInstalled() { return true }
            if JailBrokenHelper.isContainsSuspiciousApps() { return true }
            if JailBrokenHelper.isSuspiciousSystemPathsExists() { return true }
            return JailBrokenHelper.canEditSystemFiles()
        }
    }
}

final class TrustKitCertificatePinning: NSObject, URLSessionDelegate {
    
    /// URLSession with configured certificate pinning
    lazy var session: URLSession = {
        String.Pinning.PUBLIC_KEY_HASHES.count > 0 ? URLSession(configuration: URLSessionConfiguration.ephemeral, delegate: self, delegateQueue: OperationQueue.main) : URLSession.shared
    }()
    
    let trustKitConfig: [String : Any] = {
        if String.Api.HOST == String.Webapp.HOST {
            return [
                kTSKPinnedDomains: [
                    String.Api.HOST: [
                        kTSKEnforcePinning: true,
                        kTSKIncludeSubdomains: true,
                        kTSKExpirationDate: "2020-10-09",
                        kTSKPublicKeyHashes: String.Pinning.PUBLIC_KEY_HASHES,
                    ],
                ]
            ] as [String: Any]
        } else {
            return [
                kTSKPinnedDomains: [
                    String.Api.HOST: [
                        kTSKEnforcePinning: true,
                        kTSKIncludeSubdomains: true,
                        kTSKExpirationDate: "2020-10-09",
                        kTSKPublicKeyHashes: String.Pinning.PUBLIC_KEY_HASHES,
                    ],
                    String.Webapp.HOST: [
                        kTSKEnforcePinning: true,
                        kTSKIncludeSubdomains: true,
                        kTSKExpirationDate: "2020-10-09",
                        kTSKPublicKeyHashes: String.Pinning.PUBLIC_KEY_HASHES,
                    ]
                ]
            ] as [String: Any]
        }
    }()
    
    override init() {
        if String.Pinning.PUBLIC_KEY_HASHES.count > 0 {
            TrustKit.initSharedInstance(withConfiguration: trustKitConfig)
        }
        super.init()
    }
    
    // MARK: TrustKit Pinning Reference
    
    func urlSession(_ session: URLSession,
                    didReceive challenge: URLAuthenticationChallenge,
                    completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
                                                
        if TrustKit.sharedInstance().pinningValidator.handle(challenge, completionHandler: completionHandler) == false {
            // TrustKit did not handle this challenge: perhaps it was not for server trust
            // or the domain was not pinned. Fall back to the default behavior
            completionHandler(.performDefaultHandling, nil)
        }
    }
}
