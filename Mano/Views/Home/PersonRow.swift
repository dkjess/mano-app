//
//  PersonRow.swift
//  Mano
//
//  Person row component for people list
//

import SwiftUI

@available(iOS 26.0, *)
struct PersonRow: View {
    let person: Person
    @ObservedObject private var conversationLoader = PersonConversationInfoLoader()

    var body: some View {
        HStack(spacing: 0) {
            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text(person.name)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(.primaryText)

                if let role = person.role {
                    Text(role)
                        .font(.system(size: 15))
                        .foregroundColor(.secondaryText)
                }

                HStack {
                    if let conversationInfo = conversationLoader.conversationInfo[person.id] {
                        Text("Last: \(conversationInfo.displaySubtitle ?? "No conversation yet")")
                            .font(.system(size: 13))
                            .foregroundColor(.tertiaryText)
                    } else {
                        Text("Last: No conversation yet")
                            .font(.system(size: 13))
                            .foregroundColor(.tertiaryText)
                    }

                    Spacer()

                    Text(person.relationshipType.replacingOccurrences(of: "_", with: " ").capitalized)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(person.relationshipType == "direct_report" ? .forestGreen : .secondaryText)
                }
            }

            Spacer()

            // Optional subtle navigation chevron
            Image(systemName: "chevron.right")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.tertiaryText)
        }
        .padding(.vertical, Spacing.base)
        .padding(.horizontal, Spacing.lg)
        .background(Color.clear) // CRITICAL: No background
        .overlay(
            Rectangle()
                .frame(height: 1)
                .foregroundColor(.stone),
            alignment: .bottom
        )
        .contentShape(Rectangle())
        .task {
            await conversationLoader.loadConversationInfo(for: person.id)
        }
    }
}
