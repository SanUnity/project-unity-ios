/*
 * Copyright (c) 2020 Ubique Innovation AG <https://www.ubique.ch>
 *
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at https://mozilla.org/MPL/2.0/.
 *
 * SPDX-License-Identifier: MPL-2.0
 */

import Foundation
import Firenbase

/// Keychain Errors
enum KeychainError: Error {
    /// Object could not be encoded
    case encodingError(_ error: Error)
    /// Object could not be decoded
    case decodingError(_ error: Error)
    /// A error happend while storing the object
    case storingError(_ status: OSStatus)
    /// The object was not found
    case notFound
    /// a Access error happend
    case cannotAccess(_ status: OSStatus)
    /// a deletion error happend
    case cannotDelete(_ status: OSStatus)

    var localizedDescription: String {
        switch self {
        case let .encodingError(error):
            return "encodingError: \(error.localizedDescription)"
        case let .decodingError(error):
            return "decodingError: \(error.localizedDescription)"
        case let .storingError(status):
            return "storingError OSStatus: \(status)"
        case .notFound:
            return "notFound"
        case let .cannotAccess(status):
            return "cannotAccess OSStatus: \(status)"
        case let .cannotDelete(status):
            return "cannotDelete OSStatus: \(status)"
        }
    }
}

/// This is struct is needed to defer the type of a key when getting a object
struct KeychainKey<Object: Codable> {
    let key: String
    init(key: String) {
        self.key = key
    }
}

protocol KeychainProtocol {
    /// Get a object from the keychain
    /// - Parameter key: a key object with the type
    /// - Returns: a result which either contain the error or the object
    func get<T>(for key: KeychainKey<T>) -> Result<T, KeychainError> where T: Decodable, T: Encodable

    /// Set a object to the keychain
    /// - Parameters:
    ///   - object: the object to set
    ///   - key: the keyobject to use
    /// - Returns: a result which either is successful or contains the error
    @discardableResult
    func set<T>(_ object: T, for key: KeychainKey<T>) -> Result<Void, KeychainError> where T: Decodable, T: Encodable

    /// Deletes a object from the keychain
    /// - Parameter key: the key to delete
    /// - Returns: a result which either is successful or contains the error
    @discardableResult
    func delete<T>(for key: KeychainKey<T>) -> Result<Void, KeychainError> where T: Decodable, T: Encodable
}

/// A wrapper class for the keychain
class Keychain: KeychainProtocol {
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    /// Get a object from the keychain
    /// - Parameter key: a key object with the type
    /// - Returns: a result which either contain the error or the object
    public func get<T: Codable>(for key: KeychainKey<T>) -> Result<T, KeychainError> {
        var query = self.query(for: key)
        query[kSecReturnData] = kCFBooleanTrue
        query[kSecMatchLimit] = kSecMatchLimitOne

        var item: CFTypeRef?
        let status: OSStatus = SecItemCopyMatching(query as CFDictionary, &item)

        switch status {
        case errSecItemNotFound:
            return .failure(.notFound)
        case noErr:
            guard let item = item as? Data else {
                // fatalError("Keychain not returning Data")
                Analytics.logEvent("keychain_not_returning_data", parameters: nil)
                return .failure(.cannotAccess(status))
            }
            do {
                let object = try JSONDecoder().decode(T.self, from: item)
                return .success(object)
            } catch {
                return .failure(.decodingError(error))
            }
        default:
            return .failure(.cannotAccess(status))
        }
    }

    /// Set a object to the keychain
    /// - Parameters:
    ///   - object: the object to set
    ///   - key: the keyobject to use
    /// - Returns: a result which either is successful or contains the error
    @discardableResult
    public func set<T: Codable>(_ object: T, for key: KeychainKey<T>) -> Result<Void, KeychainError> {
        let data: Data
        do {
            data = try encoder.encode(object)
        } catch {
            return .failure(.encodingError(error))
        }
        var query = self.query(for: key)
        query[kSecValueData] = data

        var status: OSStatus = SecItemCopyMatching(query as CFDictionary, nil)

        switch status {
        case errSecSuccess:
            // Item exists so we can update it
            let attributes = [kSecValueData: data]
            status = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
            if status != errSecSuccess {
                return .failure(.storingError(status))
            } else {
                return .success(())
            }
        case errSecItemNotFound:
            // First time setting item
            status = SecItemAdd(query as CFDictionary, nil)

            if status != noErr {
                return .failure(.storingError(status))
            }
            return .success(())
        default:
            return .failure(.storingError(status))
        }
    }

    /// Deletes a object from the keychain
    /// - Parameter key: the key to delete
    /// - Returns: a result which either is successful or contains the error
    @discardableResult
    public func delete<T>(for key: KeychainKey<T>) -> Result<Void, KeychainError> {
        let query = self.query(for: key)

        let status: OSStatus = SecItemDelete(query as CFDictionary)
        switch status {
        case noErr, errSecItemNotFound:
            return .success(())
        default:
            return .failure(.cannotDelete(status))
        }
    }

    /// helpermethod to construct the keychain query
    /// - Parameter key: key to use
    /// - Returns: the keychain query
    private func query<T>(for key: KeychainKey<T>) -> [CFString: Any] {
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword as String,
            kSecAttrAccount: key.key,
            kSecAttrAccessible: kSecAttrAccessibleAfterFirstUnlock,
        ]
        return query
    }
}
