//
//  KeychainHelper.swift
//  StoneLifting
//
//  Created by Max Rogers on 1/4/26.
//

import Foundation
import Security

// MARK: - Keychain Helper

/// Secure storage wrapper for the iOS Keychain
final class KeychainHelper {
    // MARK: - Properties

    static let shared = KeychainHelper()
    private let logger = AppLogger()

    private init() {}

    // MARK: - Public Methods

    /// Save a string value to the Keychain
    /// - Parameters:
    ///   - value: The string value to store
    ///   - key: The key to associate with the value
    /// - Returns: True if successful, false otherwise
    @discardableResult
    func save(_ value: String, forKey key: String) -> Bool {
        guard let data = value.data(using: .utf8) else {
            logger.error("Failed to encode string for Keychain storage")
            return false
        }

        return save(data, forKey: key)
    }

    /// Save data to the Keychain
    /// - Parameters:
    ///   - data: The data to store
    ///   - key: The key to associate with the data
    /// - Returns: True if successful, false otherwise
    @discardableResult
    func save(_ data: Data, forKey key: String) -> Bool {
        // Delete any existing item
        delete(forKey: key)

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock
        ]

        let status = SecItemAdd(query as CFDictionary, nil)

        if status == errSecSuccess {
            logger.debug("Successfully saved item to Keychain for key: \(key)")
            return true
        } else {
            logger.error("Failed to save item to Keychain for key: \(key), status: \(status)")
            return false
        }
    }

    /// Retrieve a string value from the Keychain
    /// - Parameter key: The key associated with the value
    /// - Returns: The stored string value, or nil if not found
    func getString(forKey key: String) -> String? {
        guard let data = getData(forKey: key) else {
            return nil
        }

        return String(data: data, encoding: .utf8)
    }

    /// Retrieve data from the Keychain
    /// - Parameter key: The key associated with the data
    /// - Returns: The stored data, or nil if not found
    func getData(forKey key: String) -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        if status == errSecSuccess {
            logger.debug("Successfully retrieved item from Keychain for key: \(key)")
            return result as? Data
        } else if status == errSecItemNotFound {
            logger.debug("Item not found in Keychain for key: \(key)")
            return nil
        } else {
            logger.error("Failed to retrieve item from Keychain for key: \(key), status: \(status)")
            return nil
        }
    }

    /// Delete an item from the Keychain
    /// - Parameter key: The key associated with the item to delete
    /// - Returns: True if successful or item doesn't exist, false on error
    @discardableResult
    func delete(forKey key: String) -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key
        ]

        let status = SecItemDelete(query as CFDictionary)

        if status == errSecSuccess || status == errSecItemNotFound {
            logger.debug("Successfully deleted item from Keychain for key: \(key)")
            return true
        } else {
            logger.error("Failed to delete item from Keychain for key: \(key), status: \(status)")
            return false
        }
    }

    /// Delete all items stored by this app from the Keychain
    /// - Returns: True if successful, false otherwise
    @discardableResult
    func deleteAll() -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword
        ]

        let status = SecItemDelete(query as CFDictionary)

        if status == errSecSuccess || status == errSecItemNotFound {
            logger.info("Successfully deleted all items from Keychain")
            return true
        } else {
            logger.error("Failed to delete all items from Keychain, status: \(status)")
            return false
        }
    }
}

// MARK: - Keychain Keys

/// Constants for Keychain storage keys
enum KeychainKeys {
    static let jwtToken = "com.marfodub.StoneAtlas.jwtToken"
}
