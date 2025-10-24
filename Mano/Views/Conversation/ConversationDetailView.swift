//
//  ConversationDetailView.swift
//  Mano
//
//  Extracted from ConversationView.swift
//

import SwiftUI

struct ConversationDetailView: View {
    let conversation: Conversation
    let person: Person
    let messages: [Message]
    let highlightedMessageId: UUID?

    @Environment(\.dismiss) private var dismiss
    @State private var currentlyHighlightedId: UUID?

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(spacing: 12) {
                    if messages.isEmpty {
                        ContentUnavailableView(
                            "No Messages",
                            systemImage: "message.slash",
                            description: Text("This conversation has no messages.")
                        )
                        .padding()
                    } else {
                        ForEach(messages.sorted { $0.createdAt < $1.createdAt }) { message in
                            MessageBubbleView(
                                message: message,
                                isStreaming: false,
                                isHighlighted: currentlyHighlightedId == message.id
                            )
                            .id(message.id)
                            .padding(.horizontal)
                        }
                    }
                }
                .padding(.top)
            }
            .onAppear {
                if let targetId = highlightedMessageId {
                    // Scroll to the message after a brief delay to ensure layout is ready
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        withAnimation {
                            proxy.scrollTo(targetId, anchor: .center)
                        }

                        // Highlight the message
                        currentlyHighlightedId = targetId

                        // Remove highlight after 2 seconds
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                            withAnimation {
                                currentlyHighlightedId = nil
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle(conversationTitle)
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button(action: exportConversation) {
                    Image(systemName: "square.and.arrow.up")
                }
            }
        }
    }

    private var conversationTitle: String {
        conversation.title ?? "Conversation with \(person.name)"
    }

    private func exportConversation() {
        let conversationText = messages
            .sorted { $0.createdAt < $1.createdAt }
            .map { message in
                let sender = message.isUser ? "You" : person.name
                let timestamp = DateFormatter.localizedString(
                    from: message.createdAt,
                    dateStyle: .short,
                    timeStyle: .short
                )
                return "\(sender) (\(timestamp)): \(message.content)"
            }
            .joined(separator: "\n\n")

        let activityVC = UIActivityViewController(
            activityItems: [conversationText],
            applicationActivities: nil
        )

        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first {
            window.rootViewController?.present(activityVC, animated: true)
        }
    }
}
