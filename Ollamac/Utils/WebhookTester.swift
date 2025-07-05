//
//  WebhookTester.swift
//  Slacker
//
//  Created by SlackSassin Integration
//

import Foundation

class WebhookTester {
    static let shared = WebhookTester()
    
    private init() {}
    
    // MARK: - Test Functions
    
    /// Test the local webhook server directly
    func testLocalWebhook(completion: @escaping (Bool, String) -> Void) {
        testWebhook(baseURL: "http://localhost:8080", completion: completion)
    }
    
    /// Test the NGrok tunnel webhook
    func testNGrokWebhook(completion: @escaping (Bool, String) -> Void) {
        Task { @MainActor in
            guard let tunnelURL = NGrokManager.shared.tunnelURL else {
                completion(false, "NGrok tunnel not available")
                return
            }
            testWebhook(baseURL: tunnelURL, completion: completion)
        }
    }
    
    /// Test health endpoint
    func testHealthEndpoint(baseURL: String = "http://localhost:8080", completion: @escaping (Bool, String) -> Void) {
        guard let url = URL(string: "\(baseURL)/health") else {
            completion(false, "Invalid URL")
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 10.0
        
        print("🩺 Testing health endpoint: \(url)")
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                if let error = error {
                    completion(false, "Health check failed: \(error.localizedDescription)")
                    return
                }
                
                guard let httpResponse = response as? HTTPURLResponse else {
                    completion(false, "Invalid response type")
                    return
                }
                
                guard let data = data, let responseString = String(data: data, encoding: .utf8) else {
                    completion(false, "No response data")
                    return
                }
                
                let success = httpResponse.statusCode == 200
                let message = success ? 
                    "✅ Health check passed: \(responseString)" : 
                    "❌ Health check failed (HTTP \(httpResponse.statusCode)): \(responseString)"
                
                completion(success, message)
            }
        }.resume()
    }
    
    /// Test status endpoint
    func testStatusEndpoint(baseURL: String = "http://localhost:8080", completion: @escaping (Bool, String) -> Void) {
        guard let url = URL(string: "\(baseURL)/status") else {
            completion(false, "Invalid URL")
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 10.0
        
        print("📊 Testing status endpoint: \(url)")
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                if let error = error {
                    completion(false, "Status check failed: \(error.localizedDescription)")
                    return
                }
                
                guard let httpResponse = response as? HTTPURLResponse else {
                    completion(false, "Invalid response type")
                    return
                }
                
                guard let data = data, let responseString = String(data: data, encoding: .utf8) else {
                    completion(false, "No response data")
                    return
                }
                
                let success = httpResponse.statusCode == 200
                let message = success ? 
                    "✅ Status check passed: \(responseString)" : 
                    "❌ Status check failed (HTTP \(httpResponse.statusCode)): \(responseString)"
                
                completion(success, message)
            }
        }.resume()
    }
    
    /// Test the webhook endpoint with sample data
    private func testWebhook(baseURL: String, completion: @escaping (Bool, String) -> Void) {
        guard let url = URL(string: "\(baseURL)/zapier-webhook") else {
            completion(false, "Invalid URL")
            return
        }
        
        // Create sample Slack message payload
        let samplePayload = ZapierPayload(
            channel: ZapierChannel(id: "C1234567890", name: "test-channel"),
            user: ZapierUser(
                id: "U1234567890",
                name: "testuser",
                isBot: false,
                realName: "Test User",
                isRestricted: false,
                isUltraRestricted: false,
                profile: ZapierUserProfile(
                    firstName: "Test",
                    lastName: "User",
                    email: "test@example.com",
                    phone: "",
                    smallImageUrl: "https://example.com/avatar_24.png",
                    mediumImageUrl: "https://example.com/avatar_72.png",
                    largeImageUrl: "https://example.com/avatar_512.png"
                )
            ),
            ts: "\(Date().timeIntervalSince1970)",
            text: "Test message from WebhookTester at \(Date())",
            permalink: "https://slack.com/archives/C1234567890/p\(Int(Date().timeIntervalSince1970))",
            team: ZapierTeam(
                id: "T1234567890",
                name: "Test Team",
                url: "https://testteam.slack.com",
                domain: "testteam",
                emailDomain: "",
                icon: ZapierTeamIcon(
                    smallImageUrl: "https://example.com/team_34.png",
                    mediumImageUrl: "https://example.com/team_88.png",
                    largeImageUrl: "https://example.com/team_230.png"
                ),
                avatarBaseUrl: "https://ca.slack-edge.com/",
                isVerified: false,
                lobSalesHomeEnabled: false,
                isSfdcAutoSlack: false
            ),
            rawText: "Test message from WebhookTester at \(Date())",
            tsTime: ISO8601DateFormatter().string(from: Date())
        )
        
        guard let jsonData = try? JSONEncoder().encode(samplePayload) else {
            completion(false, "Failed to encode test payload")
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("webhook-tester", forHTTPHeaderField: "User-Agent")
        request.httpBody = jsonData
        request.timeoutInterval = 15.0
        
        print("🎯 Testing webhook: \(url)")
        print("📤 Payload: \(String(data: jsonData, encoding: .utf8) ?? "Invalid JSON")")
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                if let error = error {
                    completion(false, "Webhook test failed: \(error.localizedDescription)")
                    return
                }
                
                guard let httpResponse = response as? HTTPURLResponse else {
                    completion(false, "Invalid response type")
                    return
                }
                
                guard let data = data, let responseString = String(data: data, encoding: .utf8) else {
                    completion(false, "No response data")
                    return
                }
                
                let success = httpResponse.statusCode == 200
                let message = success ? 
                    "✅ Webhook test passed: \(responseString)" : 
                    "❌ Webhook test failed (HTTP \(httpResponse.statusCode)): \(responseString)"
                
                completion(success, message)
            }
        }.resume()
    }
    
    /// Run a comprehensive test of all endpoints
    func runFullTest(baseURL: String = "http://localhost:8080", completion: @escaping ([String]) -> Void) {
        var results: [String] = []
        let group = DispatchGroup()
        
        // Test health endpoint
        group.enter()
        testHealthEndpoint(baseURL: baseURL) { success, message in
            results.append("Health: \(message)")
            group.leave()
        }
        
        // Test status endpoint
        group.enter()
        testStatusEndpoint(baseURL: baseURL) { success, message in
            results.append("Status: \(message)")
            group.leave()
        }
        
        // Test webhook endpoint
        group.enter()
        testWebhook(baseURL: baseURL) { success, message in
            results.append("Webhook: \(message)")
            group.leave()
        }
        
        group.notify(queue: .main) {
            completion(results)
        }
    }
}

// MARK: - Console Testing Functions
extension WebhookTester {
    
    /// Print comprehensive test results to console
    func runConsoleTest() {
        print("🧪 ===== WEBHOOK SERVER TEST SUITE =====")
        print("🕐 Test started at: \(Date())")
        print("")
        
        runFullTest { results in
            print("📋 Test Results:")
            for result in results {
                print("   \(result)")
            }
            print("")
            print("🏁 Test completed!")
            
            // Also test NGrok if local tests pass
            let localPassed = results.allSatisfy { $0.contains("✅") }
            if localPassed {
                Task { @MainActor in
                    if let tunnelURL = NGrokManager.shared.tunnelURL {
                        print("")
                        print("🌐 Testing NGrok tunnel...")
                        self.runFullTest(baseURL: tunnelURL) { ngrokResults in
                            print("📋 NGrok Test Results:")
                            for result in ngrokResults {
                                print("   \(result)")
                            }
                            print("")
                            print("🎉 Full test suite completed!")
                        }
                    } else {
                        print("⚠️  NGrok tunnel not available for testing")
                    }
                }
            }
        }
    }
} 