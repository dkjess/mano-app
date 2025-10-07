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
    let startedWorkingTogether: Date?

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
        case startedWorkingTogether = "started_working_together"
    }

    // Regular initializer for creating Person instances in code
    init(
        id: UUID,
        userId: UUID,
        name: String,
        role: String? = nil,
        relationshipType: String,
        team: String? = nil,
        location: String? = nil,
        createdAt: Date,
        updatedAt: Date,
        notes: String? = nil,
        emoji: String? = nil,
        startDate: Date? = nil,
        communicationStyle: String? = nil,
        goals: String? = nil,
        strengths: String? = nil,
        challenges: String? = nil,
        lastProfilePrompt: Date? = nil,
        profileCompletionScore: Int? = nil,
        isSelf: Bool? = nil,
        startedWorkingTogether: Date? = nil
    ) {
        self.id = id
        self.userId = userId
        self.name = name
        self.role = role
        self.relationshipType = relationshipType
        self.team = team
        self.location = location
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.notes = notes
        self.emoji = emoji
        self.startDate = startDate
        self.communicationStyle = communicationStyle
        self.goals = goals
        self.strengths = strengths
        self.challenges = challenges
        self.lastProfilePrompt = lastProfilePrompt
        self.profileCompletionScore = profileCompletionScore
        self.isSelf = isSelf
        self.startedWorkingTogether = startedWorkingTogether
    }

    // Custom decoder to handle date-only strings from PostgreSQL
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        id = try container.decode(UUID.self, forKey: .id)
        userId = try container.decode(UUID.self, forKey: .userId)
        name = try container.decode(String.self, forKey: .name)
        role = try container.decodeIfPresent(String.self, forKey: .role)
        relationshipType = try container.decode(String.self, forKey: .relationshipType)
        team = try container.decodeIfPresent(String.self, forKey: .team)
        location = try container.decodeIfPresent(String.self, forKey: .location)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        updatedAt = try container.decode(Date.self, forKey: .updatedAt)
        notes = try container.decodeIfPresent(String.self, forKey: .notes)
        emoji = try container.decodeIfPresent(String.self, forKey: .emoji)
        startDate = try container.decodeIfPresent(Date.self, forKey: .startDate)
        communicationStyle = try container.decodeIfPresent(String.self, forKey: .communicationStyle)
        goals = try container.decodeIfPresent(String.self, forKey: .goals)
        strengths = try container.decodeIfPresent(String.self, forKey: .strengths)
        challenges = try container.decodeIfPresent(String.self, forKey: .challenges)
        lastProfilePrompt = try container.decodeIfPresent(Date.self, forKey: .lastProfilePrompt)
        profileCompletionScore = try container.decodeIfPresent(Int.self, forKey: .profileCompletionScore)
        isSelf = try container.decodeIfPresent(Bool.self, forKey: .isSelf)

        // Handle started_working_together which may be date-only string (YYYY-MM-DD)
        if let dateString = try container.decodeIfPresent(String.self, forKey: .startedWorkingTogether) {
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withFullDate] // Just date, no time
            startedWorkingTogether = formatter.date(from: dateString)
        } else {
            startedWorkingTogether = nil
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        try container.encode(id, forKey: .id)
        try container.encode(userId, forKey: .userId)
        try container.encode(name, forKey: .name)
        try container.encodeIfPresent(role, forKey: .role)
        try container.encode(relationshipType, forKey: .relationshipType)
        try container.encodeIfPresent(team, forKey: .team)
        try container.encodeIfPresent(location, forKey: .location)
        try container.encode(createdAt, forKey: .createdAt)
        try container.encode(updatedAt, forKey: .updatedAt)
        try container.encodeIfPresent(notes, forKey: .notes)
        try container.encodeIfPresent(emoji, forKey: .emoji)
        try container.encodeIfPresent(startDate, forKey: .startDate)
        try container.encodeIfPresent(communicationStyle, forKey: .communicationStyle)
        try container.encodeIfPresent(goals, forKey: .goals)
        try container.encodeIfPresent(strengths, forKey: .strengths)
        try container.encodeIfPresent(challenges, forKey: .challenges)
        try container.encodeIfPresent(lastProfilePrompt, forKey: .lastProfilePrompt)
        try container.encodeIfPresent(profileCompletionScore, forKey: .profileCompletionScore)
        try container.encodeIfPresent(isSelf, forKey: .isSelf)

        // Encode started_working_together as date-only string if present
        if let date = startedWorkingTogether {
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withFullDate]
            try container.encode(formatter.string(from: date), forKey: .startedWorkingTogether)
        } else {
            try container.encodeNil(forKey: .startedWorkingTogether)
        }
    }
}