//
//  KeychainService.swift
//  ScreenTranslate
//
//  Secure storage for API keys and credentials using macOS Keychain
//

import Foundation
import Security
import os.log

// MARK: - Keychain Service

/// Actor-based service for secure credential storage using macOS Keychain
actor KeychainService {
    /// Shared singleton instance
    static let shared = KeychainService()

    /// Service identifier for Keychain items
    private let service = "com.screentranslate.credentials"

    /// Logger instance
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "ScreenTranslate", category: "KeychainService")

    private init() {}

    // MARK: - Public API

    /// Save credentials for a translation engine
    /// - Parameters:
    ///   - apiKey: The API key to store
    ///   - engine: The engine type these credentials are for
    ///   - additionalData: Optional additional data (e.g., appID for Baidu)
    func saveCredentials(
        apiKey: String,
        for engine: TranslationEngineType,
        additionalData: [String: String]? = nil
    ) throws {
        let credentials = StoredCredentials(
            apiKey: apiKey,
            appID: additionalData?["appID"],
            additional: additionalData
        )

        guard let encodedData = try? JSONEncoder().encode(credentials) else {
            throw KeychainError.invalidData
        }

        // Try to update existing item first
        if hasCredentials(for: engine) {
            try deleteCredentials(for: engine)
        }

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: engine.rawValue,
            kSecValueData as String: encodedData,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlocked
        ]

        let status = SecItemAdd(query as CFDictionary, nil)

        guard status == errSecSuccess else {
            logger.error("Failed to save credentials for \(engine.rawValue): \(status)")
            throw KeychainError.unexpectedStatus(status)
        }

        logger.info("Saved credentials for \(engine.rawValue)")
    }

    /// Retrieve stored credentials for an engine
    /// - Parameter engine: The engine type to get credentials for
    /// - Returns: The stored credentials, or nil if not found
    func getCredentials(for engine: TranslationEngineType) throws -> StoredCredentials? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: engine.rawValue,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess else {
            if status == errSecItemNotFound {
                logger.debug("No credentials found for \(engine.rawValue)")
                return nil
            }
            logger.error("Failed to retrieve credentials for \(engine.rawValue): \(status)")
            throw KeychainError.unexpectedStatus(status)
        }

        guard let data = result as? Data else {
            throw KeychainError.invalidData
        }

        let credentials = try JSONDecoder().decode(StoredCredentials.self, from: data)
        logger.debug("Retrieved credentials for \(engine.rawValue)")
        return credentials
    }

    /// Delete stored credentials for an engine
    /// - Parameter engine: The engine type to delete credentials for
    func deleteCredentials(for engine: TranslationEngineType) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: engine.rawValue
        ]

        let status = SecItemDelete(query as CFDictionary)

        guard status == errSecSuccess || status == errSecItemNotFound else {
            logger.error("Failed to delete credentials for \(engine.rawValue): \(status)")
            throw KeychainError.unexpectedStatus(status)
        }

        logger.info("Deleted credentials for \(engine.rawValue)")
    }

    /// Check if credentials exist for an engine
    /// - Parameter engine: The engine type to check
    /// - Returns: True if credentials exist
    func hasCredentials(for engine: TranslationEngineType) -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: engine.rawValue,
            kSecReturnData as String: false,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        return status == errSecSuccess
    }

    /// Get only the API key for an engine (convenience method)
    /// - Parameter engine: The engine type
    /// - Returns: The API key, or nil if not found
    func getAPIKey(for engine: TranslationEngineType) -> String? {
        do {
            return try getCredentials(for: engine)?.apiKey
        } catch {
            logger.error("Error getting API key for \(engine.rawValue): \(error.localizedDescription)")
            return nil
        }
    }

    // MARK: - Compatible Engine Methods (String-based identifiers)

    /// Save credentials for a compatible engine instance
    /// - Parameters:
    ///   - apiKey: The API key to store
    ///   - compatibleId: The compatible engine identifier (e.g., "custom:0", "custom:1")
    func saveCredentials(apiKey: String, forCompatibleId compatibleId: String) throws {
        let credentials = StoredCredentials(apiKey: apiKey)

        guard let encodedData = try? JSONEncoder().encode(credentials) else {
            throw KeychainError.invalidData
        }

        // Try to update existing item first
        if hasCredentials(forCompatibleId: compatibleId) {
            try deleteCredentials(forCompatibleId: compatibleId)
        }

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: compatibleId,
            kSecValueData as String: encodedData,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlocked
        ]

        let status = SecItemAdd(query as CFDictionary, nil)

        guard status == errSecSuccess else {
            logger.error("Failed to save credentials for \(compatibleId): \(status)")
            throw KeychainError.unexpectedStatus(status)
        }

        logger.info("Saved credentials for compatible engine \(compatibleId)")
    }

    /// Retrieve stored credentials for a compatible engine instance
    /// - Parameter compatibleId: The compatible engine identifier
    /// - Returns: The stored credentials, or nil if not found
    func getCredentials(forCompatibleId compatibleId: String) throws -> StoredCredentials? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: compatibleId,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess else {
            if status == errSecItemNotFound {
                logger.debug("No credentials found for \(compatibleId)")
                return nil
            }
            logger.error("Failed to retrieve credentials for \(compatibleId): \(status)")
            throw KeychainError.unexpectedStatus(status)
        }

        guard let data = result as? Data else {
            throw KeychainError.invalidData
        }

        let credentials = try JSONDecoder().decode(StoredCredentials.self, from: data)
        logger.debug("Retrieved credentials for \(compatibleId)")
        return credentials
    }

    /// Check if credentials exist for a compatible engine instance
    /// - Parameter compatibleId: The compatible engine identifier
    /// - Returns: True if credentials exist
    func hasCredentials(forCompatibleId compatibleId: String) -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: compatibleId,
            kSecReturnData as String: false,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        return status == errSecSuccess
    }

    /// Delete stored credentials for a compatible engine instance
    /// - Parameter compatibleId: The compatible engine identifier
    func deleteCredentials(forCompatibleId compatibleId: String) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: compatibleId
        ]

        let status = SecItemDelete(query as CFDictionary)

        guard status == errSecSuccess || status == errSecItemNotFound else {
            logger.error("Failed to delete credentials for \(compatibleId): \(status)")
            throw KeychainError.unexpectedStatus(status)
        }

        logger.info("Deleted credentials for compatible engine \(compatibleId)")
    }

    /// Delete all stored credentials
    func deleteAllCredentials() throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service
        ]

        let status = SecItemDelete(query as CFDictionary)

        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError.unexpectedStatus(status)
        }

        logger.info("Deleted all credentials")
    }
}

// MARK: - Stored Credentials

/// Structure for stored credentials
struct StoredCredentials: Codable, Sendable {
    /// Primary API key
    let apiKey: String

    /// Application ID (required for Baidu)
    let appID: String?

    /// Additional data fields
    let additional: [String: String]?

    init(apiKey: String, appID: String? = nil, additional: [String: String]? = nil) {
        self.apiKey = apiKey
        self.appID = appID
        self.additional = additional
    }
}

// MARK: - Keychain Error

/// Errors that can occur during Keychain operations
enum KeychainError: LocalizedError, Sendable {
    /// The requested item was not found in Keychain
    case itemNotFound

    /// An item with the same identifier already exists
    case duplicateItem

    /// The data format is invalid or corrupted
    case invalidData

    /// An unexpected OS status was returned
    case unexpectedStatus(OSStatus)

    var errorDescription: String? {
        switch self {
        case .itemNotFound:
            return NSLocalizedString(
                "keychain.error.item_not_found",
                comment: "Credentials not found in Keychain"
            )
        case .duplicateItem:
            return NSLocalizedString(
                "keychain.error.duplicate_item",
                comment: "Credentials already exist in Keychain"
            )
        case .invalidData:
            return NSLocalizedString(
                "keychain.error.invalid_data",
                comment: "Invalid credential data format"
            )
        case .unexpectedStatus(let status):
            return NSLocalizedString(
                "keychain.error.unexpected_status",
                comment: "Keychain operation failed with status: \(status)"
            ) + " (\(status))"
        }
    }

    var recoverySuggestion: String? {
        switch self {
        case .itemNotFound:
            return NSLocalizedString(
                "keychain.error.item_not_found.recovery",
                comment: "Please configure your API credentials in Settings"
            )
        case .duplicateItem:
            return NSLocalizedString(
                "keychain.error.duplicate_item.recovery",
                comment: "Try deleting existing credentials first"
            )
        case .invalidData:
            return NSLocalizedString(
                "keychain.error.invalid_data.recovery",
                comment: "Try re-entering your credentials"
            )
        case .unexpectedStatus:
            return NSLocalizedString(
                "keychain.error.unexpected_status.recovery",
                comment: "Please check your Keychain access permissions"
            )
        }
    }
}

// MARK: - OSStatus Extension

extension OSStatus {
    /// Convert OSStatus to NSError for better error messages
    var asNSError: NSError {
        let domain = NSOSStatusErrorDomain
        let code = Int(self)
        let description = SecCopyErrorMessageString(self, nil) as String?
        return NSError(
            domain: domain,
            code: code,
            userInfo: [
                NSLocalizedDescriptionKey: description ?? "Unknown keychain error"
            ]
        )
    }
}
