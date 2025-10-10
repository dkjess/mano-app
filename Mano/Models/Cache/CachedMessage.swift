//
//  CachedMessage.swift
//  Mano
//
//  SwiftData model for caching Message data
//

import Foundation
import SwiftData

@Model
final class CachedMessage {
    @Attribute(.unique) var id: UUID
    var userId: UUID
    var content: String
    var isUser: Bool
    var personId: UUID?
    var topicId: UUID?
    var conversationId: UUID?
    var createdAt: Date

    // Cache metadata
    var lastFetchedAt: Date

    init(from message: Message) {
        self.id = message.id
        self.userId = message.userId
        self.content = message.content
        self.isUser = message.isUser
        self.personId = message.personId
        self.topicId = message.topicId
        self.conversationId = message.conversationId
        self.createdAt = message.createdAt
        self.lastFetchedAt = Date()
    }

    func toMessage() -> Message {
        Message(
            id: id,
            userId: userId,
            content: content,
            isUser: isUser,
            personId: personId,
            topicId: topicId,
            conversationId: conversationId,
            createdAt: createdAt
        )
    }
}
