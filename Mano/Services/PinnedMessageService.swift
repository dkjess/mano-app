//
//  PinnedMessageService.swift
//  Mano
//
//  Created by Claude on 13/10/2025.
//

import Foundation
import Supabase

@MainActor
class PinnedMessageService {
    static let shared = PinnedMessageService()

    private let client = SupabaseManager.shared.client

    private init() {}

    /// Pin a message
    func pinMessage(messageId: UUID, personId: UUID?, topicId: UUID?, note: String? = nil) async throws {
        guard let userId = try? await client.auth.session.user.id else {
            print("❌ [PinnedService] User not authenticated")
            throw NSError(domain: "PinnedMessageService", code: 401, userInfo: [NSLocalizedDescriptionKey: "User not authenticated"])
        }

        // Check if already pinned to avoid duplicate key error
        let alreadyPinned = try await isMessagePinned(messageId: messageId)
        if alreadyPinned {
            return
        }

        // Build dictionary with only non-nil values
        var pinnedMessage: [String: String] = [
            "user_id": userId.uuidString,
            "message_id": messageId.uuidString
        ]

        if let personId = personId {
            pinnedMessage["person_id"] = personId.uuidString
        }
        if let topicId = topicId {
            pinnedMessage["topic_id"] = topicId.uuidString
        }
        if let note = note {
            pinnedMessage["note"] = note
        }

        do {
            _ = try await client
                .from("pinned_messages")
                .insert(pinnedMessage)
                .execute()
                .data

            // Generate title in background (fire-and-forget)
            Task {
                await generateTitleInBackground(messageId: messageId, userId: userId)
            }
        } catch {
            print("❌ [PinnedService] Failed to pin message: \(error)")
            throw error
        }
    }

    /// Generate title for pinned message in background
    private func generateTitleInBackground(messageId: UUID, userId: UUID) async {
        do {
            let requestBody: [String: String] = [
                "message_id": messageId.uuidString,
                "user_id": userId.uuidString
            ]

            let encoder = JSONEncoder()
            let jsonData = try encoder.encode(requestBody)

            _ = try await client.functions.invoke(
                "generate-pinned-title",
                options: .init(
                    body: jsonData
                )
            )
        } catch {
            // Don't throw - this is fire-and-forget
            print("⚠️ [PinnedService] Failed to generate title: \(error)")
        }
    }

    /// Unpin a message
    func unpinMessage(messageId: UUID) async throws {
        guard let userId = try? await client.auth.session.user.id else {
            throw NSError(domain: "PinnedMessageService", code: 401, userInfo: [NSLocalizedDescriptionKey: "User not authenticated"])
        }

        try await client
            .from("pinned_messages")
            .delete()
            .eq("user_id", value: userId.uuidString)
            .eq("message_id", value: messageId.uuidString)
            .execute()

        print("✅ Unpinned message: \(messageId)")
    }

    /// Check if a message is pinned
    func isMessagePinned(messageId: UUID) async throws -> Bool {
        guard let userId = try? await client.auth.session.user.id else {
            return false
        }

        let data = try await client
            .from("pinned_messages")
            .select("id, user_id, message_id, person_id, topic_id, note, pinned_at, created_at, updated_at")
            .eq("user_id", value: userId.uuidString)
            .eq("message_id", value: messageId.uuidString)
            .execute()
            .data

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let results = try decoder.decode([PinnedMessage].self, from: data)

        return !results.isEmpty
    }

    /// Fetch all pinned messages with joined data
    func fetchPinnedMessages() async throws -> [PinnedMessage] {
        guard let userId = try? await client.auth.session.user.id else {
            throw NSError(domain: "PinnedMessageService", code: 401, userInfo: [NSLocalizedDescriptionKey: "User not authenticated"])
        }

        // Fetch pinned messages with joined message content, person, and topic
        let data = try await client
            .from("pinned_messages")
            .select("""
                id, user_id, message_id, person_id, topic_id, note, title, pinned_at, created_at, updated_at,
                message_content:messages!message_id(content),
                message_created_at:messages!message_id(created_at),
                conversation_id:messages!message_id(conversation_id),
                person_name:people!person_id(name),
                person_emoji:people!person_id(emoji),
                topic_title:topics!topic_id(title)
            """)
            .eq("user_id", value: userId.uuidString)
            .order("pinned_at", ascending: false)
            .execute()
            .data

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        // Manual decoding to handle nested joins
        let json = try JSONSerialization.jsonObject(with: data) as? [[String: Any]] ?? []

        var pinnedMessages: [PinnedMessage] = []

        for item in json {
            let id = UUID(uuidString: item["id"] as? String ?? "") ?? UUID()
            let userId = UUID(uuidString: item["user_id"] as? String ?? "") ?? UUID()
            let messageId = UUID(uuidString: item["message_id"] as? String ?? "") ?? UUID()
            let personId = (item["person_id"] as? String).flatMap { UUID(uuidString: $0) }
            let topicId = (item["topic_id"] as? String).flatMap { UUID(uuidString: $0) }
            let note = item["note"] as? String
            let title = item["title"] as? String

            let pinnedAtStr = item["pinned_at"] as? String ?? ""
            let createdAtStr = item["created_at"] as? String ?? ""
            let updatedAtStr = item["updated_at"] as? String ?? ""

            let dateFormatter = ISO8601DateFormatter()
            let pinnedAt = dateFormatter.date(from: pinnedAtStr) ?? Date()
            let createdAt = dateFormatter.date(from: createdAtStr) ?? Date()
            let updatedAt = dateFormatter.date(from: updatedAtStr) ?? Date()

            // Extract joined data
            let messageContent = (item["message_content"] as? [[String: Any]])?.first?["content"] as? String
            let messageCreatedAtStr = (item["message_created_at"] as? [[String: Any]])?.first?["created_at"] as? String
            let messageCreatedAt = messageCreatedAtStr.flatMap { dateFormatter.date(from: $0) }

            // Extract conversation_id from nested dictionary
            let conversationIdStr = (item["conversation_id"] as? [String: Any])?["conversation_id"] as? String
            let conversationId = conversationIdStr.flatMap { UUID(uuidString: $0) }

            let personName = (item["person_name"] as? [[String: Any]])?.first?["name"] as? String
            let personEmoji = (item["person_emoji"] as? [[String: Any]])?.first?["emoji"] as? String
            let topicTitle = (item["topic_title"] as? [[String: Any]])?.first?["title"] as? String

            var pinnedMessage = PinnedMessage(
                id: id,
                userId: userId,
                messageId: messageId,
                personId: personId,
                topicId: topicId,
                note: note,
                title: title,
                pinnedAt: pinnedAt,
                createdAt: createdAt,
                updatedAt: updatedAt
            )

            pinnedMessage.messageContent = messageContent
            pinnedMessage.messageCreatedAt = messageCreatedAt
            pinnedMessage.conversationId = conversationId
            pinnedMessage.personName = personName
            pinnedMessage.personEmoji = personEmoji
            pinnedMessage.topicTitle = topicTitle

            pinnedMessages.append(pinnedMessage)
        }

        return pinnedMessages
    }
}
