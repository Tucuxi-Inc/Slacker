//
//  SlackerApp.swift
//  Slacker
//
//  Created by Kevin Hermawan on 03/11/23.
//

import Defaults
import SwiftUI
import SwiftData
import Foundation
import Network

// Navigation modes for the app
enum AppViewMode {
    case slackOff  // Primary: Slack message processing
    case chat      // Secondary: Traditional AI chat
}

@main
struct SlackerApp: App {
    @State private var chatViewModel: ChatViewModel
    @State private var messageViewModel: MessageViewModel
    @State private var slackMessageViewModel: SlackMessageViewModel
    @State private var codeHighlighter: CodeHighlighter
    @State private var webhookServer: SlackerWebhookServer
    @State private var ngrokManager: NGrokManager
    
    // Navigation state for SlackOff vs Chat modes
    @State private var currentView: AppViewMode = .slackOff
    
    // Setup flow state
    @State private var showingSetup: Bool = false
    
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([Chat.self, Message.self, SlackMessage.self])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        
        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()
    
    init() {
        let modelContext = sharedModelContainer.mainContext
        
        let chatViewModel = ChatViewModel(modelContext: modelContext)
        let messageViewModel = MessageViewModel(modelContext: modelContext)
        let slackMessageViewModel = SlackMessageViewModel(modelContext: modelContext)
        let codeHighlighter = CodeHighlighter(colorScheme: .light, fontSize: Defaults[.fontSize], enabled: Defaults[.experimentalCodeHighlighting])
        let webhookServer = SlackerWebhookServer(modelContext: modelContext)
        let ngrokManager = NGrokManager.shared
        
        self._chatViewModel = State(initialValue: chatViewModel)
        self._messageViewModel = State(initialValue: messageViewModel)
        self._slackMessageViewModel = State(initialValue: slackMessageViewModel)
        self._codeHighlighter = State(initialValue: codeHighlighter)
        self._webhookServer = State(initialValue: webhookServer)
        self._ngrokManager = State(initialValue: ngrokManager)
    }
    
    var body: some Scene {
        WindowGroup {
            // TODO: Add SlackOffView once it's added to Xcode project
            // For now, showing AppView with navigation button to switch modes
            AppView(currentView: $currentView)
                .environment(chatViewModel)
                .environment(messageViewModel)
                .environment(slackMessageViewModel)
                .environment(codeHighlighter)
                .environment(webhookServer)
                .environment(ngrokManager)
                .onAppear {
                    // Check for SlackSassin configuration on startup
                    checkConfiguration()
                    
                    // Auto-start the webhook server
                    webhookServer.startServer()
                    
                    // Check for external NGrok tunnel (don't try to start automatically)
                    Task {
                        await ngrokManager.checkExternalTunnel()
                    }
                    
                    // Print debug info after startup
                    DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                        print("\n🔧 ===== SLACKSASSIN STARTUP STATUS =====")
                        
                        // Configuration status
                        let isConfigured = SlackerConfig.shared.isConfigured()
                        if isConfigured {
                            print("✅ SlackSassin configuration complete!")
                            if let zapierURL = SlackerConfig.shared.getZapierWebhookURL() {
                                print("🔗 Zapier webhook configured")
                            }
                            if let ngrokURL = SlackerConfig.shared.getNgrokStaticURL() {
                                print("🌐 NGrok URL configured: \(ngrokURL)")
                            }
                        } else {
                            print("⚠️ SlackSassin configuration incomplete - setup required")
                        }
                        
                        // Webhook server status
                        if webhookServer.isRunning {
                            print("✅ SlackerWebhookServer is running!")
                            print("📍 Local URLs:")
                            print("   Health: http://localhost:8080/health")
                            print("   Status: http://localhost:8080/status")
                            print("   Webhook: http://localhost:8080/zapier-webhook (POST)")
                        } else {
                            print("❌ SlackerWebhookServer failed to start")
                            if let error = webhookServer.lastError {
                                print("   Error: \(error)")
                            }
                        }
                        
                        // NGrok tunnel status
                        if ngrokManager.isRunning {
                            print("✅ NGrok tunnel is detected!")
                            if let tunnelURL = ngrokManager.tunnelURL {
                                print("🌐 NGrok URLs:")
                                print("   Health: \(tunnelURL)/health")
                                print("   Status: \(tunnelURL)/status")
                                print("   Webhook: \(tunnelURL)/zapier-webhook (POST)")
                            }
                        } else {
                            print("❌ NGrok tunnel not detected")
                            if let ngrokURL = SlackerConfig.shared.getNgrokStaticURL() {
                                print("💡 Manual setup: Run 'ngrok http --url=\(ngrokURL) 8080' in Terminal")
                            } else {
                                print("💡 Configure NGrok URL in setup first")
                            }
                        }
                        
                        print("🏁 SlackSassin startup complete!\n")
                    }
                }
                .sheet(isPresented: $showingSetup) {
                    SlackSassinSetupSheet(isPresented: $showingSetup)
                }
                .onDisappear {
                    // Clean shutdown
                    print("🛑 SlackSassin shutting down...")
                    webhookServer.stopServer()
                    ngrokManager.stopTunnel()
                }
        }
        .modelContainer(sharedModelContainer)
        .windowResizability(.contentSize)
        .windowToolbarStyle(.unified(showsTitle: false))
        .commands {
            CommandGroup(replacing: .appInfo) {
                Button("About Slacker") {
                    NSApplication.shared.orderFrontStandardAboutPanel(
                        options: [
                            NSApplication.AboutPanelOptionKey.credits: NSAttributedString(
                                string: "A simple macOS app for Ollama",
                                attributes: [
                                    NSAttributedString.Key.font: NSFont.systemFont(ofSize: 11),
                                    NSAttributedString.Key.foregroundColor: NSColor.secondaryLabelColor
                                ]
                            ),
                            NSApplication.AboutPanelOptionKey.applicationName: "Slacker",
                            NSApplication.AboutPanelOptionKey.applicationVersion: Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "",
                            NSApplication.AboutPanelOptionKey.version: ""
                        ]
                    )
                }
            }
            
            CommandGroup(replacing: .help) {
                if let url = URL(string: "https://github.com/Tucuxi-Inc/Slacker") {
                    Link("Slacker Help", destination: url)
                }
            }
        }
        .defaultSize(CGSize(width: 1024, height: 768))
    }
    
    private func checkConfiguration() {
        let isConfigured = SlackerConfig.shared.isConfigured()
        let hasNgrokURL = SlackerConfig.shared.getNgrokStaticURL() != nil
        
        if !isConfigured || !hasNgrokURL {
            // Show setup sheet if either Zapier webhook or NGrok URL is missing
            showingSetup = true
        }
    }
}
