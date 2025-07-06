//
//  SlackOffView.swift
//  Slacker
//
//  Created by SlackSassin Integration
//

import SwiftUI
import Defaults
import OllamaKit

struct SlackOffView: View {
    @Binding var currentView: AppViewMode
    
    @Environment(SlackerWebhookServer.self) private var webhookServer
    @Environment(NGrokManager.self) private var ngrokManager
    @Environment(SlackMessageViewModel.self) private var slackMessageViewModel
    @Environment(ChatViewModel.self) private var chatViewModel
    @Environment(MessageViewModel.self) private var messageViewModel
    
    @State private var selectedMessage: SlackMessage?
    @State private var isProcessingResponse = false
    @State private var showingSettings = false
    @State private var ollamaKit: OllamaKit
    
    init(currentView: Binding<AppViewMode>) {
        self._currentView = currentView
        let baseURL = URL(string: Defaults[.defaultHost])!
        self._ollamaKit = State(initialValue: OllamaKit(baseURL: baseURL))
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header with status and controls
            HeaderView(currentView: $currentView, 
                      webhookServer: webhookServer, 
                      ngrokManager: ngrokManager,
                      showingSettings: $showingSettings)
            
            Divider()
            
            if slackMessageViewModel.allMessages.isEmpty {
                // Empty state
                EmptyStateView()
            } else {
                // Main content: message list and detail
                HSplitView {
                    // Message list (left panel)
                    MessageListView(selectedMessage: $selectedMessage)
                        .frame(minWidth: 350, maxWidth: 500)
                    
                    // Message detail and response (right panel)
                    MessageDetailView(selectedMessage: $selectedMessage,
                             currentView: $currentView,
                             isProcessingResponse: $isProcessingResponse,
                             ollamaKit: ollamaKit)
                        .frame(minWidth: 400)
                }
            }
        }
        .sheet(isPresented: $showingSettings) {
            SlackOffSettingsView()
        }
        .onAppear {
            Task { await slackMessageViewModel.refreshMessages() }
        }
    }
}

// MARK: - Header View
struct HeaderView: View {
    @Binding var currentView: AppViewMode
    let webhookServer: SlackerWebhookServer
    let ngrokManager: NGrokManager
    @Binding var showingSettings: Bool
    
    @Environment(SlackMessageViewModel.self) private var slackMessageViewModel
    
    var body: some View {
        VStack(spacing: 12) {
            // Title and mode switch
            HStack {
                VStack(alignment: .leading) {
                    Text("SlackOff Mode")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.orange)
                    
                    Text("Slack Message Processing")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // Settings menu
                Menu {
                    Button("Refresh Messages") {
                        Task { await slackMessageViewModel.refreshMessages() }
                    }
                    Button("Clear Processed") {
                        Task { await slackMessageViewModel.clearProcessedMessages() }
                    }
                    Divider()
                    Button("Settings") {
                        showingSettings = true
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .imageScale(.large)
                }
                .buttonStyle(.borderless)
                
                Button("Switch to Chat") {
                    currentView = .chat
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.regular)
            }
            
            // Status indicators
            HStack(spacing: 20) {
                StatusIndicator(title: "Webhook", 
                              isActive: webhookServer.isRunning, 
                              details: "Port 8080")
                
                StatusIndicator(title: "NGrok", 
                              isActive: ngrokManager.isRunning, 
                              details: "Tunnel Active")
                
                Spacer()
                
                // Message counts
                HStack(spacing: 16) {
                    MessageCountBadge(count: slackMessageViewModel.pendingMessages.count, 
                                    label: "Pending", 
                                    color: .orange)
                    
                    MessageCountBadge(count: slackMessageViewModel.processingMessages.count, 
                                    label: "Processing", 
                                    color: .blue)
                    
                    MessageCountBadge(count: slackMessageViewModel.completedMessages.count, 
                                    label: "Ready", 
                                    color: .green)
                }
            }
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor))
    }
}

struct StatusIndicator: View {
    let title: String
    let isActive: Bool
    let details: String
    
    var body: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(isActive ? Color.green : Color.red)
                .frame(width: 8, height: 8)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption)
                    .fontWeight(.medium)
                Text(details)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
    }
}

struct MessageCountBadge: View {
    let count: Int
    let label: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 2) {
            Text("\(count)")
                .font(.title3)
                .fontWeight(.bold)
                .foregroundColor(color)
            Text(label)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
    }
}

// MARK: - Empty State View
struct EmptyStateView: View {
    @Environment(SlackerWebhookServer.self) private var webhookServer
    @Environment(NGrokManager.self) private var ngrokManager
    
    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            
            Image(systemName: "message.badge")
                .font(.system(size: 60))
                .foregroundColor(.orange)
            
            VStack(spacing: 8) {
                Text("Ready for Slack Messages")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Text("Your webhook is active and waiting for messages from Zapier")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            if webhookServer.isRunning && ngrokManager.isRunning {
                VStack(spacing: 12) {
                    Label("Webhook Active", systemImage: "checkmark.circle.fill")
                        .foregroundColor(.green)
                        .font(.headline)
                    
                    VStack(spacing: 4) {
                        Text("Webhook URL:")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text("https://[your-ngrok-tunnel].ngrok-free.app/zapier-webhook")
                            .font(.caption)
                            .foregroundColor(.blue)
                            .textSelection(.enabled)
                    }
                    .padding()
                    .background(Color(NSColor.controlBackgroundColor))
                    .cornerRadius(8)
                }
            }
            
            Spacer()
        }
        .padding()
        .frame(maxWidth: 600)
    }
}

// MARK: - Message List View
struct MessageListView: View {
    @Binding var selectedMessage: SlackMessage?
    @Environment(SlackMessageViewModel.self) private var slackMessageViewModel
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // List header
            HStack {
                Text("Messages")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Spacer()
                
                Text("\(slackMessageViewModel.allMessages.count)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(Color(NSColor.quaternaryLabelColor))
                    .clipShape(Capsule())
            }
            .padding()
            
            Divider()
            
            // Message list
            List(slackMessageViewModel.allMessages, id: \.id, selection: $selectedMessage) { message in
                MessageRowView(message: message)
                    .listRowSeparator(.hidden)
                    .listRowInsets(EdgeInsets(top: 4, leading: 12, bottom: 4, trailing: 12))
                    .onTapGesture {
                        selectedMessage = message
                    }
            }
            .listStyle(.plain)
        }
        .background(Color(NSColor.controlBackgroundColor))
        .onAppear {
            // Auto-select first message if none selected
            if selectedMessage == nil && !slackMessageViewModel.allMessages.isEmpty {
                selectedMessage = slackMessageViewModel.allMessages.first
            }
        }
    }
}

struct MessageRowView: View {
    let message: SlackMessage
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header with user and channel
            HStack {
                // User avatar placeholder
                Circle()
                    .fill(Color.blue.opacity(0.2))
                    .frame(width: 32, height: 32)
                    .overlay {
                        Text(String(message.userName?.first ?? "?"))
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(.blue)
                    }
                
                VStack(alignment: .leading, spacing: 2) {
                    HStack {
                        Text(message.userName ?? "Unknown")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        
                        Text("in #\(message.channelName ?? "unknown")")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Text(RelativeDateTimeFormatter().localizedString(for: message.receivedAt, relativeTo: Date()))
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // Status indicator
                StatusIcon(status: message.status)
            }
            
            // Message preview
            Text(message.text)
                .font(.subheadline)
                .lineLimit(3)
                .foregroundColor(.primary)
            
            // Keywords/tags
            if !message.matchedKeywords.isEmpty {
                HStack {
                    ForEach(Array(message.matchedKeywords.prefix(3)), id: \.self) { keyword in
                        Text(keyword)
                            .font(.caption2)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.orange.opacity(0.2))
                            .foregroundColor(.orange)
                            .clipShape(Capsule())
                    }
                    Spacer()
                }
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(8)
    }
}

struct StatusIcon: View {
    let status: SlackMessage.MessageStatus
    
    var body: some View {
        Group {
            switch status {
            case .pending:
                Image(systemName: "clock")
                    .foregroundColor(.orange)
            case .processing:
                Image(systemName: "gearshape.fill")
                    .foregroundColor(.blue)
            case .completed:
                Image(systemName: "checkmark.circle")
                    .foregroundColor(.green)
            case .sent:
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
            case .failed:
                Image(systemName: "exclamationmark.triangle")
                    .foregroundColor(.red)
            case .dismissed:
                Image(systemName: "xmark.circle")
                    .foregroundColor(.gray)
            }
        }
        .font(.caption)
    }
}

// MARK: - Message Detail View
struct MessageDetailView: View {
    @Binding var selectedMessage: SlackMessage?
    @Binding var currentView: AppViewMode
    @Binding var isProcessingResponse: Bool
    let ollamaKit: OllamaKit
    
    @Environment(SlackMessageViewModel.self) private var slackMessageViewModel
    @Environment(ChatViewModel.self) private var chatViewModel
    @Environment(MessageViewModel.self) private var messageViewModel
    
    @State private var generatedResponse: String = ""
    @State private var isEditing = false
    @State private var editedResponse: String = ""
    @State private var showingError = false
    @State private var errorMessage = ""
    
    var body: some View {
        VStack {
            if let message = selectedMessage {
                MessageDetailContent(message: message,
                                   generatedResponse: $generatedResponse,
                                   isEditing: $isEditing,
                                   editedResponse: $editedResponse,
                                   isProcessingResponse: $isProcessingResponse,
                                   currentView: $currentView,
                                   showingError: $showingError,
                                   errorMessage: $errorMessage)
            } else {
                // No message selected
                VStack(spacing: 16) {
                    Image(systemName: "message")
                        .font(.system(size: 48))
                        .foregroundColor(.secondary)
                    
                    Text("Select a message to view details")
                        .font(.headline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .alert("Error", isPresented: $showingError) {
            Button("OK") { }
        } message: {
            Text(errorMessage)
        }
        .onChange(of: selectedMessage) { _, newMessage in
            if let message = newMessage {
                Task {
                    await loadOrGenerateResponse(for: message)
                }
            }
        }
    }
    
    private func loadOrGenerateResponse(for message: SlackMessage) async {
        // Check if we already have a response
        if let existingResponse = slackMessageViewModel.getResponse(for: message.id.uuidString) {
            generatedResponse = existingResponse
            editedResponse = existingResponse
        } else if message.status == .pending {
            // Generate new response
            await generateAIResponse(for: message)
        }
    }
    
    private func generateAIResponse(for message: SlackMessage) async {
        isProcessingResponse = true
        
        // Update message status
        await slackMessageViewModel.updateMessageStatus(message.id.uuidString, status: .processing)
        
        do {
            print("🤖 Starting AI response generation for message: \(message.text)")
            
            // Check if Ollama is reachable
            print("🔍 Checking if Ollama is reachable at: \(Defaults[.defaultHost])")
            let isReachable = await ollamaKit.reachable()
            guard isReachable else {
                print("❌ Ollama is not reachable")
                throw MessageGenerationError.ollamaNotReachable
            }
            print("✅ Ollama is reachable")
            
            // Check if we have a valid model (use SlackOff-specific model)
            let selectedModel = Defaults[.slackOffModel]
            print("🔍 Selected SlackOff model: \(selectedModel)")
            guard !selectedModel.isEmpty else {
                print("❌ No SlackOff model selected")
                throw MessageGenerationError.noModelSelected
            }
            
            // Create a context-aware prompt for the AI
            let prompt = createPromptForMessage(message)
            print("📝 Generated prompt: \(prompt)")
            
            // Create a temporary chat and message for AI generation
            let tempChat = Chat(model: selectedModel)
            let tempMessage = Message(prompt: prompt)
            tempChat.messages.append(tempMessage)
            
            // Use existing message infrastructure to generate response
            print("🚀 Starting message generation with model: \(selectedModel)")
            messageViewModel.generate(ollamaKit, activeChat: tempChat, prompt: prompt)
            
            // Wait for response generation with timeout
            var timeoutCounter = 0
            while messageViewModel.loading != nil && timeoutCounter < 300 { // 30 seconds timeout
                try await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
                timeoutCounter += 1
                if timeoutCounter % 10 == 0 { // Log every second
                    print("⏳ Waiting for response... (\(timeoutCounter/10)s)")
                }
            }
            
            // Check if we timed out
            if messageViewModel.loading != nil {
                print("⏰ AI response generation timed out")
                throw MessageGenerationError.timeout
            }
            
            print("🔍 Checking for response in tempMessage")
            guard let response = tempMessage.response else {
                print("❌ No response found in tempMessage")
                print("🔍 TempMessage state: response=\(tempMessage.response ?? "nil")")
                throw MessageGenerationError.noResponse
            }
            
            // Filter out think blocks from the response
            let filteredResponse = filterThinkBlocks(from: response)
            
            print("✅ AI response generated successfully")
            print("📝 Original response length: \(response.count) characters")
            print("📝 Filtered response: \(filteredResponse.prefix(100))...")
            
            await MainActor.run {
                generatedResponse = filteredResponse
                editedResponse = filteredResponse
                isProcessingResponse = false
                
                // Save response and update message status
                Task {
                    await slackMessageViewModel.saveResponse(for: message.id.uuidString, response: response)
                    await slackMessageViewModel.updateMessageStatus(message.id.uuidString, status: .completed)
                }
            }
        } catch {
            await MainActor.run {
                isProcessingResponse = false
                errorMessage = "Failed to generate response: \(error.localizedDescription)"
                showingError = true
                
                // Update message status to failed
                Task {
                    await slackMessageViewModel.updateMessageStatus(message.id.uuidString, status: .failed)
                }
            }
        }
    }
    
    private func createPromptForMessage(_ message: SlackMessage) -> String {
        let systemPrompt = Defaults[.slackOffSystemPrompt]
        return """
        \(systemPrompt)
        
        Context:
        - User: \(message.userName ?? "Someone")
        - Channel: #\(message.channelName ?? "unknown")
        - Timestamp: \(formatDate(message.receivedAt))
        
        Message to respond to:
        \(message.text)
        
        Please provide a professional, helpful response appropriate for this Slack message.
        """
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

struct MessageDetailContent: View {
    let message: SlackMessage
    @Binding var generatedResponse: String
    @Binding var isEditing: Bool
    @Binding var editedResponse: String
    @Binding var isProcessingResponse: Bool
    @Binding var currentView: AppViewMode
    @Binding var showingError: Bool
    @Binding var errorMessage: String
    
    @Environment(SlackMessageViewModel.self) private var slackMessageViewModel
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Original message
                OriginalMessageView(message: message)
                
                Divider()
                
                // AI Response section
                AIResponseSection(message: message,
                                generatedResponse: $generatedResponse,
                                isEditing: $isEditing,
                                editedResponse: $editedResponse,
                                isProcessingResponse: $isProcessingResponse)
                
                Divider()
                
                // Action buttons
                ActionButtonsView(message: message,
                                generatedResponse: generatedResponse,
                                editedResponse: editedResponse,
                                isEditing: $isEditing,
                                currentView: $currentView,
                                showingError: $showingError,
                                errorMessage: $errorMessage)
            }
            .padding()
        }
        .background(Color(NSColor.textBackgroundColor))
    }
}

// MARK: - Component Views

struct OriginalMessageView: View {
    let message: SlackMessage
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Original Message")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Spacer()
                
                StatusIcon(status: message.status)
            }
            
            // Message metadata
            HStack {
                Label(message.userName ?? "Unknown", systemImage: "person.circle")
                Label("#\(message.channelName ?? "unknown")", systemImage: "number")
                Label(formatDate(message.receivedAt), systemImage: "clock")
            }
            .font(.caption)
            .foregroundColor(.secondary)
            
            // Message content
            Text(message.text)
                .font(.body)
                .padding()
                .background(Color(NSColor.controlBackgroundColor))
                .cornerRadius(8)
                .textSelection(.enabled)
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

struct AIResponseSection: View {
    let message: SlackMessage
    @Binding var generatedResponse: String
    @Binding var isEditing: Bool
    @Binding var editedResponse: String
    @Binding var isProcessingResponse: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("AI Response")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Spacer()
                
                if isProcessingResponse {
                    HStack {
                        ProgressView()
                            .scaleEffect(0.8)
                        Text("Generating...")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                } else if !generatedResponse.isEmpty {
                    Button(isEditing ? "View" : "Edit") {
                        isEditing.toggle()
                    }
                    .font(.caption)
                    .buttonStyle(.link)
                }
            }
            
            if isProcessingResponse {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(NSColor.controlBackgroundColor))
                    .frame(height: 100)
                    .overlay {
                        VStack {
                            ProgressView()
                            Text("Generating response using AI...")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    }
            } else if generatedResponse.isEmpty {
                Text("No response generated yet")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .padding()
                    .background(Color(NSColor.controlBackgroundColor))
                    .cornerRadius(8)
            } else {
                if isEditing {
                    // Editable text area
                    TextEditor(text: $editedResponse)
                        .font(.body)
                        .padding(8)
                        .background(Color(NSColor.textBackgroundColor))
                        .border(Color(NSColor.separatorColor), width: 1)
                        .cornerRadius(8)
                        .frame(minHeight: 100)
                } else {
                    // Read-only response
                    Text(editedResponse.isEmpty ? generatedResponse : editedResponse)
                        .font(.body)
                        .padding()
                        .background(Color(NSColor.controlBackgroundColor))
                        .cornerRadius(8)
                        .textSelection(.enabled)
                }
            }
        }
    }
}

struct ActionButtonsView: View {
    let message: SlackMessage
    let generatedResponse: String
    let editedResponse: String
    @Binding var isEditing: Bool
    @Binding var currentView: AppViewMode
    @Binding var showingError: Bool
    @Binding var errorMessage: String
    
    @Environment(SlackMessageViewModel.self) private var slackMessageViewModel
    
    var body: some View {
        VStack(spacing: 12) {
            Text("Actions")
                .font(.headline)
                .fontWeight(.semibold)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            HStack(spacing: 12) {
                // Copy response
                Button {
                    copyToClipboard()
                } label: {
                    Label("Copy", systemImage: "doc.on.doc")
                }
                .disabled(generatedResponse.isEmpty)
                .buttonStyle(.bordered)
                
                // Edit in Chat
                Button {
                    editInChat()
                } label: {
                    Label("Edit in Chat", systemImage: "square.and.pencil")
                }
                .disabled(generatedResponse.isEmpty)
                .buttonStyle(.bordered)
                
                Spacer()
                
                // Dismiss
                Button {
                    dismissMessage()
                } label: {
                    Label("Dismiss", systemImage: "xmark")
                }
                .buttonStyle(.bordered)
                .foregroundColor(.secondary)
                
                // Send to Slack
                Button {
                    sendToSlack()
                } label: {
                    Label("Send to Slack", systemImage: "paperplane.fill")
                }
                .disabled(generatedResponse.isEmpty)
                .buttonStyle(.borderedProminent)
            }
        }
    }
    
    private func copyToClipboard() {
        let responseText = editedResponse.isEmpty ? generatedResponse : editedResponse
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(responseText, forType: .string)
    }
    
    private func editInChat() {
        // Switch to chat mode and populate with the response for editing
        currentView = .chat
        // Note: We would need to implement a way to pass the context to ChatView
    }
    
    private func dismissMessage() {
        Task {
            await slackMessageViewModel.updateMessageStatus(message.id.uuidString, status: .dismissed)
        }
    }
    
    private func sendToSlack() {
        Task {
            do {
                let responseText = editedResponse.isEmpty ? generatedResponse : editedResponse
                try await slackMessageViewModel.sendResponseToSlack(messageId: message.id.uuidString, response: responseText)
                await slackMessageViewModel.updateMessageStatus(message.id.uuidString, status: .sent)
            } catch {
                await MainActor.run {
                    errorMessage = "Failed to send response: \(error.localizedDescription)"
                    showingError = true
                }
            }
        }
    }
}

// MARK: - Settings View
struct SlackOffSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(SlackMessageViewModel.self) private var slackMessageViewModel
    
    @Default(.slackOffModel) private var slackOffModel
    @Default(.slackOffSystemPrompt) private var slackOffSystemPrompt
    @Default(.slackOffAutoResponse) private var slackOffAutoResponse
    @Default(.slackOffTemperature) private var slackOffTemperature
    @Default(.slackOffTopP) private var slackOffTopP
    @Default(.slackOffTopK) private var slackOffTopK
    @Default(.defaultHost) private var defaultHost
    
    @State private var availableModels: [String] = []
    @State private var isLoadingModels = false
    
    var body: some View {
        NavigationView {
            Form {
                Section("AI Model Configuration") {
                    HStack {
                        Text("SlackOff Model")
                        Spacer()
                        if isLoadingModels {
                            ProgressView()
                                .scaleEffect(0.8)
                        } else {
                            Picker("Model", selection: $slackOffModel) {
                                ForEach(availableModels, id: \.self) { model in
                                    Text(model).tag(model)
                                }
                            }
                            .pickerStyle(.menu)
                            .frame(minWidth: 200)
                        }
                    }
                    
                    Button("Refresh Models") {
                        Task { await loadModels() }
                    }
                    .buttonStyle(.borderless)
                }
                
                Section("System Prompt") {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("SlackOff System Prompt")
                            .font(.headline)
                        
                        TextEditor(text: $slackOffSystemPrompt)
                            .font(.system(.body, design: .monospaced))
                            .frame(minHeight: 100)
                            .border(Color.gray.opacity(0.3))
                        
                        Text("This prompt will be used for all SlackOff responses.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Section("Response Settings") {
                    Toggle("Auto-generate responses", isOn: $slackOffAutoResponse)
                        .help("Automatically generate AI responses when Slack messages are received")
                    
                    if slackOffAutoResponse {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("When enabled, SlackSassin will automatically generate AI responses for incoming Slack messages using the selected model and system prompt.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .padding(.top, 4)
                        }
                    }
                }
                
                Section("Generation Parameters") {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("Temperature")
                            Spacer()
                            Text(String(format: "%.1f", slackOffTemperature))
                                .foregroundColor(.secondary)
                        }
                        Slider(value: $slackOffTemperature, in: 0...1, step: 0.1)
                        Text("Controls randomness. Higher values increase creativity, lower values are more focused.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("Top P")
                            Spacer()
                            Text(String(format: "%.1f", slackOffTopP))
                                .foregroundColor(.secondary)
                        }
                        Slider(value: $slackOffTopP, in: 0...1, step: 0.1)
                        Text("Affects diversity. Higher values increase variety, lower values are more conservative.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("Top K")
                            Spacer()
                            Text("\(slackOffTopK)")
                                .foregroundColor(.secondary)
                        }
                        Slider(value: Binding(
                            get: { Double(slackOffTopK) },
                            set: { slackOffTopK = Int($0) }
                        ), in: 1...100, step: 1)
                        Text("Limits token pool. Higher values increase variety, lower values are more conservative.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Section("Connection") {
                    HStack {
                        Text("Ollama Host")
                        Spacer()
                        Text(defaultHost)
                            .foregroundColor(.secondary)
                    }
                    
                    Text("SlackOff uses the same Ollama connection as the chat interface.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .navigationTitle("SlackOff Settings")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        .frame(width: 600, height: 700)
        .onAppear {
            Task { await loadModels() }
        }
    }
    
    private func loadModels() async {
        await MainActor.run {
            isLoadingModels = true
        }
        
        do {
            let ollamaKit = OllamaKit(baseURL: URL(string: defaultHost)!)
            let models = try await ollamaKit.models()
            
            await MainActor.run {
                availableModels = models.models.compactMap { $0.name }
                isLoadingModels = false
            }
        } catch {
            await MainActor.run {
                print("❌ Failed to load models: \(error)")
                availableModels = [slackOffModel] // At least show current selection
                isLoadingModels = false
            }
        }
    }
}

// MARK: - Helper Functions
private func filterThinkBlocks(from text: String) -> String {
    var result = ""
    var isInThinkBlock = false
    var buffer = ""
    
    for char in text {
        if !isInThinkBlock {
            // Check if we're entering a think block
            let tempBuffer = result + String(char)
            if tempBuffer.hasSuffix("<think>") {
                isInThinkBlock = true
                // Remove the "<think>" from result
                result = String(result.dropLast(6))
                buffer = ""
            } else {
                result += String(char)
            }
        } else {
            // We're inside a think block
            buffer += String(char)
            // Check if we're exiting the think block
            if buffer.hasSuffix("</think>") {
                isInThinkBlock = false
                buffer = ""
            }
        }
    }
    
    return result.trimmingCharacters(in: .whitespacesAndNewlines)
}

// MARK: - Error Types
enum MessageGenerationError: Error {
    case noResponse
    case timeout
    case ollamaNotReachable
    case noModelSelected
    
    var localizedDescription: String {
        switch self {
        case .noResponse:
            return "Failed to generate AI response"
        case .timeout:
            return "AI response generation timed out"
        case .ollamaNotReachable:
            return "Ollama server is not reachable. Please check if Ollama is running."
        case .noModelSelected:
            return "No AI model selected. Please configure a default model in settings."
        }
    }
} 
