//
//  SlackerWebhookServer.swift
//  Slacker
//
//  Created by SlackSassin Integration
//

import Foundation
import Network
import SwiftData

@MainActor
@Observable
class SlackerWebhookServer {
    private var port: UInt16 { UInt16(SlackerConfig.shared.getWebhookServerPort()) }
    private var listener: NWListener?
    
    var isRunning: Bool = false
    var lastError: String?
    var messagesReceived: Int = 0
    var lastMessageReceived: Date?
    var connectionCount: Int = 0
    
    // Published properties for UI
    var serverStartTime: Date?
    var lastRequestTime: Date?
    
    // SwiftData ModelContext for database operations
    private let modelContext: ModelContext
    
    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }
    
    private func logDebug(_ message: String) {
        let timestamp = DateFormatter.timeFormatter.string(from: Date())
        print("🔧 SlackerWebhookServer: [\(timestamp)] \(message)")
    }
    
    func startServer() {
        guard !isRunning else { return }
        
        do {
            listener = try NWListener(using: .tcp, on: NWEndpoint.Port(rawValue: port)!)
            
            listener?.stateUpdateHandler = { [weak self] state in
                Task { @MainActor in
                    switch state {
                    case .ready:
                        self?.isRunning = true
                        self?.lastError = nil
                        self?.serverStartTime = Date()
                        self?.logDebug("🚀 SlackerWebhookServer STARTED successfully")
                        self?.logDebug("📍 Local Server: http://localhost:\(self?.port ?? 8080)")
                        self?.logDebug("🔗 Webhook Endpoint: /zapier-webhook")
                        self?.logDebug("🩺 Health Check: /health")
                        self?.logDebug("📊 Status Check: /status")
                        self?.logDebug("🧪 Test Response: /test-response (POST)")
                        print("🚀 Slacker webhook server started on port \(self?.port ?? 8080)")
                        
                    case .failed(let error):
                        self?.isRunning = false
                        self?.lastError = error.localizedDescription
                        print("❌ Webhook server failed: \(error)")
                        
                    default:
                        break
                    }
                }
            }
            
            listener?.newConnectionHandler = { [weak self] connection in
                Task { @MainActor in
                    self?.handleConnection(connection)
                }
            }
            
            listener?.start(queue: .global(qos: .background))
            
        } catch {
            self.lastError = error.localizedDescription
            print("❌ Failed to start webhook server: \(error)")
        }
    }
    
    func stopServer() {
        listener?.cancel()
        listener = nil
        isRunning = false
        print("⏹️ Slacker webhook server stopped")
    }
    
    private func handleConnection(_ connection: NWConnection) {
        connection.stateUpdateHandler = { state in
            Task { @MainActor in
                switch state {
                case .ready:
                    self.connectionCount += 1
                case .cancelled:
                    self.connectionCount = max(0, self.connectionCount - 1)
                default:
                    break
                }
            }
        }
        
        connection.start(queue: .global(qos: .background))
        
        // Read HTTP request
        connection.receive(minimumIncompleteLength: 1, maximumLength: 65536) { data, _, isComplete, error in
            if let data = data, !data.isEmpty {
                Task { @MainActor in
                    self.processHTTPRequest(data: data, connection: connection)
                }
            }
            
            if isComplete {
                connection.cancel()
            }
        }
    }
    
    private func processHTTPRequest(data: Data, connection: NWConnection) {
        guard let requestString = String(data: data, encoding: .utf8) else {
            logDebug("❌ Invalid request encoding")
            sendHTTPResponse(connection: connection, status: 400, body: "Invalid request")
            return
        }
        
        let lines = requestString.components(separatedBy: "\r\n")
        guard let firstLine = lines.first else {
            logDebug("❌ Invalid HTTP request format")
            sendHTTPResponse(connection: connection, status: 400, body: "Invalid request")
            return
        }
        
        let components = firstLine.components(separatedBy: " ")
        guard components.count >= 2 else {
            logDebug("❌ Invalid HTTP request line: \(firstLine)")
            sendHTTPResponse(connection: connection, status: 400, body: "Invalid request")
            return
        }
        
        let method = components[0]
        let path = components[1]
        
        // Log incoming request
        logDebug("📥 Incoming Request: \(method) \(path)")
        
        // Update last request time
        lastRequestTime = Date()
        
        // Route the request
        switch (method, path) {
        case ("POST", "/zapier-webhook"):
            logDebug("🎯 Routing to Zapier webhook handler")
            handleZapierWebhook(data: data, connection: connection)
            
        case ("GET", "/health"):
            logDebug("🩺 Routing to health check handler")
            handleHealthCheck(connection: connection)
            
        case ("GET", "/status"):
            logDebug("📊 Routing to status check handler")
            handleStatusCheck(connection: connection)
            
        case ("POST", "/test-response"):
            logDebug("🧪 Routing to test response handler")
            handleTestResponse(connection: connection)
            
        default:
            logDebug("❓ Unknown route: \(method) \(path)")
            sendHTTPResponse(connection: connection, status: 404, body: "Not Found")
        }
    }
    
    private func handleZapierWebhook(data: Data, connection: NWConnection) {
        logDebug("🔄 Processing Zapier webhook...")
        
        // Extract JSON from HTTP body
        guard let jsonData = extractJSONFromHTTPRequest(data) else {
            logDebug("❌ Failed to extract JSON from HTTP request")
            sendHTTPResponse(connection: connection, status: 400, body: "No JSON body found")
            return
        }
        
        logDebug("📄 JSON payload size: \(jsonData.count) bytes")
        
        do {
            // Parse the updated Zapier payload
            let zapierPayload = try JSONDecoder().decode(ZapierPayload.self, from: jsonData)
            logDebug("✅ Successfully decoded ZapierPayload")
            logDebug("👤 User: \(zapierPayload.user.realName) (\(zapierPayload.user.name))")
            logDebug("📢 Channel: #\(zapierPayload.channel.name)")
            logDebug("💬 Message: \(String(zapierPayload.text.prefix(50)))...")
            
            // Create SlackMessage from the payload
            let message = SlackMessage(from: zapierPayload)
            logDebug("✅ Created SlackMessage with ID: \(message.id)")
            
            // Save to database
            modelContext.insert(message)
            try modelContext.save()
            
            messagesReceived += 1
            lastMessageReceived = Date()
            NotificationCenter.default.post(name: .newSlackMessageReceived, object: message)
            
            logDebug("✅ Slack message saved to database successfully")
            print("✅ New Slack message: \(message.text)")
            
            // Send success response
            let responseData = [
                "status": "received",
                "message_id": message.id.uuidString,
                "timestamp": Date().timeIntervalSince1970,
                "user": zapierPayload.user.realName,
                "channel": zapierPayload.channel.name
            ] as [String : Any]
            
            let responseJSON = try JSONSerialization.data(withJSONObject: responseData)
            let responseString = String(data: responseJSON, encoding: .utf8) ?? ""
            
            logDebug("📤 Sending success response to Zapier")
            sendHTTPResponse(connection: connection, status: 200, body: responseString, contentType: "application/json")
            
        } catch {
            logDebug("❌ Failed to decode ZapierPayload from JSON")
            if let jsonString = String(data: jsonData, encoding: .utf8) {
                logDebug("📄 Raw JSON: \(jsonString)")
            }
            logDebug("❌ Error: \(error.localizedDescription)")
            sendHTTPResponse(connection: connection, status: 400, body: "Invalid JSON payload: \(error.localizedDescription)")
        }
    }
    
    private func handleHealthCheck(connection: NWConnection) {
        let health = [
            "status": "healthy",
            "timestamp": Date().timeIntervalSince1970,
            "port": port
        ] as [String: Any]
        
        if let jsonData = try? JSONSerialization.data(withJSONObject: health),
           let jsonString = String(data: jsonData, encoding: .utf8) {
            sendHTTPResponse(connection: connection, status: 200, body: jsonString, contentType: "application/json")
        } else {
            sendHTTPResponse(connection: connection, status: 500, body: "Internal Error")
        }
    }
    
    private func handleStatusCheck(connection: NWConnection) {
        let uptime = serverStartTime.map { Date().timeIntervalSince($0) } ?? 0
        
        let status = [
            "server": "running",
            "version": "1.0.0",
            "port": port,
            "messages_received": messagesReceived,
            "connections": connectionCount,
            "uptime_seconds": uptime,
            "started_at": serverStartTime?.timeIntervalSince1970 ?? 0,
            "last_request": lastRequestTime?.timeIntervalSince1970 ?? 0,
            "zapier_response_url": SlackerConfig.shared.getZapierWebhookURL() ?? "Not configured",
            "endpoints": [
                "/zapier-webhook (POST)",
                "/health (GET)",
                "/status (GET)",
                "/test-response (POST)"
            ]
        ] as [String: Any]
        
        logDebug("📊 Status check requested - Messages: \(messagesReceived), Uptime: \(Int(uptime))s")
        
        if let jsonData = try? JSONSerialization.data(withJSONObject: status),
           let jsonString = String(data: jsonData, encoding: .utf8) {
            sendHTTPResponse(connection: connection, status: 200, body: jsonString, contentType: "application/json")
        } else {
            logDebug("❌ Failed to serialize status JSON")
            sendHTTPResponse(connection: connection, status: 500, body: "Internal Error")
        }
    }
    
    private func handleTestResponse(connection: NWConnection) {
        logDebug("🧪 Test response endpoint called")
        
        // Create a sample response payload
        let testPayload = ZapierResponsePayload(
            messageId: "test-\(UUID().uuidString)",
            responseText: "This is a test response from SlackSassin! 🤖 The webhook integration is working correctly.",
            channel: "C07976L66R4", // Using the channel from your example
            threadId: nil,
            originalMessageText: "Test message for webhook validation",
            userIdMention: "U079DR500BC" // Using the user ID from your example
        )
        
        // Send to Zapier webhook asynchronously
        Task {
            let success = await sendResponseToZapier(testPayload)
            
            let responseData = [
                "test_sent": success,
                "zapier_url": await SlackerConfig.shared.getZapierWebhookURL() ?? "Not configured",
                "message": success ? "Test response sent successfully!" : "Failed to send test response"
            ] as [String : Any]
            
            await MainActor.run {
                do {
                    let jsonData = try JSONSerialization.data(withJSONObject: responseData)
                    let jsonString = String(data: jsonData, encoding: .utf8) ?? ""
                    self.sendHTTPResponse(connection: connection, status: success ? 200 : 500, body: jsonString, contentType: "application/json")
                } catch {
                    self.sendHTTPResponse(connection: connection, status: 500, body: "Failed to create response")
                }
            }
        }
    }
    
    // MARK: - Helper Methods
    
    private func extractJSONFromHTTPRequest(_ data: Data) -> Data? {
        guard let requestString = String(data: data, encoding: .utf8) else { return nil }
        
        // Find the JSON body after the HTTP headers
        let components = requestString.components(separatedBy: "\r\n\r\n")
        if components.count > 1 {
            let jsonString = components[1]
            return jsonString.data(using: .utf8)
        }
        
        return nil
    }
    
    private func sendHTTPResponse(connection: NWConnection, status: Int, body: String, contentType: String = "text/plain") {
        let response = """
            HTTP/1.1 \(status) \(HTTPStatus.message(for: status))\r
            Content-Type: \(contentType)\r
            Content-Length: \(body.utf8.count)\r
            Access-Control-Allow-Origin: *\r
            Access-Control-Allow-Methods: GET, POST, OPTIONS\r
            \r
            \(body)
            """
        
        guard let responseData = response.data(using: .utf8) else {
            connection.cancel()
            return
        }
        
        connection.send(content: responseData, completion: .contentProcessed { error in
            if let error = error {
                print("❌ Send error: \(error)")
            }
            connection.cancel()
        })
    }
    
    // MARK: - Response Sending to Zapier
    
    func sendResponseToZapier(_ payload: ZapierResponsePayload) async -> Bool {
        // Get configured webhook URL
        guard let zapierWebhookURL = await SlackerConfig.shared.getZapierWebhookURL() else {
            await MainActor.run {
                logDebug("❌ Zapier webhook URL not configured")
            }
            return false
        }
        
        await MainActor.run {
            logDebug("📤 Sending response to Zapier webhook...")
            logDebug("🔗 Zapier URL: \(zapierWebhookURL)")
            logDebug("💬 Response: \(String(payload.responseText.prefix(50)))...")
        }
        
        guard let url = URL(string: zapierWebhookURL) else {
            await MainActor.run {
                logDebug("❌ Invalid Zapier webhook URL")
            }
            return false
        }
        
        do {
            let jsonData = try JSONEncoder().encode(payload)
            
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.setValue("SlackSassin-Webhook/1.0", forHTTPHeaderField: "User-Agent")
            request.httpBody = jsonData
            
            let (data, response) = try await URLSession.shared.data(for: request)
            
            if let httpResponse = response as? HTTPURLResponse {
                await MainActor.run {
                    logDebug("📡 Zapier response status: \(httpResponse.statusCode)")
                }
                
                if 200...299 ~= httpResponse.statusCode {
                    await MainActor.run {
                        logDebug("✅ Response sent successfully to Zapier")
                        
                        if let responseString = String(data: data, encoding: .utf8) {
                            logDebug("📄 Zapier response: \(responseString)")
                        }
                    }
                    return true
                } else {
                    await MainActor.run {
                        logDebug("❌ Zapier webhook returned error status: \(httpResponse.statusCode)")
                        
                        if let responseString = String(data: data, encoding: .utf8) {
                            logDebug("📄 Error response: \(responseString)")
                        }
                    }
                    return false
                }
            }
            
            return false
            
        } catch {
            await MainActor.run {
                logDebug("❌ Failed to send response to Zapier: \(error.localizedDescription)")
            }
            return false
        }
    }
    

}

// MARK: - HTTP Status Helper
struct HTTPStatus {
    static func message(for statusCode: Int) -> String {
        switch statusCode {
        case 200: return "OK"
        case 400: return "Bad Request"
        case 404: return "Not Found"
        case 500: return "Internal Server Error"
        default: return "Unknown"
        }
    }
}

// MARK: - Notification Names
extension Notification.Name {
    static let newSlackMessageReceived = Notification.Name("newSlackMessageReceived")
    static let slackMessageStatusUpdated = Notification.Name("slackMessageStatusUpdated")
}

// MARK: - Extensions
extension DateFormatter {
    static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss.SSS"
        return formatter
    }()
} 