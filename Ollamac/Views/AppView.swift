//
//  AppView.swift
//  Slacker
//
//  Created by Kevin Hermawan on 03/11/23.
//

import SwiftUI

struct AppView: View {
    @Binding var currentView: AppViewMode
    
    var body: some View {
        Group {
            if currentView == .slackOff {
                // SlackOff Mode: Full-width, no sidebar
                SlackOffView(currentView: $currentView)
            } else {
                // Chat Mode: Traditional split view with sidebar
                VStack(spacing: 0) {
                    // Mode indicator header for chat mode
                    HStack {
                        Text("Chat Mode")
                            .font(.headline)
                            .foregroundColor(.blue)
                        
                        Spacer()
                        
                        Button("Switch to SlackOff") {
                            currentView = .slackOff
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    .padding()
                    .background(Color(NSColor.controlBackgroundColor))
                    
                    // Traditional split view for chat
                    NavigationSplitView {
                        SidebarView()
                            .navigationSplitViewColumnWidth(min: 256, ideal: 256)
                    } detail: {
                        ChatView()
                    }
                }
            }
        }
    }
}

// Placeholder view for SlackOff mode until SlackOffView is added to project
struct SlackOffPlaceholderView: View {
    @Environment(SlackerWebhookServer.self) private var webhookServer
    @Environment(NGrokManager.self) private var ngrokManager
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "message.badge")
                .font(.system(size: 60))
                .foregroundColor(.orange)
            
            Text("SlackOff Mode - Phase 2")
                .font(.largeTitle)
                .fontWeight(.bold)
            
            Text("Slack Message Processing Interface")
                .font(.title2)
                .foregroundColor(.secondary)
            
            VStack(spacing: 12) {
                StatusRow(title: "Webhook Server", status: webhookServer.isRunning, details: "Port 8080")
                StatusRow(title: "NGrok Tunnel", status: ngrokManager.isRunning, details: "Tunnel Active")
            }
            .padding()
            .background(Color(NSColor.controlBackgroundColor))
            .cornerRadius(8)
            
            if webhookServer.isRunning && ngrokManager.isRunning {
                VStack(spacing: 8) {
                    Text("🎉 Ready for Zapier Integration!")
                        .font(.headline)
                        .foregroundColor(.green)
                    
                    Text("Webhook URL: https://[your-ngrok-tunnel-host].ngrok-free.app/zapier-webhook")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Text("SlackOffView will be added to Xcode project in Phase 2 completion")
                .font(.caption)
                .foregroundColor(.secondary)
                .italic()
        }
        .padding()
    }
}

struct StatusRow: View {
    let title: String
    let status: Bool
    let details: String
    
    var body: some View {
        HStack {
            Image(systemName: status ? "checkmark.circle.fill" : "xmark.circle.fill")
                .foregroundColor(status ? .green : .red)
            
            VStack(alignment: .leading) {
                Text(title)
                    .fontWeight(.medium)
                Text(details)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
    }
}
