//
//  SlackerApp.swift
//  Slacker
//
//  Created by Kevin Hermawan on 03/11/23.
//

import Defaults
import SwiftUI
import SwiftData

@main
struct SlackerApp: App {
    @State private var chatViewModel: ChatViewModel
    @State private var messageViewModel: MessageViewModel
    @State private var codeHighlighter: CodeHighlighter
    
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([Chat.self, Message.self])
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
        let codeHighlighter = CodeHighlighter(colorScheme: .light, fontSize: Defaults[.fontSize], enabled: Defaults[.experimentalCodeHighlighting])
        
        self._chatViewModel = State(initialValue: chatViewModel)
        self._messageViewModel = State(initialValue: messageViewModel)
        self._codeHighlighter = State(initialValue: codeHighlighter)
    }
    
    var body: some Scene {
        WindowGroup {
            AppView()
                .environment(chatViewModel)
                .environment(messageViewModel)
                .environment(codeHighlighter)
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
}
