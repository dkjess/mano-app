//
//  MessageBubbleView.swift
//  Mano
//
//  Created by Jess Wambui Olsen on 31/08/2025.
//

import SwiftUI

struct MessageBubbleView: View {
    let message: Message
    
    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            if message.isUser {
                Spacer(minLength: 60)
            }
            
            VStack(alignment: message.isUser ? .trailing : .leading, spacing: 4) {
                MarkdownView(content: message.content, isUserMessage: message.isUser)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 18)
                            .fill(message.isUser ? Color.blue : Color.gray.opacity(0.2))
                    )
                    .foregroundStyle(message.isUser ? .white : .primary)
                    .textSelection(.enabled)
                
                Text(timeString(from: message.createdAt))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 4)
            }
            
            if !message.isUser {
                Spacer(minLength: 60)
            }
        }
        .padding(.horizontal, 4)
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