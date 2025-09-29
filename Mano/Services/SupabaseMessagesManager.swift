//
//  SupabaseMessagesManager.swift
//  Mano
//
//  Created by Claude on 11/09/2025.
//

import Foundation
import Supabase
import PostgREST

class SupabaseMessagesManager {
    private let client: SupabaseClient
    private let authManager: SupabaseAuthManager
    
    init(client: SupabaseClient, authManager: SupabaseAuthManager) {
        self.client = client
        self.authManager = authManager
    }
    
    func fetchMessages(for personId: UUID) async throws -> [Message] {
        print("💬 Fetching messages for person: \(personId)")

        guard let userId = await authManager.user?.id else {
            print("❌ No user ID available")
            throw NSError(domain: "SupabaseMessagesManager", code: 401, userInfo: [NSLocalizedDescriptionKey: "User not authenticated"])
        }

        print("🔍 User ID: \(userId.uuidString)")
        print("🔍 Person ID: \(personId.uuidString)")

        // First, get the active conversation for this person
        let conversationResponse = try await client
            .from("conversations")
            .select("id")
            .eq("person_id", value: personId.uuidString.lowercased())
            .eq("is_active", value: true)
            .order("updated_at", ascending: false)
            .limit(1)
            .execute()

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        // If we have an active conversation, fetch messages from it
        if !conversationResponse.data.isEmpty {
            if let conversationData = try? JSONSerialization.jsonObject(with: conversationResponse.data) as? [[String: Any]],
               let firstConversation = conversationData.first,
               let conversationIdString = firstConversation["id"] as? String {

                print("🔍 Found active conversation: \(conversationIdString)")

                let response = try await client
                    .from("messages")
                    .select()
                    .eq("conversation_id", value: conversationIdString)
                    .order("created_at", ascending: true)
                    .execute()

                print("📦 Raw response data length: \(response.data.count)")

                do {
                    let messages = try decoder.decode([Message].self, from: response.data)
                    print("✅ Fetched \(messages.count) messages from active conversation")
                    return messages
                } catch {
                    print("❌ Decoding error: \(error)")
                    print("📦 Raw data: \(String(data: response.data, encoding: .utf8) ?? "nil")")
                    throw error
                }
            }
        }

        // Fallback: fetch messages by person_id for backward compatibility
        print("⚠️ No active conversation found, falling back to person-based query")
        let response = try await client
            .from("messages")
            .select()
            .eq("user_id", value: userId.uuidString.lowercased())
            .eq("person_id", value: personId.uuidString.lowercased())
            .order("created_at", ascending: true)
            .execute()

        print("📦 Raw response data length: \(response.data.count)")

        do {
            let messages = try decoder.decode([Message].self, from: response.data)
            print("✅ Fetched \(messages.count) messages via fallback")
            return messages
        } catch {
            print("❌ Decoding error: \(error)")
            print("📦 Raw data: \(String(data: response.data, encoding: .utf8) ?? "nil")")
            throw error
        }
    }
    
    func sendMessageWithStream(_ content: String, to personId: UUID, onChunk: @escaping (String) async -> Void) async throws {
        print("📤 Sending message with streaming to person: \(personId)")
        
        guard let userId = await authManager.user?.id else {
            print("❌ No user ID available")
            throw NSError(domain: "SupabaseMessagesManager", code: 401, userInfo: [NSLocalizedDescriptionKey: "User not authenticated"])
        }
        
        // First, insert the user's message
        let messageData: [String: AnyJSON] = [
            "user_id": AnyJSON.string(userId.uuidString.lowercased()),
            "person_id": AnyJSON.string(personId.uuidString.lowercased()),
            "content": AnyJSON.string(content),
            "is_user": AnyJSON.bool(true)
        ]
        
        try await client
            .from("messages")
            .insert(messageData)
            .execute()
        
        print("✅ User message sent successfully")
        
        // Now call the chat Edge Function with streaming
        try await callChatFunctionWithStream(content: content, personId: personId, onChunk: onChunk)
    }
    
    func sendMessage(_ content: String, to personId: UUID) async throws {
        print("📤 Sending message to person: \(personId)")
        
        guard let userId = await authManager.user?.id else {
            print("❌ No user ID available")
            throw NSError(domain: "SupabaseMessagesManager", code: 401, userInfo: [NSLocalizedDescriptionKey: "User not authenticated"])
        }
        
        // First, insert the user's message
        let messageData: [String: AnyJSON] = [
            "user_id": AnyJSON.string(userId.uuidString.lowercased()),
            "person_id": AnyJSON.string(personId.uuidString.lowercased()),
            "content": AnyJSON.string(content),
            "is_user": AnyJSON.bool(true)
        ]
        
        try await client
            .from("messages")
            .insert(messageData)
            .execute()
        
        print("✅ User message sent successfully")
        
        // Now call the chat Edge Function to get AI response
        try await callChatFunction(content: content, personId: personId)
    }
    
    private func callChatFunctionWithStream(content: String, personId: UUID, onChunk: @escaping (String) async -> Void) async throws {
        print("🌊 Starting streaming chat function")
        print("📝 Message content: \(content)")
        print("👤 Person ID: \(personId.uuidString.lowercased())")
        
        let session = try await client.auth.session
        
        // Request streaming response from backend
        let requestBody: [String: Any] = [
            "message": content,
            "person_id": personId.uuidString.lowercased(),
            "action": "streaming_chat"  // This triggers the streaming response
        ]
        
        let jsonData = try JSONSerialization.data(withJSONObject: requestBody)
        
        let supabaseURL = BackendEnvironmentManager.shared.currentEnvironment.supabaseURL
        let supabaseAnonKey = BackendEnvironmentManager.shared.currentEnvironment.supabaseAnonKey
        
        var request = URLRequest(url: URL(string: "\(supabaseURL)/functions/v1/chat")!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(session.accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue(supabaseAnonKey, forHTTPHeaderField: "apikey")
        request.httpBody = jsonData
        
        print("🌐 Starting streaming request to: \(supabaseURL)/functions/v1/chat")
        
        let (bytes, response) = try await URLSession.shared.bytes(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NSError(domain: "SupabaseMessagesManager", code: 0, userInfo: [NSLocalizedDescriptionKey: "Invalid response"])
        }
        
        if httpResponse.statusCode != 200 {
            var errorData = Data()
            for try await byte in bytes {
                errorData.append(byte)
            }
            let errorMessage = String(data: errorData, encoding: .utf8) ?? "Unknown error"
            print("❌ Chat API error: \(errorMessage)")
            throw NSError(domain: "SupabaseMessagesManager", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: errorMessage])
        }
        
        print("🌊 Starting to process SSE stream...")
        
        // Process Server-Sent Events stream from backend
        var currentMessage = ""
        var hasReceivedContent = false
        
        for try await line in bytes.lines {
            print("📝 SSE Line: \(line)")

            // Parse standard SSE format: "data: {json}"
            if line.hasPrefix("data: ") {
                let jsonString = String(line.dropFirst(6)) // Remove "data: " prefix
                print("📦 Received data: \(jsonString)")

                // Parse the JSON content
                if let data = jsonString.data(using: .utf8),
                   let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {

                    if let content = json["content"] as? String {
                        // Character-by-character streaming
                        hasReceivedContent = true
                        await onChunk(content)
                        print("✅ Received character chunk: '\(content)'")
                    } else if let thinking = json["thinking"] as? Bool {
                        // Handle thinking indicators
                        print("🧠 Thinking indicator: \(thinking)")
                    } else if let done = json["done"] as? Bool, done {
                        // Handle completion signal
                        print("✅ Stream completed")
                        break
                    }
                }
            }
        }
        
        if !hasReceivedContent {
            print("⚠️ No content received from stream")
        } else {
            print("✅ Stream processing completed")
        }
    }
    
    private func callChatFunction(content: String, personId: UUID) async throws {
        print("🤖 Calling chat function for AI response")
        print("📝 Message content: \(content)")
        print("👤 Person ID: \(personId.uuidString.lowercased())")
        
        let session = try await client.auth.session
        
        // Use snake_case for the API as expected by the Edge Function
        let requestBody: [String: Any] = [
            "message": content,
            "person_id": personId.uuidString.lowercased()  // Changed from personId to person_id
        ]
        
        let jsonData = try JSONSerialization.data(withJSONObject: requestBody)
        print("📦 Request payload: \(String(data: jsonData, encoding: .utf8) ?? "nil")")
        
        let supabaseURL = BackendEnvironmentManager.shared.currentEnvironment.supabaseURL
        let supabaseAnonKey = BackendEnvironmentManager.shared.currentEnvironment.supabaseAnonKey
        
        var request = URLRequest(url: URL(string: "\(supabaseURL)/functions/v1/chat")!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(session.accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue(supabaseAnonKey, forHTTPHeaderField: "apikey")
        request.httpBody = jsonData
        
        print("🌐 Sending request to: \(supabaseURL)/functions/v1/chat")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NSError(domain: "SupabaseMessagesManager", code: 0, userInfo: [NSLocalizedDescriptionKey: "Invalid response"])
        }
        
        print("📡 Chat API response status: \(httpResponse.statusCode)")
        
        if httpResponse.statusCode != 200 {
            let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
            print("❌ Chat API error: \(errorMessage)")
            print("📄 Full response data: \(data)")
            throw NSError(domain: "SupabaseMessagesManager", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: errorMessage])
        }
        
        print("✅ AI response received successfully")
        let responseString = String(data: data, encoding: .utf8) ?? "nil"
        print("💬 Response: \(responseString)")
    }
}