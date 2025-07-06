//
//  SlackSassinSetupSheet.swift
//  Slacker
//
//  Created by SlackSassin Setup Flow
//

import SwiftUI

struct SlackSassinSetupSheet: View {
    @Binding var isPresented: Bool
    @State private var ngrokURL: String = ""
    @State private var zapierWebhookURL: String = ""
    @State private var showingAlert = false
    @State private var alertMessage = ""
    @State private var isValid = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                // Header
                VStack(spacing: 12) {
                    Image(systemName: "gear.badge.checkmark")
                        .font(.system(size: 48))
                        .foregroundColor(.blue)
                    
                    Text("SlackSassin Setup")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                    
                    Text("Configure your webhook URLs to get started")
                        .font(.title3)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.top)
                
                // Configuration Form
                VStack(spacing: 20) {
                    // NGrok URL Field
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: "network")
                                .foregroundColor(.blue)
                            Text("NGrok Tunnel URL")
                                .font(.headline)
                        }
                        
                        Text("Your static NGrok domain (without https://)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        TextField("your-domain.ngrok-free.app", text: $ngrokURL)
                            .textFieldStyle(.roundedBorder)
                            .font(.system(.body, design: .monospaced))
                    }
                    
                    // Zapier Webhook URL Field
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: "link")
                                .foregroundColor(.orange)
                            Text("Zapier Webhook URL")
                                .font(.headline)
                        }
                        
                        Text("Your Zapier webhook endpoint for sending responses to Slack")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        TextField("https://hooks.zapier.com/hooks/catch/...", text: $zapierWebhookURL)
                            .textFieldStyle(.roundedBorder)
                            .font(.system(.body, design: .monospaced))
                    }
                }
                .padding(.horizontal)
                
                // Validation Status
                if !ngrokURL.isEmpty || !zapierWebhookURL.isEmpty {
                    HStack {
                        Image(systemName: isValid ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                            .foregroundColor(isValid ? .green : .orange)
                        
                        Text(isValid ? "Configuration looks good!" : "Please fill in both fields")
                            .font(.caption)
                            .foregroundColor(isValid ? .green : .orange)
                    }
                }
                
                Spacer()
                
                // Instructions
                VStack(spacing: 12) {
                    Text("Setup Instructions:")
                        .font(.headline)
                    
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(alignment: .top) {
                            Text("1.")
                                .fontWeight(.semibold)
                            Text("Start your NGrok tunnel manually in Terminal:")
                        }
                        
                        Text("ngrok http --url=your-domain.ngrok-free.app 8080")
                            .font(.system(.caption, design: .monospaced))
                            .padding(8)
                            .background(Color.secondary.opacity(0.1))
                            .cornerRadius(4)
                        
                        HStack(alignment: .top) {
                            Text("2.")
                                .fontWeight(.semibold)
                            Text("Get your Zapier webhook URL from your Slack integration")
                        }
                        
                        HStack(alignment: .top) {
                            Text("3.")
                                .fontWeight(.semibold)
                            Text("Enter both URLs above and click 'Complete Setup'")
                        }
                    }
                    .font(.caption)
                    .foregroundColor(.secondary)
                }
                .padding(.horizontal)
            }
            .padding()
            .navigationTitle("Setup")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Skip") {
                        isPresented = false
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Complete Setup") {
                        completeSetup()
                    }
                    .disabled(!isValid)
                    .buttonStyle(.borderedProminent)
                }
            }
        }
        .frame(width: 600, height: 700)
        .onChange(of: ngrokURL) { _, _ in validateInput() }
        .onChange(of: zapierWebhookURL) { _, _ in validateInput() }
        .onAppear { validateInput() }
        .alert("Setup", isPresented: $showingAlert) {
            Button("OK") { }
        } message: {
            Text(alertMessage)
        }
    }
    
    private func validateInput() {
        let ngrokValid = !ngrokURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
                        ngrokURL.contains("ngrok")
        
        let zapierValid = !zapierWebhookURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
                         zapierWebhookURL.contains("hooks.zapier.com")
        
        isValid = ngrokValid && zapierValid
    }
    
    private func completeSetup() {
        do {
            let cleanNgrokURL = ngrokURL.trimmingCharacters(in: .whitespacesAndNewlines)
            let cleanZapierURL = zapierWebhookURL.trimmingCharacters(in: .whitespacesAndNewlines)
            
            // Save NGrok URL
            try SlackerConfig.shared.setNgrokStaticURL(cleanNgrokURL)
            
            // Save Zapier webhook URL
            try SlackerConfig.shared.setZapierWebhookURL(cleanZapierURL)
            
            alertMessage = "Setup completed successfully! SlackSassin is now configured."
            showingAlert = true
            
            // Dismiss after alert
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                isPresented = false
            }
            
        } catch {
            alertMessage = "Setup failed: \(error.localizedDescription)"
            showingAlert = true
        }
    }
}

#Preview {
    SlackSassinSetupSheet(isPresented: .constant(true))
} 