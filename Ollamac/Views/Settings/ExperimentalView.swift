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
                NGrokStatusView()
            } header: {
                Text("NGrok Tunnel")
            } footer: {
                SectionFooter("External tunnel service for webhook connectivity.")
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
