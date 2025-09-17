//
//  Message.swift
//  Mano
//
//  Created by Jess Wambui Olsen on 31/08/2025.
//

import Foundation

struct Message: Codable, Identifiable, Equatable {
    let id: UUID
    let userId: UUID
    let content: String
    let isUser: Bool
    let personId: UUID?
    let topicId: UUID?
    let createdAt: Date
    
    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case content
        case isUser = "is_user"
        case personId = "person_id"
        case topicId = "topic_id"
        case createdAt = "created_at"
    }
}

struct NewMessage: Codable, Sendable {
    let userId: String
    let personId: String
    let content: String
    let isUser: Bool
    
    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case personId = "person_id"
        case content
        case isUser = "is_user"
    }
}