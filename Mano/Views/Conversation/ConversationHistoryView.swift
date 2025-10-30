//
//  ConversationHistoryView.swift
//  Mano
//
//  Extracted from ConversationView.swift
//

import SwiftUI

struct ConversationHistoryView: View {
    let person: Person
    @State private var conversations: [Conversation] = []
    @State private var isLoading = true
    @State private var selectedConversation: Conversation? = nil
    @State private var conversationMessages: [UUID: [Message]] = [:]
    @ObservedObject private var supabase = SupabaseManager.shared
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    ProgressView("Loading conversation history...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if conversations.isEmpty {
                    ContentUnavailableView(
                        "No Conversation History",
                        systemImage: "clock.arrow.circlepath",
                        description: Text("You haven't had any previous conversations with \(person.name) yet.")
                    )
                } else {
                    conversationList
                }
            }
            .navigationTitle("History")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .task {
                await loadConversationHistory()
            }
            .sheet(item: $selectedConversation) { conversation in
                ConversationDetailView(
                    conversation: conversation,
                    person: person,
                    messages: conversationMessages[conversation.id] ?? [],
                    highlightedMessageId: nil
                )
            }
        }
    }

    private var conversationList: some View {
        List {
            ForEach(conversations) { conversation in
                ConversationHistoryRow(
                    conversation: conversation,
                    person: person,
                    onTap: {
                        Task {
                            await loadMessages(for: conversation)
                            selectedConversation = conversation
                        }
                    }
                )
            }
        }
    }

    private func loadConversationHistory() async {
        isLoading = true
        do {
            conversations = try await supabase.conversations.fetchConversations(for: person.id)
            print("✅ Loaded \(conversations.count) conversations for \(person.name)")
        } catch {
            print("❌ Failed to load conversation history: \(error)")
        }
        isLoading = false
    }

    private func loadMessages(for conversation: Conversation) async {
        do {
            let messages = try await supabase.conversations.fetchMessagesForConversation(conversation.id)
            conversationMessages[conversation.id] = messages
            print("✅ Loaded \(messages.count) messages for conversation \(conversation.id)")
        } catch {
            print("❌ Failed to load messages for conversation: \(error)")
        }
    }
}
