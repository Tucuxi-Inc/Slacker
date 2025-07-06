//
//  SlackerConfig.swift
//  Slacker
//
//  Created by Kevin Keller -- Tucuxi, Inc. July 2025
//

import Foundation
import Security
import Defaults

@MainActor
class SlackerConfig: ObservableObject {
    static let shared = SlackerConfig()
    
    private init() {}
    
    // MARK: - Public Configuration Methods
    
    /// Get the configured Zapier webhook URL
    func getZapierWebhookURL() -> String? {
        // First check if URL is configured in Defaults
        guard Defaults[.zapierWebhookURLConfigured] else {
            return nil
        }
        
        // Try to get from keychain first (most secure)
        if let keychainURL = getFromKeychain(service: "SlackSassin", account: "zapierWebhook") {
            return keychainURL
        }
        
        // Fallback to Defaults if keychain fails
        let defaultsURL = Defaults[.zapierWebhookURL]
        return defaultsURL.isEmpty ? nil : defaultsURL
    }
    
    /// Set the Zapier webhook URL securely
    func setZapierWebhookURL(_ url: String) throws {
        guard isValidWebhookURL(url) else {
            throw ConfigError.invalidURL("Invalid webhook URL format")
        }
        
        // Store in keychain (preferred)
        if storeInKeychain(service: "SlackSassin", account: "zapierWebhook", value: url) {
            // Clear from Defaults for security
            Defaults[.zapierWebhookURL] = ""
            Defaults[.zapierWebhookURLConfigured] = true
        } else {
            // Fallback to Defaults if keychain fails
            Defaults[.zapierWebhookURL] = url
            Defaults[.zapierWebhookURLConfigured] = true
        }
    }
    
    /// Get the configured NGrok static URL
    func getNgrokStaticURL() -> String? {
        let url = Defaults[.ngrokStaticURL]
        return url.isEmpty ? nil : url
    }
    
    /// Set the NGrok static URL
    func setNgrokStaticURL(_ url: String) throws {
        guard isValidNgrokURL(url) else {
            throw ConfigError.invalidURL("Invalid NGrok URL format")
        }
        
        Defaults[.ngrokStaticURL] = url
    }
    
    /// Get the webhook server port
    func getWebhookServerPort() -> Int {
        return Defaults[.webhookServerPort]
    }
    
    /// Set the webhook server port
    func setWebhookServerPort(_ port: Int) throws {
        guard (1024...65535).contains(port) else {
            throw ConfigError.invalidPort("Port must be between 1024 and 65535")
        }
        
        Defaults[.webhookServerPort] = port
    }
    
    /// Check if SlackSassin is properly configured
    func isConfigured() -> Bool {
        return getZapierWebhookURL() != nil
    }
    
    /// Clear all sensitive configuration
    func clearConfiguration() {
        deleteFromKeychain(service: "SlackSassin", account: "zapierWebhook")
        Defaults[.zapierWebhookURL] = ""
        Defaults[.zapierWebhookURLConfigured] = false
        Defaults[.ngrokStaticURL] = ""
        Defaults[.webhookServerPort] = 8080
    }
    
    // MARK: - Validation Methods
    
    private func isValidWebhookURL(_ url: String) -> Bool {
        guard let urlObj = URL(string: url) else { return false }
        return urlObj.scheme == "https" && 
               (urlObj.host?.contains("zapier.com") == true || 
                urlObj.host?.contains("hooks.zapier.com") == true)
    }
    
    private func isValidNgrokURL(_ url: String) -> Bool {
        // Allow any reasonable hostname/domain format for NGrok
        let pattern = "^[a-zA-Z0-9][a-zA-Z0-9-]*[a-zA-Z0-9]*\\.(ngrok-free\\.app|ngrok\\.io|ngrok\\.app)$"
        let regex = try? NSRegularExpression(pattern: pattern)
        let range = NSRange(location: 0, length: url.utf16.count)
        return regex?.firstMatch(in: url, range: range) != nil
    }
    
    // MARK: - Keychain Methods
    
    private func storeInKeychain(service: String, account: String, value: String) -> Bool {
        guard let data = value.data(using: .utf8) else { return false }
        
        // Delete any existing item first
        deleteFromKeychain(service: service, account: account)
        
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]
        
        let status = SecItemAdd(query as CFDictionary, nil)
        return status == errSecSuccess
    }
    
    private func getFromKeychain(service: String, account: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        var dataTypeRef: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &dataTypeRef)
        
        guard status == errSecSuccess,
              let data = dataTypeRef as? Data,
              let value = String(data: data, encoding: .utf8) else {
            return nil
        }
        
        return value
    }
    
    private func deleteFromKeychain(service: String, account: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        
        SecItemDelete(query as CFDictionary)
    }
}

// MARK: - Error Types
enum ConfigError: LocalizedError {
    case invalidURL(String)
    case invalidPort(String)
    case keychainError(String)
    
    var errorDescription: String? {
        switch self {
        case .invalidURL(let message):
            return "Invalid URL: \(message)"
        case .invalidPort(let message):
            return "Invalid Port: \(message)"
        case .keychainError(let message):
            return "Keychain Error: \(message)"
        }
    }
} 