//
//  ConversationHistoryRow.swift
//  Mano
//
//  Extracted from ConversationView.swift
//

import SwiftUI

struct ConversationHistoryRow: View {
    let conversation: Conversation
    let person: Person
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(conversationTitle)
                        .font(.headline)
                        .foregroundColor(.primary)
                        .lineLimit(2)

                    Spacer()

                    if conversation.isActive {
                        Text("Active")
                            .font(.caption)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(Color.green.opacity(0.2))
                            .foregroundColor(.green)
                            .cornerRadius(4)
                    }
                }

                HStack {
                    Text("Started: \(DateFormatter.conversationDate.string(from: conversation.createdAt))")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Spacer()

                    Text("Updated: \(DateFormatter.conversationDate.string(from: conversation.updatedAt))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.vertical, 4)
        }
        .buttonStyle(PlainButtonStyle())
    }

    private var conversationTitle: String {
        conversation.title ?? "Conversation with \(person.name)"
    }
}

extension DateFormatter {
    static let conversationDate: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()
}
