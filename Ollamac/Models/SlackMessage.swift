//
//  SlackMessage.swift
//  Slacker
//
//  Created by SlackSassin Integration
//

import Foundation
import SwiftData

@Model
final class SlackMessage: Identifiable {
    @Attribute(.unique) var id: UUID = UUID()
    
    // Slack Data
    var text: String
    var channelId: String
    var channelName: String?
    var userId: String
    var userName: String?
    var threadTS: String?
    var slackTimestamp: String
    
    // Processing Data
    var status: MessageStatus = MessageStatus.pending
    var aiResponse: String?
    var editedResponse: String?
    var useForAutoResponse: Bool = false
    var error: String?
    
    // Metadata
    private var matchedKeywordsString: String = ""
    var messageType: MessageType = MessageType.mention
    
    // Computed property to provide array interface for matchedKeywords
    var matchedKeywords: [String] {
        get {
            if matchedKeywordsString.isEmpty {
                return []
            }
            return matchedKeywordsString.components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespaces) }
        }
        set {
            matchedKeywordsString = newValue.joined(separator: ", ")
        }
    }
    var receivedAt: Date = Date.now
    var processedAt: Date?
    var sentAt: Date?
    
    init(text: String, channelId: String, userId: String, slackTimestamp: String) {
        self.text = text
        self.channelId = channelId
        self.userId = userId
        self.slackTimestamp = slackTimestamp
    }
    
    // Initialize from Zapier webhook payload
    init(from zapierPayload: ZapierPayload) {
        self.text = zapierPayload.text
        self.channelId = zapierPayload.channel.id
        self.channelName = zapierPayload.channel.name
        self.userId = zapierPayload.user.id
        self.userName = zapierPayload.user.realName.isEmpty ? zapierPayload.user.name : zapierPayload.user.realName
        self.threadTS = nil // Can be enhanced later for threaded messages
        self.slackTimestamp = zapierPayload.ts
        self.messageType = zapierPayload.channel.id.starts(with: "D") ? MessageType.dm : MessageType.mention
        self.matchedKeywords = ["mention"] // Default, can be enhanced
    }
}

// MARK: - Enums
extension SlackMessage {
    enum MessageStatus: String, CaseIterable, Codable {
        case pending = "pending"
        case processing = "processing"
        case completed = "completed"
        case sent = "sent"
        case failed = "error"
        case dismissed = "dismissed"
    }
    
    enum MessageType: String, CaseIterable, Codable {
        case mention = "mention"
        case keyword = "keyword"
        case dm = "dm"
    }
}

// MARK: - Webhook payload structure for Zapier integration
struct ZapierPayload: Codable {
    let channel: ZapierChannel
    let user: ZapierUser
    let ts: String
    let text: String
    let permalink: String
    let team: ZapierTeam
    let rawText: String
    let tsTime: String
    
    private enum CodingKeys: String, CodingKey {
        case channel, user, ts, text, permalink, team
        case rawText = "raw_text"
        case tsTime = "ts_time"
    }
}

struct ZapierChannel: Codable {
    let id: String
    let name: String
}

struct ZapierUser: Codable {
    let id: String
    let name: String
    let isBot: Bool
    let realName: String
    let isRestricted: Bool
    let isUltraRestricted: Bool
    let profile: ZapierUserProfile
    
    private enum CodingKeys: String, CodingKey {
        case id, name, profile
        case isBot = "is_bot"
        case realName = "real_name"
        case isRestricted = "is_restricted"
        case isUltraRestricted = "is_ultra_restricted"
    }
}

struct ZapierUserProfile: Codable {
    let firstName: String
    let lastName: String
    let email: String
    let phone: String
    let smallImageUrl: String
    let mediumImageUrl: String
    let largeImageUrl: String
    
    private enum CodingKeys: String, CodingKey {
        case email, phone
        case firstName = "first_name"
        case lastName = "last_name"
        case smallImageUrl = "small_image_url"
        case mediumImageUrl = "medium_image_url"
        case largeImageUrl = "large_image_url"
    }
}

struct ZapierTeam: Codable {
    let id: String
    let name: String
    let url: String
    let domain: String
    let emailDomain: String
    let icon: ZapierTeamIcon
    let avatarBaseUrl: String
    let isVerified: Bool
    let lobSalesHomeEnabled: Bool
    let isSfdcAutoSlack: Bool
    
    private enum CodingKeys: String, CodingKey {
        case id, name, url, domain, icon
        case emailDomain = "email_domain"
        case avatarBaseUrl = "avatar_base_url"
        case isVerified = "is_verified"
        case lobSalesHomeEnabled = "lob_sales_home_enabled"
        case isSfdcAutoSlack = "is_sfdc_auto_slack"
    }
}

struct ZapierTeamIcon: Codable {
    let smallImageUrl: String
    let mediumImageUrl: String
    let largeImageUrl: String
    
    private enum CodingKeys: String, CodingKey {
        case smallImageUrl = "small_image_url"
        case mediumImageUrl = "medium_image_url"
        case largeImageUrl = "large_image_url"
    }
}

// MARK: - Response payload for sending back to Zapier
struct ZapierResponsePayload: Codable {
    let messageId: String
    let responseText: String
    let channel: String
    let threadId: String?
    let originalMessageText: String
    let userIdMention: String
    let timestamp: Date
    
    private enum CodingKeys: String, CodingKey {
        case messageId = "message_id"
        case responseText = "response_text"
        case channel
        case threadId = "thread_id"
        case originalMessageText = "original_message_text"
        case userIdMention = "user_id_mention"
        case timestamp
    }
    
    init(messageId: String, responseText: String, channel: String, threadId: String? = nil, originalMessageText: String, userIdMention: String, timestamp: Date = Date()) {
        self.messageId = messageId
        self.responseText = responseText
        self.channel = channel
        self.threadId = threadId
        self.originalMessageText = originalMessageText
        self.userIdMention = userIdMention
        self.timestamp = timestamp
    }
}

struct WebhookResponse: Codable {
    let replyText: String
    let channelId: String
    let threadTS: String?
    let status: String
} 