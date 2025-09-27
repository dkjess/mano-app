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

    init(message: Message, isStreaming: Bool = false) {
        self.message = message
        self.isStreaming = isStreaming
    }

    var body: some View {
        if message.isUser {
            // User messages: Keep blue bubbles with right alignment
            userMessageView
        } else {
            // AI messages: Full-width, no bubble
            aiMessageView
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
            // Full-width AI message with streaming support
            HStack {
                if isStreaming {
                    // Use StreamingTextView for smooth animations
                    StreamingTextView(text: message.content.replacingOccurrences(of: "|", with: ""))
                        .font(.body)
                        .foregroundColor(.primary)
                        .multilineTextAlignment(.leading)
                } else {
                    Text(message.content.replacingOccurrences(of: "|", with: ""))
                        .font(.body)
                        .foregroundColor(.primary)
                        .multilineTextAlignment(.leading)
                }
                Spacer()
            }

            // Timestamp aligned to left
            HStack {
                Text(timeString(from: message.createdAt))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
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
            createdAt: Date()
        )
    )
    .padding()
}