//
//  PinnedView.swift
//  Mano
//
//  Created by Claude on 13/10/2025.
//

import SwiftUI

struct PinnedView: View {
    private let pinnedService = PinnedMessageService.shared
    @State private var pinnedMessages: [PinnedMessage] = []
    @State private var isLoading = true
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
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
            .navigationTitle("📌 Pinned Advice")
            .task {
                await loadPinnedMessages()
            }
            .refreshable {
                await loadPinnedMessages()
            }
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
                PinnedMessageRow(pinnedMessage: pin)
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
            errorMessage = error.localizedDescription
            isLoading = false
            print("❌ Error loading pinned messages: \(error)")
        }
    }

    private func unpinMessage(_ pin: PinnedMessage) async {
        do {
            try await pinnedService.unpinMessage(messageId: pin.messageId)
            await loadPinnedMessages() // Refresh list
        } catch {
            print("❌ Error unpinning message: \(error)")
        }
    }
}

struct PinnedMessageRow: View {
    let pinnedMessage: PinnedMessage

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Message content (truncated)
            if let content = pinnedMessage.messageContent {
                Text(content)
                    .font(.body)
                    .lineLimit(3)
                    .foregroundColor(.primary)
            }

            // Metadata row
            HStack(spacing: 12) {
                // Person
                if let emoji = pinnedMessage.personEmoji, let name = pinnedMessage.personName {
                    Label {
                        Text(name)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } icon: {
                        Text(emoji)
                            .font(.caption)
                    }
                }

                // Topic
                if let topic = pinnedMessage.topicTitle {
                    Label(topic, systemImage: "tag")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                // Date
                if let messageDate = pinnedMessage.messageCreatedAt {
                    Text(messageDate, style: .date)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
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
}

#Preview {
    PinnedView()
}
