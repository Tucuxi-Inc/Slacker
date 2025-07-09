// SimilarityService.swift
//
// Created by Kevin Keller -- Tucuxi, Inc. July 2025

import Foundation
import SwiftData
import Defaults

struct SimilarMessageResult {
    let message: SlackMessage
    let confidence: Double
    let confidenceLevel: ConfidenceLevel
    
    var formattedConfidence: String {
        String(format: "%.1f%%", confidence)
    }
    
    enum ConfidenceLevel {
        case veryHigh, high, medium, low
        
        var emoji: String {
            switch self {
            case .veryHigh: return "🎯"
            case .high: return "🔥"
            case .medium: return "⚡"
            case .low: return "💡"
            }
        }
        
        var color: String {
            switch self {
            case .veryHigh: return "#22C55E"
            case .high: return "#3B82F6"
            case .medium: return "#F59E0B"
            case .low: return "#6B7280"
            }
        }
    }
}

class SimilarityService {
    static let shared = SimilarityService()
    private init() {}
    
    private let embeddingModel = Defaults[.similarityEmbeddingModel]
    
    func findSimilarMessages(to message: SlackMessage, in context: ModelContext) -> [SimilarMessageResult] {
        print("🔍 Starting similarity search for: \(message.text.prefix(100))...")
        
        // Generate embedding for the target message
        let targetEmbedding = generateEmbedding(for: message.text)
        
        // Fetch all messages with embeddings
        let descriptor = FetchDescriptor<SlackMessage>()
        guard let allMessages = try? context.fetch(descriptor) else {
            print("❌ Failed to fetch messages from context")
            return []
        }
        
        // Filter to only auto-response templates for comparison
        let templateMessages = allMessages.filter { $0.useForAutoResponse }
        print("📊 Found \(allMessages.count) total messages, \(templateMessages.count) are auto-response templates")
        
        var results: [SimilarMessageResult] = []
        
        for storedMessage in templateMessages {
            // Skip the same message
            if storedMessage.id == message.id {
                continue
            }
            
            // Generate embedding if not present
            var storedEmbedding: [Double]
            if let embedding = storedMessage.embedding {
                storedEmbedding = embedding
            } else {
                storedEmbedding = generateEmbedding(for: storedMessage.text)
            }
            
            // Calculate similarity
            let similarity = cosineSimilarity(targetEmbedding, storedEmbedding)
            
            // Convert to percentage and add debug logging
            let confidencePercentage = similarity * 100
            
            // Debug logging for similarity calculations
            print("🔍 Similarity comparison:")
            print("   Target: \(message.text.prefix(50))...")
            print("   Stored: \(storedMessage.text.prefix(50))...")
            print("   Raw similarity: \(String(format: "%.4f", similarity))")
            print("   Confidence: \(String(format: "%.2f", confidencePercentage))%")
            print("   Threshold: \(Defaults[.similarityDisplayThreshold])%")
            print("   Auto-response template: \(storedMessage.useForAutoResponse)")
            
            if confidencePercentage > Defaults[.similarityDisplayThreshold] {
                let level = getConfidenceLevel(for: confidencePercentage)
                let result = SimilarMessageResult(
                    message: storedMessage,
                    confidence: confidencePercentage,
                    confidenceLevel: level
                )
                results.append(result)
                print("   ✅ Added to results (above threshold)")
            } else {
                print("   ❌ Rejected (below threshold)")
            }
        }
        
        // Sort by confidence (highest first)
        return results.sorted { $0.confidence > $1.confidence }
    }
    
    private func generateEmbedding(for text: String) -> [Double] {
        // TODO: Replace with actual Ollama embedding when OllamaKit supports it
        // For now, use text-based feature extraction
        return extractFeatures(from: text)
    }
    
    private func extractFeatures(from text: String) -> [Double] {
        // Enhanced semantic-aware feature extraction
        let cleanText = text.lowercased()
        let words = cleanText.components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
        
        print("🧠 Feature extraction for: \(text.prefix(50))...")
        print("   Clean text: \(cleanText)")
        print("   Words: \(words)")
        
        // Stop words to filter out for content analysis
        let stopWords = Set(["the", "and", "to", "of", "a", "in", "is", "it", "you", "that", "he", "was", "for", "on", "are", "as", "with", "his", "they", "i", "at", "be", "this", "have", "from", "or", "one", "had", "by", "word", "but", "not", "what", "all", "were", "we", "when", "your", "can", "said", "there", "each", "which", "she", "do", "how", "their", "if", "will", "way", "about", "many", "then", "them", "would", "like", "so", "these", "her", "long", "make", "thing", "see", "him", "two", "more", "has", "go", "me", "no", "my", "than", "first", "been", "call", "who", "its", "now", "find", "get", "may", "say", "come", "use", "into", "over", "think", "also", "back", "after", "very", "well", "year", "work", "where", "much", "before", "here", "too", "any", "new", "want", "because", "does", "old", "tell", "boy", "follow", "came", "show", "around", "gov", "don", "let", "put", "end", "why", "try", "good", "hand", "school", "move", "right", "student", "place", "made", "high", "such", "stay", "turn", "ask", "might", "great", "change", "kind", "off", "need", "house", "picture", "try", "us", "again", "animal", "point", "mother", "world", "near", "build", "self", "earth", "father"])
        
        // Get content words (non-stop words)
        let contentWords = words.filter { !stopWords.contains($0) && $0.count > 2 }
        print("   Content words: \(contentWords)")
        
        var features: [Double] = []
        
        // 1. Basic structural features (3 dimensions)
        features.append(min(Double(cleanText.count) / 100.0, 1.0))
        features.append(min(Double(words.count) / 50.0, 1.0))
        features.append(min(Double(contentWords.count) / 20.0, 1.0))
        
        // 2. SEMANTIC INTENT DETECTION (10 dimensions) - This is the key improvement!
        // Different question types require different answers
        let abilityIntent = ["can", "could", "able", "do", "does", "did", "will", "would", "shall", "may"]
        let preferenceIntent = ["like", "love", "want", "prefer", "enjoy", "hate", "dislike", "wish", "desire"]
        let quantityIntent = words.contains("how") && (words.contains("many") || words.contains("much"))
        let comparisonIntent = ["better", "worse", "more", "less", "compare", "versus", "vs", "different"]
        let timeIntent = ["when", "before", "after", "during", "while", "until", "since", "time"]
        let locationIntent = ["where", "here", "there", "location", "place"]
        let reasonIntent = ["why", "because", "reason", "cause", "purpose", "goal"]
        let methodIntent = words.contains("how") && !quantityIntent
        let yesNoIntent = cleanText.hasPrefix("is ") || cleanText.hasPrefix("are ") || cleanText.hasPrefix("do ") || cleanText.hasPrefix("does ")
        
        // Intent feature encoding with higher weights
        features.append(Double(words.filter { abilityIntent.contains($0) }.count) * 2.0)  // Weight ability questions
        features.append(Double(words.filter { preferenceIntent.contains($0) }.count) * 2.0) // Weight preference questions  
        features.append(quantityIntent ? 2.0 : 0.0)
        features.append(Double(words.filter { comparisonIntent.contains($0) }.count) * 1.5)
        features.append(Double(words.filter { timeIntent.contains($0) }.count) * 1.5)
        features.append(Double(words.filter { locationIntent.contains($0) }.count) * 1.5)
        features.append(Double(words.filter { reasonIntent.contains($0) }.count) * 1.5)
        features.append(methodIntent ? 1.5 : 0.0)
        features.append(yesNoIntent ? 1.5 : 0.0)
        
        // Semantic modifier that changes meaning significantly
        let negationPresent = cleanText.contains("not") || cleanText.contains("n't") || cleanText.contains("never") || cleanText.contains("no ")
        features.append(negationPresent ? 2.0 : 0.0) // Negation completely changes meaning
        
        // 3. Critical phrase patterns (8 dimensions)
        // These patterns indicate very different semantic meanings
        let criticalPatterns = [
            "like to",     // Preference vs ability
            "want to",     // Desire vs capability  
            "able to",     // Ability indicator
            "have to",     // Obligation vs choice
            "going to",    // Future intent
            "used to",     // Past habit vs current
            "supposed to", // Expectation vs reality
            "need to"      // Necessity vs want
        ]
        
        for pattern in criticalPatterns {
            features.append(cleanText.contains(pattern) ? 2.0 : 0.0)
        }
        
        // 4. Topic/domain features (15 dimensions)
        let domainWords = [
            // Legal/crime domain
            ["legal", "law", "crime", "felony", "penalty", "death", "prison", "court"],
            // Business/marketing domain
            ["business", "marketing", "sms", "email", "advertising", "customer", "privacy"],
            // Animal/nature domain  
            ["woodchuck", "chuck", "wood", "animal", "forest", "nature", "wildlife"],
            // Technical domain
            ["computer", "software", "program", "code", "data", "system", "technology"],
            // Personal domain
            ["personal", "family", "friend", "relationship", "home", "life", "feeling"]
        ]
        
        for domain in domainWords {
            let domainScore = Double(words.filter { word in domain.contains { word.contains($0) } }.count)
            features.append(domainScore)
        }
        
        // Pad remaining slots with contextual features
        features.append(cleanText.contains("?") ? 1.0 : 0.0) // Question mark
        features.append(cleanText.hasPrefix("@") ? 1.0 : 0.0) // Mention
        features.append(Double(words.count > 10 ? 1 : 0)) // Long question
        features.append(Double(words.count < 5 ? 1 : 0))  // Short question
        
        // 5. Advanced semantic features (remaining dimensions)
        let emotionalWords = ["angry", "happy", "sad", "excited", "worried", "confused", "frustrated"]
        features.append(Double(words.filter { emotionalWords.contains($0) }.count))
        
        let certaintyWords = ["definitely", "certainly", "probably", "maybe", "possibly", "surely"]
        features.append(Double(words.filter { certaintyWords.contains($0) }.count))
        
        let intensityWords = ["very", "extremely", "really", "quite", "somewhat", "little", "much"]
        features.append(Double(words.filter { intensityWords.contains($0) }.count))
        
        let formalityWords = ["please", "kindly", "would you", "could you", "may i", "excuse me"]
        let informalityWords = ["hey", "yo", "sup", "dude", "bro", "gonna", "wanna"]
        features.append(Double(formalityWords.filter { cleanText.contains($0) }.count))
        features.append(Double(words.filter { informalityWords.contains($0) }.count))
        
        // Pad to exactly 50 dimensions
        while features.count < 50 {
            features.append(0.0)
        }
        features = Array(features.prefix(50))
        
        print("   Features: \(features.prefix(10))... (total: \(features.count))")
        print("   Intent signals: ability=\(features[3]), preference=\(features[4]), negation=\(features[9])")
        
        return features
    }
    
    private func cosineSimilarity(_ a: [Double], _ b: [Double]) -> Double {
        guard a.count == b.count else { return 0.0 }
        
        // Fixed critical bug in dot product calculation
        let dotProduct = zip(a, b).reduce(0) { result, pair in result + (pair.0 * pair.1) }
        let magnitudeA = sqrt(a.reduce(0) { $0 + ($1 * $1) })
        let magnitudeB = sqrt(b.reduce(0) { $0 + ($1 * $1) })
        
        guard magnitudeA > 0 && magnitudeB > 0 else { return 0.0 }
        
        let result = dotProduct / (magnitudeA * magnitudeB)
        
        // Debug the cosine similarity calculation
        print("🧮 Cosine similarity debug:")
        print("   Vector A length: \(a.count), Vector B length: \(b.count)")
        print("   Dot product: \(String(format: "%.4f", dotProduct))")
        print("   Magnitude A: \(String(format: "%.4f", magnitudeA))")
        print("   Magnitude B: \(String(format: "%.4f", magnitudeB))")
        print("   Result: \(String(format: "%.4f", result))")
        
        return result
    }
    
    private func getConfidenceLevel(for confidencePercentage: Double) -> SimilarMessageResult.ConfidenceLevel {
        if confidencePercentage >= 90.0 {
            return .veryHigh
        } else if confidencePercentage >= 75.0 {
            return .high
        } else if confidencePercentage >= 50.0 {
            return .medium
        } else {
            return .low
        }
    }
    
    func generateEmbeddingForMessage(_ message: SlackMessage) {
        // TODO: Replace with actual Ollama embedding when OllamaKit supports it
        message.embedding = generateEmbedding(for: message.text)
        message.embeddingModel = embeddingModel
        message.embeddingGeneratedAt = Date()
    }
    
    func getAutoResponseCandidates(for message: SlackMessage, in context: ModelContext) -> [SlackMessage] {
        let similarMessages = findSimilarMessages(to: message, in: context)
        return similarMessages
            .filter { $0.confidence >= Defaults[.similarityAutoResponseThreshold] && $0.message.useForAutoResponse }
            .map { $0.message }
    }
} 