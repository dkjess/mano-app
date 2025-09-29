//
//  Conversation.swift
//  Mano
//
//  Created by Claude Code on 27/09/2025.
//

import Foundation

struct Conversation: Codable, Identifiable, Equatable {
    let id: UUID
    let personId: UUID
    let title: String?
    let isActive: Bool
    let createdAt: Date
    let updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case personId = "person_id"
        case title
        case isActive = "is_active"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

struct ConversationWithMessages: Codable, Identifiable, Equatable {
    let id: UUID
    let personId: UUID
    let title: String?
    let isActive: Bool
    let createdAt: Date
    let updatedAt: Date
    let messages: [Message]

    enum CodingKeys: String, CodingKey {
        case id
        case personId = "person_id"
        case title
        case isActive = "is_active"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case messages
    }
}

struct ConversationSummary: Codable, Identifiable, Equatable {
    let id: UUID
    let title: String
    let lastMessageAt: Date
    let messageCount: Int

    enum CodingKeys: String, CodingKey {
        case id
        case title
        case lastMessageAt = "last_message_at"
        case messageCount = "message_count"
    }
}