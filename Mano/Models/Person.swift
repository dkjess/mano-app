//
//  Person.swift
//  Mano
//
//  Created by Jess Wambui Olsen on 31/08/2025.
//

import Foundation

struct Person: Codable, Identifiable, Hashable {
    let id: UUID
    let userId: UUID
    let name: String
    let role: String?
    let relationshipType: String
    let team: String?
    let location: String?
    let createdAt: Date
    let updatedAt: Date
    
    // Additional fields from backend
    let notes: String?
    let emoji: String?
    let startDate: Date?
    let communicationStyle: String?
    let goals: String?
    let strengths: String?
    let challenges: String?
    let lastProfilePrompt: Date?
    let profileCompletionScore: Int?
    let isSelf: Bool?

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case name
        case role
        case relationshipType = "relationship_type"
        case team
        case location
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case notes
        case emoji
        case startDate = "start_date"
        case communicationStyle = "communication_style"
        case goals
        case strengths
        case challenges
        case lastProfilePrompt = "last_profile_prompt"
        case profileCompletionScore = "profile_completion_score"
        case isSelf = "is_self"
    }
}