//
//  NGrokManager.swift
//  Slacker
//
//  Created by SlackSassin Integration
//

import Foundation
import Combine

@MainActor @Observable
class NGrokManager {
    static let shared = NGrokManager()
    
    // Published properties for UI
    var isRunning: Bool = false
    var tunnelURL: String?
    var lastError: String?
    var ngrokProcess: Process?
    
    // Configuration
    private let staticURL = "relaxing-sensibly-ghost.ngrok-free.app"
    private let localPort = 8080
    
    private init() {}
    
    // MARK: - Public Methods
    
    func startTunnel() {
        guard !isRunning else { return }
        
        print("🔧 User requested NGrok tunnel start...")
        
        // First, check if NGrok is already running externally
        Task {
            await checkForExternalTunnel()
            
            // If external tunnel is found, don't try to start our own
            if self.isRunning {
                print("🔧 ✅ External NGrok tunnel detected, skipping local startup")
                return
            }
            
            // Only try to start if no external tunnel is detected
            await MainActor.run {
                self.attemptLocalNGrokStart()
            }
        }
    }
    
    private func attemptLocalNGrokStart() {
        // Check if NGrok is installed
        guard isNGrokInstalled() else {
            lastError = "NGrok is not installed. Please install NGrok: https://ngrok.com/download"
            print("❌ NGrok not found. Install with: brew install ngrok")
            return
        }
        
        // Try to start NGrok (will likely fail due to sandbox)
        print("🔧 Attempting to start NGrok locally (may fail due to sandbox restrictions)...")
        
        // Stop any existing tunnel
        stopTunnel()
        
        // Start new tunnel
        startNGrokProcess()
    }
    
    func stopTunnel() {
        ngrokProcess?.terminate()
        ngrokProcess?.waitUntilExit()
        ngrokProcess = nil
        
        self.isRunning = false
        self.tunnelURL = nil
        print("⏹️ NGrok tunnel stopped")
    }
    
    func checkExternalTunnel() async {
        await checkForExternalTunnel()
    }
    
    func getManualStartInstructions() -> String {
        return """
        Due to app sandbox restrictions, NGrok cannot be started automatically.
        
        Please run this command in Terminal:
        
        ngrok http --url=\(staticURL) \(localPort)
        
        Then click "Check for External Tunnel" to detect your running tunnel.
        """
    }
    
    // MARK: - Private Methods
    
    private func findNGrokPath() -> String? {
        print("🔧 Searching for NGrok executable...")
        
        // Check common NGrok installation paths
        let commonPaths = [
            "/usr/local/bin/ngrok",      // Homebrew Intel
            "/opt/homebrew/bin/ngrok",   // Homebrew Apple Silicon
            "/usr/bin/ngrok",            // System install
            "~/bin/ngrok"                // User install
        ]
        
        for path in commonPaths {
            let expandedPath = NSString(string: path).expandingTildeInPath
            print("🔧 Checking: \(expandedPath)")
            if FileManager.default.fileExists(atPath: expandedPath) {
                print("🔧 ✅ Found NGrok at: \(expandedPath)")
                return expandedPath
            } else {
                print("🔧 ❌ Not found at: \(expandedPath)")
            }
        }
        
        // Fallback: try which command with full PATH
        print("🔧 Trying 'which' command as fallback...")
        
        let process = Process()
        process.launchPath = "/bin/bash"
        process.arguments = ["-c", "export PATH=/usr/local/bin:/opt/homebrew/bin:/usr/bin:$PATH && which ngrok"]
        
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe
        
        do {
            try process.run()
            process.waitUntilExit()
            
            print("🔧 'which' command exit status: \(process.terminationStatus)")
            
            if process.terminationStatus == 0 {
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                if let output = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) {
                    print("🔧 ✅ Found NGrok via which: \(output)")
                    return output
                } else {
                    print("🔧 ❌ 'which' succeeded but no output")
                }
            } else {
                let errorData = pipe.fileHandleForReading.readDataToEndOfFile()
                if let errorOutput = String(data: errorData, encoding: .utf8) {
                    print("🔧 ❌ 'which' failed with: \(errorOutput)")
                }
            }
        } catch {
            print("🔧 Error running 'which' command: \(error)")
        }
        
        print("🔧 ❌ NGrok executable not found in any location")
        return nil
    }
    
    private func isNGrokInstalled() -> Bool {
        return findNGrokPath() != nil
    }
    
    private func startNGrokProcess() {
        ngrokProcess = Process()
        
        // Find the correct NGrok path
        guard let ngrokPath = findNGrokPath() else {
            self.lastError = "NGrok executable not found"
            print("❌ NGrok executable not found")
            return
        }
        
        // Use the static URL if available, otherwise use dynamic
        // If using container path, don't need to export PATH
        let command = if ngrokPath.contains("Application Support") {
            "\(ngrokPath) http --url=\(staticURL) \(localPort)"
        } else {
            "export PATH=/usr/local/bin:/opt/homebrew/bin:/usr/bin:$PATH && \(ngrokPath) http --url=\(staticURL) \(localPort)"
        }
        
        print("🔧 Executing NGrok command: \(command)")
        
        ngrokProcess?.launchPath = "/bin/bash"
        ngrokProcess?.arguments = ["-c", command]
        
        // Set up output pipes
        let outputPipe = Pipe()
        let errorPipe = Pipe()
        
        ngrokProcess?.standardOutput = outputPipe
        ngrokProcess?.standardError = errorPipe
        
        // Monitor output
        outputPipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            if let output = String(data: data, encoding: .utf8) {
                Task { @MainActor in
                    self?.parseNGrokOutput(output)
                }
            }
        }
        
        errorPipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            if let error = String(data: data, encoding: .utf8) {
                Task { @MainActor in
                    self?.handleNGrokError(error)
                }
            }
        }
        
        // Set up termination handler
        ngrokProcess?.terminationHandler = { [weak self] process in
            Task { @MainActor in
                self?.isRunning = false
                if process.terminationStatus != 0 {
                    let status = process.terminationStatus
                    if status == 126 {
                        // Permission denied
                        self?.lastError = "App sandbox prevents NGrok execution. Please start NGrok manually: 'ngrok http --url=\(self?.staticURL ?? "YOUR_URL") \(self?.localPort ?? 8080)'"
                        print("❌ NGrok blocked by sandbox (status 126)")
                        print("💡 Manual command: ngrok http --url=\(self?.staticURL ?? "YOUR_URL") \(self?.localPort ?? 8080)")
                    } else {
                        self?.lastError = "NGrok process terminated with status \(status)"
                        print("❌ NGrok process failed with status \(status)")
                    }
                    
                    // Check if NGrok is running externally
                    await self?.checkForExternalTunnel()
                }
            }
        }
        
        // Start the process
        do {
            try ngrokProcess?.run()
            
            self.isRunning = true
            self.lastError = nil
            self.tunnelURL = "https://\(self.staticURL)"
            print("🚀 Starting NGrok tunnel...")
            print("🌐 Tunnel URL: https://\(self.staticURL)")
            
        } catch {
            self.lastError = "App sandbox prevents NGrok execution. Please start NGrok manually: 'ngrok http --url=\(self.staticURL) \(self.localPort)'"
            print("❌ Failed to start NGrok due to sandbox restrictions")
            print("💡 Manual command: ngrok http --url=\(self.staticURL) \(self.localPort)")
            
            // Check if NGrok is already running externally
            Task {
                await self.checkForExternalTunnel()
            }
        }
    }
    
    private func parseNGrokOutput(_ output: String) {
        // Parse NGrok output to extract tunnel URL and status
        let lines = output.components(separatedBy: .newlines)
        
        for line in lines {
            if line.contains("started tunnel") || line.contains("url=") {
                print("🔧 NGrok: \(line)")
                
                // Extract URL if different from static URL
                if line.contains("url=https://") {
                    let components = line.components(separatedBy: "url=https://")
                    if components.count > 1 {
                        let urlPart = components[1].components(separatedBy: " ")[0]
                        Task { @MainActor in
                            self.tunnelURL = "https://\(urlPart)"
                        }
                    }
                }
            }
            
            if line.contains("tunnel session started") {
                Task { @MainActor in
                    self.isRunning = true
                    self.lastError = nil
                    print("✅ NGrok tunnel established successfully")
                }
            }
        }
    }
    
    private func handleNGrokError(_ error: String) {
        print("🔧 NGrok Error: \(error)")
        
        if error.contains("failed to start tunnel") {
            Task { @MainActor in
                self.lastError = "Failed to start tunnel - URL may be in use"
                self.isRunning = false
            }
        } else if error.contains("authentication failed") {
            Task { @MainActor in
                self.lastError = "NGrok authentication failed - check your auth token"
                self.isRunning = false
            }
        } else if error.contains("tunnel not found") {
            Task { @MainActor in
                self.lastError = "Reserved tunnel URL not found - using dynamic URL"
                // Try with dynamic URL
                self.startDynamicTunnel()
            }
        }
    }
    
    private func startDynamicTunnel() {
        // Fallback to dynamic URL if static URL fails
        ngrokProcess?.terminate()
        ngrokProcess = Process()
        
        // Find the correct NGrok path
        guard let ngrokPath = findNGrokPath() else {
            Task { @MainActor in
                self.lastError = "NGrok executable not found for dynamic tunnel"
                print("❌ NGrok executable not found for dynamic tunnel")
            }
            return
        }
        
        let command = if ngrokPath.contains("Application Support") {
            "\(ngrokPath) http \(localPort) --log=stdout"
        } else {
            "export PATH=/usr/local/bin:/opt/homebrew/bin:/usr/bin:$PATH && \(ngrokPath) http \(localPort) --log=stdout"
        }
        
        ngrokProcess?.launchPath = "/bin/bash"
        ngrokProcess?.arguments = ["-c", command]
        
        // Set up pipes again
        let outputPipe = Pipe()
        ngrokProcess?.standardOutput = outputPipe
        
        outputPipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            if let output = String(data: data, encoding: .utf8) {
                Task { @MainActor in
                    self?.parseNGrokOutput(output)
                }
            }
        }
        
        do {
            try ngrokProcess?.run()
            print("🔄 Falling back to dynamic NGrok tunnel...")
        } catch {
            Task { @MainActor in
                self.lastError = "Failed to start dynamic tunnel: \(error.localizedDescription)"
                print("❌ Failed to start dynamic NGrok tunnel: \(error)")
            }
        }
    }
    
    // MARK: - Public Utility Methods
    
    func getStatus() -> [String: Any] {
        return [
            "is_running": isRunning,
            "tunnel_url": tunnelURL ?? "None",
            "last_error": lastError ?? "None",
            "static_url": staticURL,
            "local_port": localPort,
            "ngrok_installed": isNGrokInstalled(),
            "ngrok_path": findNGrokPath() ?? "Not found"
        ]
    }
    
    /// Debug method to find NGrok location manually
    func debugNGrokLocation() {
        print("🔧 ===== NGROK DEBUG INFO =====")
        print("🔧 Current PATH: \(ProcessInfo.processInfo.environment["PATH"] ?? "Not set")")
        
        // Check if ngrok is in PATH
        let whichResult = shell("which ngrok")
        print("🔧 'which ngrok' result: \(whichResult)")
        
        // Check container path first
        let containerPath = getContainerNGrokPath()
        let containerExists = FileManager.default.fileExists(atPath: containerPath)
        print("🔧 \(containerPath): \(containerExists ? "✅ EXISTS" : "❌ Missing")")
        
        // Check common paths
        let commonPaths = [
            "/usr/local/bin/ngrok",
            "/opt/homebrew/bin/ngrok", 
            "/usr/bin/ngrok",
            "~/bin/ngrok"
        ]
        
        for path in commonPaths {
            let expandedPath = NSString(string: path).expandingTildeInPath
            let exists = FileManager.default.fileExists(atPath: expandedPath)
            print("🔧 \(expandedPath): \(exists ? "✅ EXISTS" : "❌ Missing")")
        }
        
        // Try to find it manually
        let findResult = shell("find /usr -name ngrok -type f 2>/dev/null")
        print("🔧 'find /usr -name ngrok' result: \(findResult)")
        
        let brewResult = shell("brew --prefix 2>/dev/null")
        print("🔧 Homebrew prefix: \(brewResult)")
        
        print("🔧 ===== END DEBUG INFO =====")
    }
    
    private func shell(_ command: String) -> String {
        let process = Process()
        process.launchPath = "/bin/bash"
        process.arguments = ["-c", command]
        
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe
        
        do {
            try process.run()
            process.waitUntilExit()
            
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            return String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "No output"
        } catch {
            return "Error: \(error)"
        }
    }
    
    // MARK: - External NGrok Detection
    
    private func checkExternalNGrokTunnel() async -> Bool {
        await checkForExternalTunnel()
        return isRunning
    }
    
    private func checkForExternalTunnel() async {
        print("🔧 Checking for external NGrok tunnel...")
        
        // Try to connect to the expected tunnel URL
        do {
            let url = URL(string: "https://\(staticURL)")!
            let request = URLRequest(url: url, timeoutInterval: 10.0)
            let (_, response) = try await URLSession.shared.data(for: request)
            
            if let httpResponse = response as? HTTPURLResponse {
                // Check for NGrok-specific headers to confirm it's actually NGrok
                let hasNGrokHeaders = httpResponse.allHeaderFields.keys.contains { key in
                    if let keyString = key as? String {
                        return keyString.lowercased().contains("ngrok")
                    }
                    return false
                }
                
                if hasNGrokHeaders {
                    self.isRunning = true
                    self.tunnelURL = "https://\(self.staticURL)"
                    self.lastError = nil
                    print("🔧 ✅ External NGrok tunnel detected and working!")
                    print("🌐 Tunnel URL: https://\(self.staticURL)")
                    print("🔧 Response status: \(httpResponse.statusCode)")
                    
                    // Print NGrok-specific headers for debugging
                    for (key, value) in httpResponse.allHeaderFields {
                        if let keyString = key as? String, keyString.lowercased().contains("ngrok") {
                            print("🔧 NGrok header: \(keyString) = \(value)")
                        }
                    }
                    return
                }
            }
        } catch {
            // NGrok might not be running, or network error
            print("🔧 No external NGrok tunnel detected: \(error.localizedDescription)")
        }
        
        // If we get here, NGrok is not running externally
        self.isRunning = false
        self.tunnelURL = nil
        self.lastError = "NGrok not running. Please start manually: 'ngrok http --url=\(self.staticURL) \(self.localPort)'"
        print("🔧 ❌ No external NGrok tunnel found")
    }
    
    // MARK: - Container NGrok Management
    
    private func getContainerNGrokPath() -> String {
        let containerURL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let binURL = containerURL.appendingPathComponent("bin")
        return binURL.appendingPathComponent("ngrok").path
    }
    
    private func copyNGrokToContainer(from sourcePath: String) -> Bool {
        let containerPath = getContainerNGrokPath()
        let containerDir = URL(fileURLWithPath: containerPath).deletingLastPathComponent()
        
        do {
            // Create bin directory if it doesn't exist
            try FileManager.default.createDirectory(at: containerDir, withIntermediateDirectories: true)
            
            // Remove existing ngrok if present
            if FileManager.default.fileExists(atPath: containerPath) {
                try FileManager.default.removeItem(atPath: containerPath)
            }
            
            // Copy NGrok to container
            try FileManager.default.copyItem(atPath: sourcePath, toPath: containerPath)
            
            // Make it executable
            try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: containerPath)
            
            print("🔧 ✅ NGrok copied to container: \(containerPath)")
            return true
        } catch {
            print("🔧 ❌ Failed to copy NGrok to container: \(error)")
            return false
        }
    }
    
    func testTunnel() async -> Bool {
        guard let tunnelURL = tunnelURL else { return false }
        
        do {
            let url = URL(string: "\(tunnelURL)/health")!
            let (_, response) = try await URLSession.shared.data(from: url)
            
            if let httpResponse = response as? HTTPURLResponse {
                return httpResponse.statusCode == 200
            }
            return false
        } catch {
            print("❌ Tunnel test failed: \(error)")
            return false
        }
    }
} 