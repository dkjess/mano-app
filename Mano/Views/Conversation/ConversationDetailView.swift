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
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
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
                            MessageBubbleView(message: message, isStreaming: false)
                                .padding(.horizontal)
                        }
                    }
                }
                .padding(.top)
            }
            .navigationTitle(conversationTitle)
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .primaryAction) {
                    Button(action: exportConversation) {
                        Image(systemName: "square.and.arrow.up")
                    }
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
