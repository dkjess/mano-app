//
//  PinnedMessagesManager.swift
//  Mano
//
//  Observable manager for tracking pinned message IDs across views
//

import Foundation
import SwiftUI
import Combine

@MainActor
class PinnedMessagesManager: ObservableObject {
    static let shared = PinnedMessagesManager()

    @Published private(set) var pinnedMessageIds: Set<UUID> = []

    private let pinnedService = PinnedMessageService.shared

    private init() {
        // Load initial pinned IDs
        Task {
            await refresh()
        }
    }

    /// Check if a message is pinned (in-memory lookup)
    func isPinned(_ messageId: UUID) -> Bool {
        return pinnedMessageIds.contains(messageId)
    }

    /// Refresh pinned message IDs from database
    func refresh() async {
        do {
            let pinnedMessages = try await pinnedService.fetchPinnedMessages()
            let ids = Set(pinnedMessages.map { $0.messageId })
            pinnedMessageIds = ids
        } catch {
            print("❌ [PinnedManager] Error refreshing pinned IDs: \(error)")
        }
    }

    /// Pin a message and update in-memory cache
    func pinMessage(messageId: UUID, personId: UUID?, topicId: UUID?) async throws {
        try await pinnedService.pinMessage(messageId: messageId, personId: personId, topicId: topicId)
        pinnedMessageIds.insert(messageId)
        print("✅ [PinnedManager] Added to cache: \(messageId)")
    }

    /// Unpin a message and update in-memory cache
    func unpinMessage(messageId: UUID) async throws {
        try await pinnedService.unpinMessage(messageId: messageId)
        pinnedMessageIds.remove(messageId)
        print("✅ [PinnedManager] Removed from cache: \(messageId)")
    }
}
