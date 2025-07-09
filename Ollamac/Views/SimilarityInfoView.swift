// SimilarityInfoView.swift
// Created by Kevin Keller -- Tucuxi, Inc. July 2025

import SwiftUI

struct SimilarityInfoView: View {
    let message: SlackMessage
    @Environment(SlackMessageViewModel.self) private var slackMessageViewModel
    @State private var showingSimilarMessages = false
    
    private var similarMessages: [SimilarMessageResult] {
        slackMessageViewModel.getSimilarMessages(for: message.id.uuidString)
    }
    
    private var autoResponseCandidate: SimilarMessageResult? {
        slackMessageViewModel.getAutoResponseCandidate(for: message.id.uuidString)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Auto-response notification
            if let candidate = autoResponseCandidate {
                autoResponseNotification(candidate)
            }
            
            // Similar requests info
            if !similarMessages.isEmpty {
                similarRequestsInfo()
            }
        }
    }
    
    @ViewBuilder
    private func autoResponseNotification(_ candidate: SimilarMessageResult) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "bolt.circle.fill")
                .foregroundColor(.green)
            
            VStack(alignment: .leading, spacing: 2) {
                Text("Auto-Response Sent")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.green)
                
                Text("Using template with \(candidate.formattedConfidence) confidence")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
        .padding(8)
        .background(Color.green.opacity(0.1))
        .cornerRadius(6)
    }
    
    @ViewBuilder
    private func similarRequestsInfo() -> some View {
        Button {
            showingSimilarMessages = true
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass.circle")
                    .foregroundColor(.blue)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("Similar Requests: \(similarMessages.count)")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                    
                    if let highest = similarMessages.first {
                        Text("Highest: \(highest.formattedConfidence)")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .buttonStyle(.plain)
        .padding(8)
        .background(Color.blue.opacity(0.05))
        .cornerRadius(6)
        .sheet(isPresented: $showingSimilarMessages) {
            SimilarMessagesSheet(
                message: message,
                similarMessages: similarMessages,
                onMarkAsNotSimilar: { similarMessageId in
                    Task {
                        await slackMessageViewModel.markAsNotSimilar(
                            messageId: message.id.uuidString,
                            similarMessageId: similarMessageId
                        )
                    }
                }
            )
        }
    }
}

struct SimilarMessagesSheet: View {
    let message: SlackMessage
    let similarMessages: [SimilarMessageResult]
    let onMarkAsNotSimilar: (UUID) -> Void
    
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            VStack(alignment: .leading, spacing: 16) {
                // Original message
                VStack(alignment: .leading, spacing: 8) {
                    Text("Original Message")
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    Text(message.text)
                        .padding()
                        .background(Color(NSColor.controlBackgroundColor))
                        .cornerRadius(8)
                }
                
                Divider()
                
                // Similar messages
                VStack(alignment: .leading, spacing: 8) {
                    Text("Similar Messages (\(similarMessages.count))")
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            ForEach(Array(similarMessages.enumerated()), id: \.element.message.id) { index, result in
                                SimilarMessageCard(
                                    result: result,
                                    rank: index + 1,
                                    onMarkAsNotSimilar: {
                                        onMarkAsNotSimilar(result.message.id)
                                    }
                                )
                            }
                        }
                        .padding(.vertical, 8)
                    }
                }
                
                Spacer()
            }
            .padding()
            .navigationTitle("Similar Messages")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        .frame(width: 600, height: 500)
    }
}

struct SimilarMessageCard: View {
    let result: SimilarMessageResult
    let rank: Int
    let onMarkAsNotSimilar: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header with confidence and rank
            HStack {
                HStack(spacing: 4) {
                    Text("#\(rank)")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(.secondary)
                    
                    Text(result.confidenceLevel.emoji)
                    
                    Text(result.formattedConfidence)
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(confidenceColor)
                }
                
                Spacer()
                
                Button("Not Similar") {
                    onMarkAsNotSimilar()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .foregroundColor(.red)
            }
            
            // Original message
            VStack(alignment: .leading, spacing: 4) {
                Text("Question:")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.secondary)
                
                Text(result.message.text)
                    .font(.body)
            }
            
            // Response
            if let response = result.message.editedResponse ?? result.message.aiResponse {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Response:")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.secondary)
                    
                    Text(response)
                        .font(.body)
                        .foregroundColor(.secondary)
                }
            }
            
            // Metadata
            HStack {
                if let channelName = result.message.channelName {
                    Label(channelName, systemImage: "number")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                
                if let userName = result.message.userName {
                    Label(userName, systemImage: "person")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Text(formatDate(result.message.receivedAt))
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(confidenceColor.opacity(0.3), lineWidth: 1)
        )
    }
    
    private var confidenceColor: Color {
        switch result.confidenceLevel {
        case .veryHigh:
            return .green
        case .high:
            return .blue
        case .medium:
            return .orange
        case .low:
            return .gray
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

#Preview {
    // Preview with mock data
    let mockMessage = SlackMessage(
        text: "How do I reset my password?",
        channelId: "C123",
        userId: "U123",
        slackTimestamp: "1234567890.123"
    )
    
    SimilarityInfoView(message: mockMessage)
} 