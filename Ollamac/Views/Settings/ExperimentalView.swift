//
//  ExperimentalView.swift
//  Slacker
//
//  Created by Kevin Hermawan on 8/10/24.
//

import Defaults
import SwiftUI

struct ExperimentalView: View {
    @Default(.experimentalCodeHighlighting) private var experimentalCodeHighlighting
    @Default(.similarityDisplayThreshold) private var similarityDisplayThreshold
    @Default(.similarityAutoResponseThreshold) private var similarityAutoResponseThreshold
    @Default(.similarityEmbeddingModel) private var similarityEmbeddingModel
    @Environment(NGrokManager.self) private var ngrokManager
    
    var body: some View {
        Form {
            Section {
                Box {
                    HStack(alignment: .center) {
                        Text("Code Highlighting")
                            .fontWeight(.semibold)
                        
                        Spacer()
                        
                        Toggle("", isOn: $experimentalCodeHighlighting)
                            .labelsHidden()
                            .toggleStyle(.switch)
                    }
                }
            } footer: {
                SectionFooter("Enabling this might affect generation and scrolling performance.")
            }
            
            Section {
                Box {
                    VStack(spacing: 12) {
                        HStack {
                            Text("Display Threshold")
                                .fontWeight(.semibold)
                            Spacer()
                            Text("\(Int(similarityDisplayThreshold))%")
                                .foregroundColor(.secondary)
                                .monospacedDigit()
                        }
                        
                        Slider(value: $similarityDisplayThreshold, in: 0...100, step: 5)
                        
                        Divider()
                        
                        HStack {
                            Text("Auto-Response Threshold")
                                .fontWeight(.semibold)
                            Spacer()
                            Text("\(Int(similarityAutoResponseThreshold))%")
                                .foregroundColor(.secondary)
                                .monospacedDigit()
                        }
                        
                        Slider(value: $similarityAutoResponseThreshold, in: 0...100, step: 5)
                        
                        Divider()
                        
                        HStack {
                            Text("Embedding Model")
                                .fontWeight(.semibold)
                            Spacer()
                            Picker("", selection: $similarityEmbeddingModel) {
                                Text("nomic-embed-text:v1.5").tag("nomic-embed-text:v1.5")
                                Text("all-minilm:22m").tag("all-minilm:22m")
                                Text("text-based (current)").tag("text-based")
                            }
                            .pickerStyle(.menu)
                        }
                    }
                }
            } header: {
                Text("Similarity Detection")
            } footer: {
                SectionFooter("Configure thresholds for displaying and auto-responding to similar messages. Display threshold determines when similarity info appears in UI. Auto-response threshold determines when automatic responses are sent.")
            }
            
            Section {
                NGrokStatusView()
            } header: {
                Text("NGrok Tunnel")
            } footer: {
                SectionFooter("External tunnel service for webhook connectivity.")
            }
            
            Section {
                SlackSassinConfigView()
            } header: {
                Text("SlackSassin Configuration")
            } footer: {
                SectionFooter("Configure webhook URLs for Slack integration.")
            }
        }
    }
}

struct NGrokStatusView: View {
    @Environment(NGrokManager.self) private var ngrokManager
    
    var body: some View {
        Box {
            VStack(alignment: .leading, spacing: 12) {
                // Status indicator
                HStack {
                    Image(systemName: ngrokManager.isRunning ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .foregroundColor(ngrokManager.isRunning ? .green : .red)
                    
                    Text(ngrokManager.isRunning ? "Tunnel Active" : "Tunnel Inactive")
                        .fontWeight(.semibold)
                    
                    Spacer()
                }
                
                // Tunnel URL or error message
                if let tunnelURL = ngrokManager.tunnelURL {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Tunnel URL:")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        HStack {
                            Text(tunnelURL)
                                .font(.system(.caption, design: .monospaced))
                                .foregroundColor(.primary)
                                .textSelection(.enabled)
                            
                            Spacer()
                            
                            Button("Copy") {
                                NSPasteboard.general.clearContents()
                                NSPasteboard.general.setString(tunnelURL, forType: .string)
                            }
                            .buttonStyle(.borderless)
                            .font(.caption)
                        }
                    }
                } else if ngrokManager.lastError != nil {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Manual Setup Required:")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Text(ngrokManager.getManualStartInstructions())
                            .font(.system(.caption, design: .monospaced))
                            .foregroundColor(.secondary)
                            .textSelection(.enabled)
                            .padding(8)
                            .background(Color.secondary.opacity(0.1))
                            .cornerRadius(4)
                    }
                }
                
                // Control buttons
                HStack {
                    Button("Start Tunnel") {
                        ngrokManager.startTunnel()
                    }
                    .disabled(ngrokManager.isRunning)
                    
                    Button("Stop Tunnel") {
                        ngrokManager.stopTunnel()
                    }
                    .disabled(!ngrokManager.isRunning)
                    
                    Spacer()
                    
                    Button("Check External") {
                        Task {
                            await ngrokManager.checkExternalTunnel()
                        }
                    }
                    .buttonStyle(.borderless)
                }
            }
        }
    }
}

struct SlackSassinConfigView: View {
    @State private var zapierWebhookURL: String = ""
    @State private var ngrokStaticURL: String = ""
    @State private var webhookServerPort: Int = 8080
    @State private var showingAlert = false
    @State private var alertMessage = ""
    @State private var isConfigured = false
    
    var body: some View {
        Box {
            VStack(alignment: .leading, spacing: 12) {
                // Configuration status
                HStack {
                    Image(systemName: isConfigured ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                        .foregroundColor(isConfigured ? .green : .orange)
                    
                    Text(isConfigured ? "SlackSassin Configured" : "Configuration Required")
                        .fontWeight(.semibold)
                    
                    Spacer()
                }
                
                // Zapier Webhook URL
                VStack(alignment: .leading, spacing: 4) {
                    Text("Zapier Webhook URL:")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    HStack {
                        TextField("https://hooks.zapier.com/hooks/catch/...", text: $zapierWebhookURL)
                            .textFieldStyle(.roundedBorder)
                            .font(.system(.caption, design: .monospaced))
                        
                        Button("Clear") {
                            zapierWebhookURL = ""
                        }
                        .buttonStyle(.borderless)
                        .font(.caption)
                    }
                }
                
                // NGrok Static URL
                VStack(alignment: .leading, spacing: 4) {
                    Text("NGrok Static URL:")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    HStack {
                        TextField("your-static-url.ngrok-free.app", text: $ngrokStaticURL)
                            .textFieldStyle(.roundedBorder)
                            .font(.system(.caption, design: .monospaced))
                        
                        Button("Clear") {
                            ngrokStaticURL = ""
                        }
                        .buttonStyle(.borderless)
                        .font(.caption)
                    }
                }
                
                // Webhook Server Port
                VStack(alignment: .leading, spacing: 4) {
                    Text("Webhook Server Port:")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    HStack {
                        TextField("8080", value: $webhookServerPort, format: .number)
                            .textFieldStyle(.roundedBorder)
                            .font(.system(.caption, design: .monospaced))
                            .frame(width: 80)
                        
                        Text("(1024-65535)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Spacer()
                    }
                }
                
                // Action buttons
                HStack {
                    Button("Save Configuration") {
                        saveConfiguration()
                    }
                    .buttonStyle(.borderedProminent)
                    
                    Button("Clear All") {
                        clearConfiguration()
                    }
                    .buttonStyle(.bordered)
                    
                    Spacer()
                    
                    Button("Test Configuration") {
                        testConfiguration()
                    }
                    .buttonStyle(.borderless)
                }
            }
        }
        .onAppear {
            loadConfiguration()
        }
        .alert("Configuration", isPresented: $showingAlert) {
            Button("OK") { }
        } message: {
            Text(alertMessage)
        }
    }
    
    private func loadConfiguration() {
        zapierWebhookURL = SlackerConfig.shared.getZapierWebhookURL() ?? ""
        ngrokStaticURL = SlackerConfig.shared.getNgrokStaticURL() ?? ""
        webhookServerPort = SlackerConfig.shared.getWebhookServerPort()
        isConfigured = SlackerConfig.shared.isConfigured()
    }
    
    private func saveConfiguration() {
        do {
            // Save Zapier webhook URL
            if !zapierWebhookURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                try SlackerConfig.shared.setZapierWebhookURL(zapierWebhookURL.trimmingCharacters(in: .whitespacesAndNewlines))
            }
            
            // Save NGrok static URL
            if !ngrokStaticURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                try SlackerConfig.shared.setNgrokStaticURL(ngrokStaticURL.trimmingCharacters(in: .whitespacesAndNewlines))
            }
            
            // Save webhook server port
            try SlackerConfig.shared.setWebhookServerPort(webhookServerPort)
            
            // Update status
            isConfigured = SlackerConfig.shared.isConfigured()
            
            alertMessage = "Configuration saved successfully!"
            showingAlert = true
            
        } catch {
            alertMessage = "Failed to save configuration: \(error.localizedDescription)"
            showingAlert = true
        }
    }
    
    private func clearConfiguration() {
        SlackerConfig.shared.clearConfiguration()
        loadConfiguration()
        alertMessage = "Configuration cleared successfully!"
        showingAlert = true
    }
    
    private func testConfiguration() {
        // Simple validation test
        var issues: [String] = []
        
        if zapierWebhookURL.isEmpty {
            issues.append("Zapier webhook URL is required")
        } else if !zapierWebhookURL.contains("hooks.zapier.com") {
            issues.append("Zapier webhook URL should contain 'hooks.zapier.com'")
        }
        
        if ngrokStaticURL.isEmpty {
            issues.append("NGrok static URL is required")
        } else if !ngrokStaticURL.contains("ngrok") {
            issues.append("NGrok static URL should contain 'ngrok'")
        }
        
        if webhookServerPort < 1024 || webhookServerPort > 65535 {
            issues.append("Webhook server port must be between 1024 and 65535")
        }
        
        if issues.isEmpty {
            alertMessage = "Configuration looks good! ✅"
        } else {
            alertMessage = "Configuration issues found:\n\n" + issues.joined(separator: "\n")
        }
        
        showingAlert = true
    }
}
