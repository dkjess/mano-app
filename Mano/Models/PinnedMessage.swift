//
//  PinnedMessage.swift
//  Mano
//
//  Created by Claude on 13/10/2025.
//

import Foundation

struct PinnedMessage: Codable, Identifiable, Hashable {
    let id: UUID
    let userId: UUID
    let messageId: UUID
    let personId: UUID?
    let topicId: UUID?
    let note: String?
    let title: String?
    let pinnedAt: Date
    let createdAt: Date
    let updatedAt: Date

    // Joined data from messages table
    var messageContent: String?
    var messageCreatedAt: Date?
    var conversationId: UUID?

    // Joined data from people table
    var personName: String?
    var personEmoji: String?

    // Joined data from topics table
    var topicTitle: String?

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case messageId = "message_id"
        case personId = "person_id"
        case topicId = "topic_id"
        case note
        case title
        case pinnedAt = "pinned_at"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case messageContent = "message_content"
        case messageCreatedAt = "message_created_at"
        case conversationId = "conversation_id"
        case personName = "person_name"
        case personEmoji = "person_emoji"
        case topicTitle = "topic_title"
    }
}
