//
//  SlackerWebhookServer.swift
//  Slacker
//
//  Created by SlackSassin Integration
//

import Foundation
import Network
import SwiftData

@Observable
class SlackerWebhookServer {
    private let port: UInt16 = 8080
    private var listener: NWListener?
    
    // Published properties for UI
    var isRunning: Bool = false
    var lastError: String?
    var connectionCount: Int = 0
    var messagesReceived: Int = 0
    
    // Model context for database operations
    private let modelContext: ModelContext
    
    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }
    
    func startServer() {
        guard !isRunning else { return }
        
        do {
            listener = try NWListener(using: .tcp, on: NWEndpoint.Port(rawValue: port)!)
            
            listener?.stateUpdateHandler = { [weak self] state in
                DispatchQueue.main.async {
                    switch state {
                    case .ready:
                        self?.isRunning = true
                        self?.lastError = nil
                        print("🚀 Slacker webhook server started on port \(self?.port ?? 8080)")
                        print("📡 NGrok URL: https://relaxing-sensibly-ghost.ngrok-free.app")
                        
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
                self?.handleConnection(connection)
            }
            
            listener?.start(queue: .global(qos: .background))
            
        } catch {
            DispatchQueue.main.async {
                self.lastError = error.localizedDescription
                print("❌ Failed to start webhook server: \(error)")
            }
        }
    }
    
    func stopServer() {
        listener?.cancel()
        listener = nil
        
        DispatchQueue.main.async {
            self.isRunning = false
            print("⏹️ Slacker webhook server stopped")
        }
    }
    
    private func handleConnection(_ connection: NWConnection) {
        connection.stateUpdateHandler = { state in
            switch state {
            case .ready:
                DispatchQueue.main.async {
                    self.connectionCount += 1
                }
            case .cancelled:
                DispatchQueue.main.async {
                    self.connectionCount = max(0, self.connectionCount - 1)
                }
            default:
                break
            }
        }
        
        connection.start(queue: .global(qos: .background))
        
        // Read HTTP request
        connection.receive(minimumIncompleteLength: 1, maximumLength: 65536) { [weak self] data, _, isComplete, error in
            if let data = data, !data.isEmpty {
                self?.processHTTPRequest(data: data, connection: connection)
            }
            
            if isComplete {
                connection.cancel()
            }
        }
    }
    
    private func processHTTPRequest(data: Data, connection: NWConnection) {
        guard let requestString = String(data: data, encoding: .utf8) else {
            sendHTTPResponse(connection: connection, status: 400, body: "Invalid request")
            return
        }
        
        let lines = requestString.components(separatedBy: "\r\n")
        guard let firstLine = lines.first else {
            sendHTTPResponse(connection: connection, status: 400, body: "Invalid request")
            return
        }
        
        let components = firstLine.components(separatedBy: " ")
        guard components.count >= 2 else {
            sendHTTPResponse(connection: connection, status: 400, body: "Invalid request")
            return
        }
        
        let method = components[0]
        let path = components[1]
        
        // Route the request
        switch (method, path) {
        case ("POST", "/zapier-webhook"):
            handleZapierWebhook(data: data, connection: connection)
            
        case ("GET", "/health"):
            handleHealthCheck(connection: connection)
            
        case ("GET", "/status"):
            handleStatusCheck(connection: connection)
            
        case ("POST", "/response-confirmation"):
            handleResponseConfirmation(data: data, connection: connection)
            
        default:
            sendHTTPResponse(connection: connection, status: 404, body: "Not Found")
        }
    }
    
    private func handleZapierWebhook(data: Data, connection: NWConnection) {
        // Extract JSON from HTTP body
        guard let jsonData = extractJSONFromHTTPRequest(data),
              let zapierPayload = try? JSONDecoder().decode(ZapierPayload.self, from: jsonData) else {
            sendHTTPResponse(connection: connection, status: 400, body: "Invalid JSON payload")
            return
        }
        
        // Create SlackMessage from Zapier payload
        let slackMessage = SlackMessage(from: zapierPayload)
        
        // Save to database
        do {
            modelContext.insert(slackMessage)
            try modelContext.save()
            
            DispatchQueue.main.async {
                self.messagesReceived += 1
                NotificationCenter.default.post(name: .newSlackMessageReceived, object: slackMessage)
            }
            
            print("✅ Slack message saved: \(slackMessage.text)")
            
            // Send success response
            let response = WebhookResponse(status: "received", messageId: slackMessage.id.uuidString)
            let responseData = try JSONEncoder().encode(response)
            let responseString = String(data: responseData, encoding: .utf8) ?? ""
            
            sendHTTPResponse(connection: connection, status: 200, body: responseString, contentType: "application/json")
            
        } catch {
            print("❌ Failed to save Slack message: \(error)")
            sendHTTPResponse(connection: connection, status: 500, body: "Failed to save message")
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
        let status = [
            "server": "running",
            "version": "1.0.0",
            "ngrok_url": "https://relaxing-sensibly-ghost.ngrok-free.app",
            "messages_received": messagesReceived,
            "connections": connectionCount
        ] as [String: Any]
        
        if let jsonData = try? JSONSerialization.data(withJSONObject: status),
           let jsonString = String(data: jsonData, encoding: .utf8) {
            sendHTTPResponse(connection: connection, status: 200, body: jsonString, contentType: "application/json")
        } else {
            sendHTTPResponse(connection: connection, status: 500, body: "Internal Error")
        }
    }
    
    private func handleResponseConfirmation(data: Data, connection: NWConnection) {
        // Handle response confirmation from Zapier after sending to Slack
        guard let jsonData = extractJSONFromHTTPRequest(data),
              let confirmation = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any],
              let messageIdString = confirmation["messageId"] as? String,
              let messageId = UUID(uuidString: messageIdString),
              let status = confirmation["status"] as? String else {
            sendHTTPResponse(connection: connection, status: 400, body: "Invalid confirmation payload")
            return
        }
        
        // Update message status in database
        do {
            let fetchRequest = FetchDescriptor<SlackMessage>(
                predicate: #Predicate { $0.id == messageId }
            )
            let messages = try modelContext.fetch(fetchRequest)
            
            if let message = messages.first {
                message.status = status == "sent" ? SlackMessage.MessageStatus.sent : SlackMessage.MessageStatus.failed
                message.sentAt = Date()
                try modelContext.save()
                
                DispatchQueue.main.async {
                    NotificationCenter.default.post(name: .slackMessageStatusUpdated, object: message)
                }
                
                print("✅ Message \(messageId) status updated to \(status)")
            }
            
            sendHTTPResponse(connection: connection, status: 200, body: "OK")
            
        } catch {
            print("❌ Failed to update message status: \(error)")
            sendHTTPResponse(connection: connection, status: 500, body: "Failed to update status")
        }
    }
    
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
}

// MARK: - HTTP Status Helper
private enum HTTPStatus {
    static func message(for code: Int) -> String {
        switch code {
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