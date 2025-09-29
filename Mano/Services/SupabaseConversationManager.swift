//
//  SupabaseConversationManager.swift
//  Mano
//
//  Created by Claude Code on 27/09/2025.
//

import Foundation
import Supabase
import Combine

@MainActor
class SupabaseConversationManager: ObservableObject {
    private let client: SupabaseClient
    private let authManager: SupabaseAuthManager

    init(client: SupabaseClient, authManager: SupabaseAuthManager) {
        self.client = client
        self.authManager = authManager
    }

    func fetchConversations(for personId: UUID) async throws -> [Conversation] {
        print("📚 Fetching conversations for person: \(personId)")

        guard let userId = await authManager.user?.id else {
            print("❌ No user ID available")
            throw NSError(domain: "SupabaseConversationManager", code: 401, userInfo: [NSLocalizedDescriptionKey: "User not authenticated"])
        }

        // Fetch conversations with inner join to ensure person belongs to user
        let response = try await client
            .from("conversations")
            .select("""
                id,
                person_id,
                title,
                is_active,
                created_at,
                updated_at,
                people!inner(user_id)
            """)
            .eq("person_id", value: personId.uuidString.lowercased())
            .eq("people.user_id", value: userId.uuidString.lowercased())
            .order("updated_at", ascending: false)
            .execute()

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        do {
            let conversations = try decoder.decode([Conversation].self, from: response.data)
            print("✅ Fetched \(conversations.count) conversations")
            return conversations
        } catch {
            print("❌ Decoding error: \(error)")
            print("📦 Raw data: \(String(data: response.data, encoding: .utf8) ?? "nil")")
            throw error
        }
    }

    func getActiveConversation(for personId: UUID) async throws -> Conversation? {
        print("🔍 Getting active conversation for person: \(personId)")

        let conversations = try await fetchConversations(for: personId)
        return conversations.first { $0.isActive }
    }

    func archiveActiveConversation(for personId: UUID) async throws {
        print("📦 Archiving active conversation for person: \(personId)")

        guard let userId = await authManager.user?.id else {
            print("❌ No user ID available")
            throw NSError(domain: "SupabaseConversationManager", code: 401, userInfo: [NSLocalizedDescriptionKey: "User not authenticated"])
        }

        // Archive all active conversations for this person
        let response = try await client
            .from("conversations")
            .update([
                "is_active": AnyJSON.bool(false)
            ])
            .eq("person_id", value: personId.uuidString.lowercased())
            .eq("is_active", value: true)
            .execute()

        print("✅ Archived active conversations")
    }

    func startNewConversation(for personId: UUID) async throws -> Conversation {
        print("🆕 Starting new conversation for person: \(personId)")

        guard let userId = await authManager.user?.id else {
            print("❌ No user ID available")
            throw NSError(domain: "SupabaseConversationManager", code: 401, userInfo: [NSLocalizedDescriptionKey: "User not authenticated"])
        }

        // First archive any active conversations
        try await archiveActiveConversation(for: personId)

        // Create new conversation
        let conversationData: [String: AnyJSON] = [
            "person_id": AnyJSON.string(personId.uuidString.lowercased()),
            "title": AnyJSON.null,
            "is_active": AnyJSON.bool(true)
        ]

        let response = try await client
            .from("conversations")
            .insert(conversationData)
            .select()
            .single()
            .execute()

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        do {
            let conversation = try decoder.decode(Conversation.self, from: response.data)
            print("✅ Created new conversation: \(conversation.id)")
            return conversation
        } catch {
            print("❌ Decoding error: \(error)")
            print("📦 Raw data: \(String(data: response.data, encoding: .utf8) ?? "nil")")
            throw error
        }
    }

    func updateConversationTitle(_ conversationId: UUID, title: String) async throws {
        print("🏷️ Updating conversation title: \(conversationId)")

        let response = try await client
            .from("conversations")
            .update([
                "title": AnyJSON.string(title)
            ])
            .eq("id", value: conversationId.uuidString.lowercased())
            .execute()

        print("✅ Updated conversation title to: \(title)")
    }

    func fetchMessagesForConversation(_ conversationId: UUID) async throws -> [Message] {
        print("💬 Fetching messages for conversation: \(conversationId)")

        let response = try await client
            .from("messages")
            .select()
            .eq("conversation_id", value: conversationId.uuidString.lowercased())
            .order("created_at", ascending: true)
            .execute()

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        do {
            let messages = try decoder.decode([Message].self, from: response.data)
            print("✅ Fetched \(messages.count) messages for conversation")
            return messages
        } catch {
            print("❌ Decoding error: \(error)")
            print("📦 Raw data: \(String(data: response.data, encoding: .utf8) ?? "nil")")
            throw error
        }
    }

    func deleteConversation(_ conversationId: UUID) async throws {
        print("🗑️ Deleting conversation: \(conversationId)")

        // Delete all messages in the conversation first (if not handled by CASCADE)
        try await client
            .from("messages")
            .delete()
            .eq("conversation_id", value: conversationId.uuidString.lowercased())
            .execute()

        // Delete the conversation
        try await client
            .from("conversations")
            .delete()
            .eq("id", value: conversationId.uuidString.lowercased())
            .execute()

        print("✅ Deleted conversation and its messages")
    }
}