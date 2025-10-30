//
//  PinnedView.swift
//  Mano
//
//  Created by Claude on 13/10/2025.
//

import SwiftUI
import Supabase

// NSURLError constants
private let NSURLErrorCancelled = -999

struct PinnedView: View {
    private let pinnedService = PinnedMessageService.shared
    private let supabase = SupabaseManager.shared.client
    @ObservedObject private var pinnedManager = PinnedMessagesManager.shared
    @ObservedObject private var supabaseManager = SupabaseManager.shared
    @State private var pinnedMessages: [PinnedMessage] = []
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var realtimeTask: Task<Void, Never>?
    @State private var selectedPerson: Person? = nil

    var body: some View {
        Group {
            if isLoading {
                ProgressView("Loading pinned advice...")
            } else if let error = errorMessage {
                ContentUnavailableView(
                    "Error Loading Pins",
                    systemImage: "exclamationmark.triangle",
                    description: Text(error)
                )
            } else if pinnedMessages.isEmpty {
                emptyState
            } else {
                pinnedList
            }
        }
        .navigationTitle("Pins")
        .navigationBarTitleDisplayMode(.large)
        .navigationDestination(item: $selectedPerson) { person in
            ConversationView(person: person)
        }
        .task {
            await loadPinnedMessages()
            await subscribeToUpdates()
            // Sync the manager cache with current pins
            await pinnedManager.refresh()
        }
        .refreshable {
            await loadPinnedMessages()
            await pinnedManager.refresh()
        }
        .onDisappear {
            realtimeTask?.cancel()
        }
    }

    private var emptyState: some View {
        ContentUnavailableView(
            "No Pinned Advice Yet",
            systemImage: "pin.slash",
            description: Text("Long press any message to pin it for later reference")
        )
    }

    private var pinnedList: some View {
        List {
            ForEach(pinnedMessages) { pin in
                Group {
                    if let personId = pin.personId, pin.conversationId != nil {
                        // Message has conversation - enable navigation to actual conversation
                        Button(action: {
                            Task {
                                await navigateToPinnedConversation(personId: personId)
                            }
                        }) {
                            PinnedMessageRow(pinnedMessage: pin)
                        }
                        .buttonStyle(.plain)
                    } else {
                        // Old message without conversation - show but no navigation
                        PinnedMessageRow(pinnedMessage: pin)
                            .opacity(0.7)
                            .overlay(alignment: .trailing) {
                                Image(systemName: "info.circle")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .padding(.trailing, 8)
                                    .help("Legacy message - conversation not available")
                            }
                    }
                }
                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                    Button(role: .destructive) {
                        Task {
                            await unpinMessage(pin)
                        }
                    } label: {
                        Label("Unpin", systemImage: "pin.slash")
                    }
                }
            }
        }
        .listStyle(.plain)
    }

    private func loadPinnedMessages() async {
        isLoading = true
        errorMessage = nil

        do {
            pinnedMessages = try await pinnedService.fetchPinnedMessages()
            isLoading = false
        } catch {
            // Ignore cancellation errors (happens when view dismisses or pull-to-refresh interrupts)
            if (error as NSError).code == NSURLErrorCancelled {
                return
            }

            errorMessage = error.localizedDescription
            isLoading = false
            print("❌ Error loading pinned messages: \(error)")
        }
    }

    private func unpinMessage(_ pin: PinnedMessage) async {
        // Optimistically remove from local array
        await MainActor.run {
            withAnimation {
                pinnedMessages.removeAll { $0.id == pin.id }
            }
        }

        do {
            try await pinnedManager.unpinMessage(messageId: pin.messageId)
            print("✅ Unpinned message: \(pin.messageId)")
        } catch {
            print("❌ Error unpinning message: \(error)")
            // On error, reload to restore state
            await loadPinnedMessages()
        }
    }

    private func subscribeToUpdates() async {
        realtimeTask = Task {
            // Poll every 5 seconds to check for title updates
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 5_000_000_000) // 5 seconds

                // Only reload if there are pins with missing titles
                if pinnedMessages.contains(where: { $0.title == nil }) {
                    await loadPinnedMessages()
                }
            }
        }
    }

    private func navigateToPinnedConversation(personId: UUID) async {
        // Try to find person in cache first
        let cachedPeople = await CacheManager.shared.getCachedPeople()
        if let cachedPerson = cachedPeople.first(where: { $0.id == personId }) {
            await MainActor.run {
                selectedPerson = cachedPerson
            }
            return
        }

        // If not in cache, fetch from database
        do {
            let people = try await supabaseManager.people.fetchPeople()
            if let person = people.first(where: { $0.id == personId }) {
                await MainActor.run {
                    selectedPerson = person
                }
            } else {
                print("❌ Person not found for pinned message: \(personId)")
            }
        } catch {
            print("❌ Error fetching person for navigation: \(error)")
        }
    }
}

struct PinnedMessageRow: View {
    let pinnedMessage: PinnedMessage

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Title (AI-generated or placeholder)
            Text(pinnedMessage.title ?? "Generating title...")
                .font(.headline)
                .fontWeight(.semibold)
                .foregroundColor(.primary)
                .lineLimit(2)

            // Context line: Person + Topic
            HStack(spacing: 6) {
                if let emoji = pinnedMessage.personEmoji, let name = pinnedMessage.personName {
                    Text(emoji)
                        .font(.caption)
                    Text(name)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                if pinnedMessage.personName != nil && pinnedMessage.topicTitle != nil {
                    Text("•")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }

                if let topic = pinnedMessage.topicTitle {
                    Text(topic)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            // Preview of message content
            if let content = pinnedMessage.messageContent {
                Text(content)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }

            // Timestamp
            HStack {
                Text(relativeTimeString(from: pinnedMessage.pinnedAt))
                    .font(.caption)
                    .foregroundStyle(.tertiary)

                Spacer()

                // Pin icon indicator
                Image(systemName: "pin.fill")
                    .font(.caption2)
                    .foregroundStyle(.blue)
            }

            // Optional note
            if let note = pinnedMessage.note, !note.isEmpty {
                Text(note)
                    .font(.caption)
                    .italic()
                    .foregroundColor(.blue)
                    .padding(.top, 4)
            }
        }
        .padding(.vertical, 8)
    }

    private func relativeTimeString(from date: Date) -> String {
        let calendar = Calendar.current
        let now = Date()

        let components = calendar.dateComponents([.day, .hour, .minute], from: date, to: now)

        if let days = components.day, days > 0 {
            if days == 1 {
                return "Yesterday"
            } else if days < 7 {
                return "\(days) days ago"
            } else if days < 30 {
                let weeks = days / 7
                return weeks == 1 ? "Last week" : "\(weeks) weeks ago"
            } else {
                let formatter = DateFormatter()
                formatter.dateStyle = .medium
                return formatter.string(from: date)
            }
        } else if let hours = components.hour, hours > 0 {
            return hours == 1 ? "1 hour ago" : "\(hours) hours ago"
        } else if let minutes = components.minute, minutes > 0 {
            return minutes == 1 ? "1 minute ago" : "\(minutes) minutes ago"
        } else {
            return "Just now"
        }
    }
}

#Preview {
    PinnedView()
}
