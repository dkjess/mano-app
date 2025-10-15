//
//  MessageBubbleView.swift
//  Mano
//
//  Created by Jess Wambui Olsen on 31/08/2025.
//

import SwiftUI

struct MessageBubbleView: View {
    let message: Message
    let isStreaming: Bool

    private let pinnedService = PinnedMessageService.shared
    @State private var isPinned = false
    @State private var showingPinConfirmation = false

    init(message: Message, isStreaming: Bool = false) {
        self.message = message
        self.isStreaming = isStreaming
    }

    var body: some View {
        Group {
            if message.isUser {
                // User messages: Keep blue bubbles with right alignment
                userMessageView
            } else {
                // AI messages: Full-width, no bubble with context menu
                aiMessageView
                    .contextMenu {
                        // Pin/Unpin button
                        Button {
                            Task {
                                await togglePin()
                            }
                        } label: {
                            Label(isPinned ? "Unpin Advice" : "Pin Advice", systemImage: isPinned ? "pin.slash" : "pin")
                        }

                        // Copy button
                        Button {
                            UIPasteboard.general.string = message.content
                        } label: {
                            Label("Copy", systemImage: "doc.on.doc")
                        }

                        // Share button
                        Button {
                            shareMessage()
                        } label: {
                            Label("Share", systemImage: "square.and.arrow.up")
                        }
                    }
            }
        }
        .task {
            await checkIfPinned()
        }
    }

    private var userMessageView: some View {
        HStack(alignment: .bottom, spacing: 8) {
            Spacer(minLength: 60)

            VStack(alignment: .trailing, spacing: 4) {
                MarkdownView(content: message.content, isUserMessage: true)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 18)
                            .fill(Color.blue)
                    )
                    .foregroundStyle(.white)
                    .textSelection(.enabled)

                Text(timeString(from: message.createdAt))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 4)
            }
        }
        .padding(.horizontal, 4)
    }

    private var aiMessageView: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Full-width AI message with streaming support and markdown rendering
            HStack(alignment: .top) {
                if isStreaming {
                    // Use StreamingMarkdownView for smooth animations with markdown
                    StreamingMarkdownView(
                        text: message.content.replacingOccurrences(of: "|", with: ""),
                        isUserMessage: false
                    )
                    .font(.body)
                    .foregroundColor(.primary)
                } else {
                    // Use MarkdownView for completed messages
                    MarkdownView(
                        content: message.content.replacingOccurrences(of: "|", with: ""),
                        isUserMessage: false
                    )
                    .font(.body)
                    .foregroundColor(.primary)
                }
                Spacer()
            }

            // Timestamp and pin indicator aligned to left
            HStack(spacing: 6) {
                Text(timeString(from: message.createdAt))
                    .font(.caption2)
                    .foregroundStyle(.secondary)

                // Show pin indicator if message is pinned
                if isPinned {
                    Image(systemName: "pin.fill")
                        .font(.caption2)
                        .foregroundStyle(.blue)
                }

                Spacer()
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }
    
    private func timeString(from date: Date) -> String {
        let formatter = DateFormatter()
        let calendar = Calendar.current

        if calendar.isDateInToday(date) {
            formatter.dateFormat = "h:mm a"
        } else if calendar.isDateInYesterday(date) {
            formatter.dateFormat = "'Yesterday' h:mm a"
        } else {
            formatter.dateFormat = "MMM d, h:mm a"
        }

        return formatter.string(from: date)
    }

    // MARK: - Pin Management

    private func checkIfPinned() async {
        do {
            isPinned = try await pinnedService.isMessagePinned(messageId: message.id)
        } catch {
            print("❌ Error checking pin status: \(error)")
        }
    }

    private func togglePin() async {
        do {
            if isPinned {
                try await pinnedService.unpinMessage(messageId: message.id)
                isPinned = false
            } else {
                try await pinnedService.pinMessage(
                    messageId: message.id,
                    personId: message.personId,
                    topicId: message.topicId
                )
                isPinned = true
                showingPinConfirmation = true

                // Add haptic feedback
                #if os(iOS)
                let generator = UINotificationFeedbackGenerator()
                generator.notificationOccurred(.success)
                #endif
            }
        } catch {
            print("❌ Error toggling pin: \(error)")
        }
    }

    private func shareMessage() {
        #if os(iOS)
        let activityVC = UIActivityViewController(
            activityItems: [message.content],
            applicationActivities: nil
        )

        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootVC = windowScene.windows.first?.rootViewController {
            rootVC.present(activityVC, animated: true)
        }
        #endif
    }
}

#Preview {
    MessageBubbleView(
        message: Message(
            id: UUID(),
            userId: UUID(),
            content: "Hello! This is a sample message to preview the bubble design.",
            isUser: true,
            personId: nil,
            topicId: nil,
            conversationId: nil,
            createdAt: Date()
        )
    )
    .padding()
}