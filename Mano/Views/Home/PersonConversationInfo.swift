//
//  PersonConversationInfo.swift
//  Mano
//
//  Created by Claude Code on 27/09/2025.
//

import SwiftUI
import Foundation
import Combine

struct PersonConversationInfo {
    let personId: UUID
    let activeConversationTitle: String?
    let messageCount: Int
    let lastMessageDate: Date?

    var displayTitle: String {
        if let title = activeConversationTitle, !title.isEmpty {
            return title
        }
        return messageCount > 0 ? "Conversation" : "No messages yet"
    }

    var displaySubtitle: String? {
        guard messageCount > 0 else { return nil }

        if let lastDate = lastMessageDate {
            let formatter = RelativeDateTimeFormatter()
            formatter.unitsStyle = .abbreviated
            return "Last: \(formatter.localizedString(for: lastDate, relativeTo: Date()))"
        }

        return "\(messageCount) message\(messageCount == 1 ? "" : "s")"
    }
}

@MainActor
class PersonConversationInfoLoader: ObservableObject {
    @Published var conversationInfo: [UUID: PersonConversationInfo] = [:]
    @Published var isLoading: Set<UUID> = []

    private let conversationManager = SupabaseManager.shared.conversations

    func loadConversationInfo(for personId: UUID) async {
        // Avoid duplicate loading
        guard !isLoading.contains(personId) else { return }

        isLoading.insert(personId)

        do {
            // Get active conversation for this person
            if let activeConversation = try await conversationManager.getActiveConversation(for: personId) {
                // Get message count for the active conversation
                let messages = try await conversationManager.fetchMessagesForConversation(activeConversation.id)

                let info = PersonConversationInfo(
                    personId: personId,
                    activeConversationTitle: activeConversation.title,
                    messageCount: messages.count,
                    lastMessageDate: messages.last?.createdAt
                )

                conversationInfo[personId] = info
            } else {
                // No active conversation
                let info = PersonConversationInfo(
                    personId: personId,
                    activeConversationTitle: nil,
                    messageCount: 0,
                    lastMessageDate: nil
                )

                conversationInfo[personId] = info
            }
        } catch {
            print("❌ Failed to load conversation info for person \(personId): \(error)")

            // Set empty info on error
            let info = PersonConversationInfo(
                personId: personId,
                activeConversationTitle: nil,
                messageCount: 0,
                lastMessageDate: nil
            )

            conversationInfo[personId] = info
        }

        isLoading.remove(personId)
    }

    func refresh() {
        conversationInfo.removeAll()
        isLoading.removeAll()
    }
}