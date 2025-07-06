//
//  Defaults+Keys.swift
//
//
//  Created by Kevin Hermawan on 13/07/24.
//  Modified by Kevin Keller -- Tucuxi, Inc. 07/2025
//

import Defaults
import Foundation
import AppKit.NSFont

extension Defaults.Keys {
    static let defaultChatName = Key<String>("defaultChatName", default: "New Chat")
    static let defaultModel = Key<String>("defaultModel", default: "granite3.3:2b")
    static let defaultHost = Key<String>("defaultHost", default: "http://localhost:11434")
    static let fontSize = Key<Double>("fontSize", default: NSFont.systemFontSize)
    static let defaultSystemPrompt = Key<String>("defaultSystemPrompt", default: "You're Slacker, a helpful assistant.")
    static let defaultTemperature = Key<Double>("defaultTemperature", default: 0.7)
    static let defaultTopP = Key<Double>("defaultTopP", default: 0.9)
    static let defaultTopK = Key<Int>("defaultTopK", default: 40)
    
    // SlackOff-specific settings
    static let slackOffModel = Key<String>("slackOffModel", default: "granite3.3:2b")
    static let slackOffSystemPrompt = Key<String>("slackOffSystemPrompt", default: "You're SlackSassin, a helpful assistant that responds to Slack messages professionally and concisely. Keep responses brief and actionable.")
    static let slackOffAutoResponse = Key<Bool>("slackOffAutoResponse", default: true)
    static let slackOffTemperature = Key<Double>("slackOffTemperature", default: 0.7)
    static let slackOffTopP = Key<Double>("slackOffTopP", default: 0.9)
    static let slackOffTopK = Key<Int>("slackOffTopK", default: 40)
    
    static let experimentalCodeHighlighting = Key<Bool>("experimentalCodeHighlighting", default: false)
    
    // MARK: - SlackSassin Configuration
    static let zapierWebhookURL = Key<String>("zapierWebhookURL", default: "")
    static let ngrokStaticURL = Key<String>("ngrokStaticURL", default: "")
    static let webhookServerPort = Key<Int>("webhookServerPort", default: 8080)
    
    // Security: Mark sensitive configuration
    static let zapierWebhookURLConfigured = Key<Bool>("zapierWebhookURLConfigured", default: false)
}
