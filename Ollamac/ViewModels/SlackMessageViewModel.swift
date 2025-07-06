//
//  SlackMessageViewModel.swift
//  Slacker
//
//  Created by Kevin Keller -- Tucuxi, Inc. July 2025
//

import Foundation
import SwiftData
import SwiftUI
import Defaults
import OllamaKit

@Observable
final class SlackMessageViewModel {
    private let modelContext: ModelContext
    
    // Current state
    var pendingMessages: [SlackMessage] = []
    var processingMessages: [SlackMessage] = []
    var completedMessages: [SlackMessage] = []
    var allMessages: [SlackMessage] = []
    
    // Statistics
    var totalMessages: Int = 0
    var pendingCount: Int = 0
    var processingCount: Int = 0
    var completedCount: Int = 0
    
    init(modelContext: ModelContext) {
        self.modelContext = modelContext
        loadMessages()
        setupNotifications()
    }
    
    // MARK: - Data Loading
    
    func loadMessages() {
        do {
            let fetchRequest = FetchDescriptor<SlackMessage>(
                sortBy: [SortDescriptor(\SlackMessage.receivedAt, order: .reverse)]
            )
            allMessages = try modelContext.fetch(fetchRequest)
            
            // Update categorized arrays
            updateCategorizedMessages()
            updateStatistics()
            
        } catch {
            print("❌ Failed to load Slack messages: \(error)")
        }
    }
    
    func loadPendingMessages() {
        do {
            let fetchRequest = FetchDescriptor<SlackMessage>(
                predicate: #Predicate { $0.status.rawValue == "pending" },
                sortBy: [SortDescriptor(\SlackMessage.receivedAt, order: .reverse)]
            )
            pendingMessages = try modelContext.fetch(fetchRequest)
            
        } catch {
            print("❌ Failed to load pending messages: \(error)")
        }
    }
    
    func loadProcessingMessages() {
        do {
            let fetchRequest = FetchDescriptor<SlackMessage>(
                predicate: #Predicate { $0.status.rawValue == "processing" },
                sortBy: [SortDescriptor(\SlackMessage.receivedAt, order: .reverse)]
            )
            processingMessages = try modelContext.fetch(fetchRequest)
            
        } catch {
            print("❌ Failed to load processing messages: \(error)")
        }
    }
    
    func loadCompletedMessages() {
        do {
            let fetchRequest = FetchDescriptor<SlackMessage>(
                predicate: #Predicate { $0.status.rawValue == "completed" || $0.status.rawValue == "sent" },
                sortBy: [SortDescriptor(\SlackMessage.receivedAt, order: .reverse)]
            )
            completedMessages = try modelContext.fetch(fetchRequest)
            
        } catch {
            print("❌ Failed to load completed messages: \(error)")
        }
    }
    
    // MARK: - Message Operations
    
    func updateMessageStatus(_ message: SlackMessage, to status: SlackMessage.MessageStatus) {
        do {
            message.status = status
            
            if status == SlackMessage.MessageStatus.processing {
                message.processedAt = Date()
            } else if status == SlackMessage.MessageStatus.sent {
                message.sentAt = Date()
            }
            
            try modelContext.save()
            loadMessages() // Refresh all data
            
        } catch {
            print("❌ Failed to update message status: \(error)")
        }
    }
    
    func setAIResponse(_ message: SlackMessage, response: String) {
        do {
            message.aiResponse = response
            message.status = SlackMessage.MessageStatus.completed
            message.processedAt = Date()
            
            try modelContext.save()
            loadMessages() // Refresh all data
            
        } catch {
            print("❌ Failed to set AI response: \(error)")
        }
    }
    
    func editResponse(_ message: SlackMessage, editedResponse: String) {
        do {
            message.editedResponse = editedResponse
            try modelContext.save()
            
        } catch {
            print("❌ Failed to edit response: \(error)")
        }
    }
    
    func dismissMessage(_ message: SlackMessage) {
        do {
            message.status = SlackMessage.MessageStatus.dismissed
            try modelContext.save()
            loadMessages() // Refresh all data
            
        } catch {
            print("❌ Failed to dismiss message: \(error)")
        }
    }
    
    func deleteMessage(_ message: SlackMessage) {
        do {
            modelContext.delete(message)
            try modelContext.save()
            loadMessages() // Refresh all data
            
        } catch {
            print("❌ Failed to delete message: \(error)")
        }
    }
    
    // MARK: - Batch Operations
    
    func dismissAllPendingMessages() {
        do {
            for message in pendingMessages {
                message.status = SlackMessage.MessageStatus.dismissed
            }
            try modelContext.save()
            loadMessages() // Refresh all data
            
        } catch {
            print("❌ Failed to dismiss all pending messages: \(error)")
        }
    }
    
    func retryErrorMessages() {
        do {
            let fetchRequest = FetchDescriptor<SlackMessage>(
                predicate: #Predicate { $0.status.rawValue == "error" }
            )
            let errorMessages = try modelContext.fetch(fetchRequest)
            
            for message in errorMessages {
                message.status = SlackMessage.MessageStatus.pending
                message.error = nil
            }
            
            try modelContext.save()
            loadMessages() // Refresh all data
            
        } catch {
            print("❌ Failed to retry error messages: \(error)")
        }
    }
    
    // MARK: - Helper Methods
    
    private func updateCategorizedMessages() {
        pendingMessages = allMessages.filter { $0.status == SlackMessage.MessageStatus.pending }
        processingMessages = allMessages.filter { $0.status == SlackMessage.MessageStatus.processing }
        completedMessages = allMessages.filter { $0.status == SlackMessage.MessageStatus.completed || $0.status == SlackMessage.MessageStatus.sent }
    }
    
    private func updateStatistics() {
        totalMessages = allMessages.count
        pendingCount = pendingMessages.count
        processingCount = processingMessages.count
        completedCount = completedMessages.count
    }
    
    // MARK: - Notification Handling
    
    private func setupNotifications() {
        NotificationCenter.default.addObserver(
            forName: .newSlackMessageReceived,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            self?.loadMessages()
            
            // Auto-generate response if enabled
            if Defaults[.slackOffAutoResponse] {
                if let message = notification.object as? SlackMessage {
                    print("🤖 Auto-generating response for message: \(message.text)")
                    Task {
                        await self?.autoGenerateResponse(for: message)
                    }
                }
            }
        }
        
        NotificationCenter.default.addObserver(
            forName: .slackMessageStatusUpdated,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.loadMessages()
        }
    }
    
    // MARK: - Utilities
    
    func getMessage(by id: UUID) -> SlackMessage? {
        return allMessages.first { $0.id == id }
    }
    
    func getResponseText(for message: SlackMessage) -> String {
        return message.editedResponse ?? message.aiResponse ?? ""
    }
    
    func canSendResponse(for message: SlackMessage) -> Bool {
        return message.status == SlackMessage.MessageStatus.completed && !getResponseText(for: message).isEmpty
    }
    
    // MARK: - Async Operations for SlackOffView
    
    @MainActor
    func refreshMessages() async {
        loadMessages()
    }
    
    @MainActor
    func clearProcessedMessages() async {
        do {
            let processedMessages = allMessages.filter { 
                $0.status == .sent || $0.status == .dismissed 
            }
            
            for message in processedMessages {
                modelContext.delete(message)
            }
            
            try modelContext.save()
            loadMessages()
            
        } catch {
            print("❌ Failed to clear processed messages: \(error)")
        }
    }
    
    func getResponse(for messageId: String) -> String? {
        guard let message = allMessages.first(where: { $0.id.uuidString == messageId }) else {
            return nil
        }
        return message.editedResponse ?? message.aiResponse
    }
    
    @MainActor
    func saveResponse(for messageId: String, response: String) async {
        guard let message = allMessages.first(where: { $0.id.uuidString == messageId }) else {
            print("❌ Message not found for ID: \(messageId)")
            return
        }
        
        do {
            message.aiResponse = response
            message.status = .completed
            message.processedAt = Date()
            
            try modelContext.save()
            loadMessages()
            
        } catch {
            print("❌ Failed to save AI response: \(error)")
        }
    }
    
    @MainActor
    func updateMessageStatus(_ messageId: String, status: SlackMessage.MessageStatus) async {
        guard let message = allMessages.first(where: { $0.id.uuidString == messageId }) else {
            print("❌ Message not found for ID: \(messageId)")
            return
        }
        
        do {
            message.status = status
            
            if status == .processing {
                message.processedAt = Date()
            } else if status == .sent {
                message.sentAt = Date()
            }
            
            try modelContext.save()
            loadMessages()
            
        } catch {
            print("❌ Failed to update message status: \(error)")
        }
    }
    
    func sendResponseToSlack(messageId: String, response: String) async throws {
        guard let message = allMessages.first(where: { $0.id.uuidString == messageId }) else {
            throw SlackMessageError.messageNotFound
        }
        
        // Create the response payload for Zapier
        let responsePayload = ZapierResponsePayload(
            messageId: messageId,
            responseText: response,
            channel: message.channelId,
            threadId: message.threadTS,
            originalMessageText: message.text,
            userIdMention: message.userId,
            timestamp: Date()
        )
        
        // Get configured Zapier webhook URL
        guard let zapierWebhookURL = await SlackerConfig.shared.getZapierWebhookURL() else {
            throw SlackMessageError.webhookNotConfigured
        }
        
        guard let url = URL(string: zapierWebhookURL) else {
            throw SlackMessageError.invalidWebhookURL
        }
        
        do {
            let jsonData = try JSONEncoder().encode(responsePayload)
            
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.setValue("SlackSassin-Response/1.0", forHTTPHeaderField: "User-Agent")
            request.httpBody = jsonData
            
            let (_, response) = try await URLSession.shared.data(for: request)
            
            if let httpResponse = response as? HTTPURLResponse,
               200...299 ~= httpResponse.statusCode {
                print("✅ Response sent to Slack successfully")
                
                // Update message status
                await updateMessageStatus(messageId, status: .sent)
            } else {
                throw SlackMessageError.webhookSendFailed
            }
            
        } catch {
            print("❌ Failed to send response to Slack: \(error)")
            throw error
        }
    }
    
    // MARK: - Auto Response Generation
    @MainActor
    private func autoGenerateResponse(for message: SlackMessage) async {
        do {
            print("🔄 Starting auto-response generation for message: \(message.id)")
            print("📝 Message text: \(message.text)")
            
            // Update message status to processing
            await updateMessageStatus(message.id.uuidString, status: .processing)
            
            // Configure OllamaKit with detailed logging
            let hostURL = Defaults[.defaultHost]
            print("🌐 Using Ollama host: \(hostURL)")
            
            guard let baseURL = URL(string: hostURL) else {
                print("❌ Invalid Ollama host URL: \(hostURL)")
                await updateMessageStatus(message.id.uuidString, status: .failed)
                return
            }
            
            let ollamaKit = OllamaKit(baseURL: baseURL)
            print("🔧 OllamaKit configured with base URL: \(baseURL)")
            
            // Check if Ollama is reachable with detailed error reporting
            print("🔍 Testing Ollama connectivity...")
            let isReachable = await ollamaKit.reachable()
            if !isReachable {
                print("❌ Ollama reachable() returned false")
                await updateMessageStatus(message.id.uuidString, status: .failed)
                return
            }
            print("✅ Ollama connectivity confirmed")
            
            // Get SlackOff model
            let model = Defaults[.slackOffModel]
            print("🤖 SlackOff model configured: '\(model)'")
            guard !model.isEmpty else {
                print("❌ No SlackOff model configured")
                await updateMessageStatus(message.id.uuidString, status: .failed)
                return
            }
            
            // Create prompt
            let systemPrompt = Defaults[.slackOffSystemPrompt]
            print("📋 Using system prompt: \(systemPrompt.prefix(100))...")
            
            let prompt = """
            \(systemPrompt)
            
            Context:
            - User: \(message.userName ?? "Someone")
            - Channel: #\(message.channelName ?? "unknown")
            - Timestamp: \(formatDate(message.receivedAt))
            
            Message to respond to:
            \(message.text)
            
            Please provide a professional, helpful response appropriate for this Slack message.
            """
            
            print("🎯 Generated prompt length: \(prompt.count) characters")
            
            // Try direct OllamaKit chat instead of using MessageViewModel
            print("🚀 Starting direct OllamaKit chat...")
            
            let userMessage = OKChatRequestData.Message(role: .user, content: prompt)
            let chatRequest = OKChatRequestData(model: model, messages: [userMessage])
            
            var fullResponse = ""
            var isInThinkBlock = false
            var thinkingContent = ""
            var displayResponse = ""
            
            for try await chunk in ollamaKit.chat(data: chatRequest) {
                if let content = chunk.message?.content {
                    fullResponse += content
                    
                    // Process content to filter out think blocks
                    for char in content {
                        if !isInThinkBlock {
                            // Check if we're entering a think block
                            let tempBuffer = displayResponse + String(char)
                            if tempBuffer.hasSuffix("<think>") {
                                isInThinkBlock = true
                                // Remove the "<think>" from display
                                displayResponse = String(displayResponse.dropLast(6))
                                thinkingContent = ""
                            } else {
                                displayResponse += String(char)
                            }
                        } else {
                            // We're inside a think block
                            thinkingContent += String(char)
                            // Check if we're exiting the think block
                            if thinkingContent.hasSuffix("</think>") {
                                isInThinkBlock = false
                                // Log the thinking content for debug purposes
                                print("🧠 Model thinking: \(thinkingContent.dropLast(8))")
                                thinkingContent = ""
                            }
                        }
                    }
                }
                
                if chunk.done {
                    break
                }
            }
            
            // Clean up the display response
            displayResponse = displayResponse.trimmingCharacters(in: .whitespacesAndNewlines)
            
            print("✅ Direct chat generation successful!")
            print("📤 Full response length: \(fullResponse.count) characters")
            print("📤 Display response: \(displayResponse.prefix(100))...")
            
            // Save both responses - display version for UI, full version for records
            await saveResponse(for: message.id.uuidString, response: displayResponse)
            
            // Optionally save the full response with thinking in a separate field for debugging
            // This could be added to the SlackMessage model if needed
            
            await updateMessageStatus(message.id.uuidString, status: .completed)
            
            print("✅ Auto-response saved successfully")
            
        } catch {
            print("❌ Auto-response generation failed: \(error)")
            print("🔍 Error details: \(error.localizedDescription)")
            if let decodingError = error as? DecodingError {
                print("🔍 Decoding error: \(decodingError)")
            }
            await updateMessageStatus(message.id.uuidString, status: .failed)
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}

// MARK: - Error Types
enum SlackMessageError: LocalizedError {
    case messageNotFound
    case invalidWebhookURL
    case webhookSendFailed
    case webhookNotConfigured
    
    var errorDescription: String? {
        switch self {
        case .messageNotFound:
            return "Message not found"
        case .invalidWebhookURL:
            return "Invalid webhook URL"
        case .webhookSendFailed:
            return "Failed to send webhook response"
        case .webhookNotConfigured:
            return "Zapier webhook URL not configured"
        }
    }
}

// Note: ZapierResponsePayload is defined in SlackMessage.swift to avoid duplication 