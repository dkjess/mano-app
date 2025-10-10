//
//  CachedPerson.swift
//  Mano
//
//  SwiftData model for caching Person data
//

import Foundation
import SwiftData

@Model
final class CachedPerson {
    @Attribute(.unique) var id: UUID
    var userId: UUID
    var name: String
    var role: String?
    var relationshipType: String
    var team: String?
    var location: String?
    var createdAt: Date
    var updatedAt: Date
    var notes: String?
    var emoji: String?
    var startDate: Date?
    var communicationStyle: String?
    var goals: String?
    var strengths: String?
    var challenges: String?
    var lastProfilePrompt: Date?
    var profileCompletionScore: Int?
    var isSelf: Bool?
    var startedWorkingTogether: Date?

    // Cache metadata
    var lastFetchedAt: Date

    init(from person: Person) {
        self.id = person.id
        self.userId = person.userId
        self.name = person.name
        self.role = person.role
        self.relationshipType = person.relationshipType
        self.team = person.team
        self.location = person.location
        self.createdAt = person.createdAt
        self.updatedAt = person.updatedAt
        self.notes = person.notes
        self.emoji = person.emoji
        self.startDate = person.startDate
        self.communicationStyle = person.communicationStyle
        self.goals = person.goals
        self.strengths = person.strengths
        self.challenges = person.challenges
        self.lastProfilePrompt = person.lastProfilePrompt
        self.profileCompletionScore = person.profileCompletionScore
        self.isSelf = person.isSelf
        self.startedWorkingTogether = person.startedWorkingTogether
        self.lastFetchedAt = Date()
    }

    func toPerson() -> Person {
        Person(
            id: id,
            userId: userId,
            name: name,
            role: role,
            relationshipType: relationshipType,
            team: team,
            location: location,
            createdAt: createdAt,
            updatedAt: updatedAt,
            notes: notes,
            emoji: emoji,
            startDate: startDate,
            communicationStyle: communicationStyle,
            goals: goals,
            strengths: strengths,
            challenges: challenges,
            lastProfilePrompt: lastProfilePrompt,
            profileCompletionScore: profileCompletionScore,
            isSelf: isSelf,
            startedWorkingTogether: startedWorkingTogether
        )
    }
}
