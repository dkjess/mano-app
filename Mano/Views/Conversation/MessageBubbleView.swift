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
    let isHighlighted: Bool

    @ObservedObject private var pinnedManager = PinnedMessagesManager.shared
    @State private var showingPinConfirmation = false

    init(message: Message, isStreaming: Bool = false, isHighlighted: Bool = false) {
        self.message = message
        self.isStreaming = isStreaming
        self.isHighlighted = isHighlighted
    }

    private var isPinned: Bool {
        pinnedManager.isPinned(message.id)
    }

    var body: some View {
        Group {
            if message.isUser {
                // User messages: Keep blue bubbles with right alignment
                userMessageView
            } else {
                // AI messages: Full-width, no bubble with context menu
                // Only show context menu for non-streaming messages (streaming messages aren't in DB yet)
                if isStreaming {
                    aiMessageView
                } else {
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
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(isHighlighted ? Color.blue.opacity(0.1) : Color.clear)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(isHighlighted ? Color.blue : Color.clear, lineWidth: 2)
        )
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

    private func togglePin() async {
        print("🔴 [MessageBubble] togglePin called, isPinned: \(isPinned)")
        print("🔴 [MessageBubble] Message ID: \(message.id)")
        print("🔴 [MessageBubble] Person ID: \(String(describing: message.personId))")
        print("🔴 [MessageBubble] Topic ID: \(String(describing: message.topicId))")

        do {
            if isPinned {
                print("🔴 [MessageBubble] Attempting to unpin...")
                try await pinnedManager.unpinMessage(messageId: message.id)
                print("✅ [MessageBubble] Successfully unpinned")
            } else {
                print("🔴 [MessageBubble] Attempting to pin...")
                try await pinnedManager.pinMessage(
                    messageId: message.id,
                    personId: message.personId,
                    topicId: message.topicId
                )
                showingPinConfirmation = true
                print("✅ [MessageBubble] Successfully pinned")

                // Add haptic feedback
                #if os(iOS)
                let generator = UINotificationFeedbackGenerator()
                generator.notificationOccurred(.success)
                #endif
            }
        } catch {
            print("❌ [MessageBubble] Error toggling pin: \(error)")
            print("❌ [MessageBubble] Error details: \(error.localizedDescription)")
            if let nsError = error as NSError? {
                print("❌ [MessageBubble] Error domain: \(nsError.domain)")
                print("❌ [MessageBubble] Error code: \(nsError.code)")
                print("❌ [MessageBubble] Error userInfo: \(nsError.userInfo)")
            }
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