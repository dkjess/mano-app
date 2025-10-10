//
//  CacheManager.swift
//  Mano
//
//  SwiftData cache manager for offline functionality
//

import Foundation
import SwiftData

@MainActor
class CacheManager {
    static let shared = CacheManager()

    private(set) var modelContainer: ModelContainer?
    private var modelContext: ModelContext? {
        modelContainer?.mainContext
    }

    private init() {
        setupContainer()
    }

    private func setupContainer() {
        let schema = Schema([
            CachedPerson.self,
            CachedMessage.self,
        ])

        let modelConfiguration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false
        )

        do {
            modelContainer = try ModelContainer(
                for: schema,
                configurations: [modelConfiguration]
            )
            print("✅ SwiftData cache initialized")
        } catch {
            print("❌ Failed to initialize SwiftData cache: \(error)")
        }
    }

    // MARK: - Person Caching

    func cachePeople(_ people: [Person]) {
        guard let context = modelContext else { return }

        for person in people {
            // Check if already cached
            let descriptor = FetchDescriptor<CachedPerson>(
                predicate: #Predicate { $0.id == person.id }
            )

            if let existing = try? context.fetch(descriptor).first {
                // Update existing
                existing.name = person.name
                existing.role = person.role
                existing.relationshipType = person.relationshipType
                existing.team = person.team
                existing.location = person.location
                existing.updatedAt = person.updatedAt
                existing.notes = person.notes
                existing.emoji = person.emoji
                existing.startDate = person.startDate
                existing.communicationStyle = person.communicationStyle
                existing.goals = person.goals
                existing.strengths = person.strengths
                existing.challenges = person.challenges
                existing.lastProfilePrompt = person.lastProfilePrompt
                existing.profileCompletionScore = person.profileCompletionScore
                existing.isSelf = person.isSelf
                existing.startedWorkingTogether = person.startedWorkingTogether
                existing.lastFetchedAt = Date()
            } else {
                // Insert new
                let cached = CachedPerson(from: person)
                context.insert(cached)
            }
        }

        try? context.save()
        print("✅ Cached \(people.count) people")
    }

    func getCachedPeople() -> [Person] {
        guard let context = modelContext else { return [] }

        let descriptor = FetchDescriptor<CachedPerson>(
            sortBy: [SortDescriptor(\.name)]
        )

        guard let cached = try? context.fetch(descriptor) else { return [] }
        print("📦 Retrieved \(cached.count) cached people")
        return cached.map { $0.toPerson() }
    }

    func getCachedPerson(id: UUID) -> Person? {
        guard let context = modelContext else { return nil }

        let descriptor = FetchDescriptor<CachedPerson>(
            predicate: #Predicate { $0.id == id }
        )

        guard let cached = try? context.fetch(descriptor).first else { return nil }
        print("📦 Retrieved cached person: \(cached.name)")
        return cached.toPerson()
    }

    // MARK: - Message Caching

    func cacheMessages(_ messages: [Message], for personId: UUID) {
        guard let context = modelContext else { return }

        for message in messages {
            // Check if already cached
            let descriptor = FetchDescriptor<CachedMessage>(
                predicate: #Predicate { $0.id == message.id }
            )

            if let existing = try? context.fetch(descriptor).first {
                // Update existing
                existing.content = message.content
                existing.lastFetchedAt = Date()
            } else {
                // Insert new
                let cached = CachedMessage(from: message)
                context.insert(cached)
            }
        }

        try? context.save()
        print("✅ Cached \(messages.count) messages for person \(personId)")
    }

    func getCachedMessages(for personId: UUID) -> [Message] {
        guard let context = modelContext else { return [] }

        let descriptor = FetchDescriptor<CachedMessage>(
            predicate: #Predicate { $0.personId == personId },
            sortBy: [SortDescriptor(\.createdAt)]
        )

        guard let cached = try? context.fetch(descriptor) else { return [] }
        print("📦 Retrieved \(cached.count) cached messages for person \(personId)")
        return cached.map { $0.toMessage() }
    }

    // MARK: - Cache Management

    func clearCache() {
        guard let context = modelContext else { return }

        do {
            try context.delete(model: CachedPerson.self)
            try context.delete(model: CachedMessage.self)
            try context.save()
            print("✅ Cache cleared")
        } catch {
            print("❌ Failed to clear cache: \(error)")
        }
    }

    func getCacheSize() -> (people: Int, messages: Int) {
        guard let context = modelContext else { return (0, 0) }

        let peopleCount = (try? context.fetchCount(FetchDescriptor<CachedPerson>())) ?? 0
        let messagesCount = (try? context.fetchCount(FetchDescriptor<CachedMessage>())) ?? 0

        return (peopleCount, messagesCount)
    }
}
