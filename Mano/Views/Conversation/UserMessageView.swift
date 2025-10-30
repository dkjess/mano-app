//
//  UserMessageView.swift
//  Mano
//
//  User message view - NO BUBBLES, right-aligned text only
//

import SwiftUI

@available(iOS 26.0, *)
struct UserMessageView: View {
    let message: Message

    var body: some View {
        VStack(alignment: .trailing, spacing: Spacing.sm) {
            Text(message.content)
                .font(.system(size: 17))
                .foregroundColor(.primaryText)
                .lineSpacing(8)
                .frame(maxWidth: .infinity, alignment: .trailing)
                .fixedSize(horizontal: false, vertical: true)

            Text(message.createdAt.formatted(date: .abbreviated, time: .shortened))
                .font(.system(size: 12))
                .foregroundColor(.tertiaryText)
        }
        .frame(maxWidth: .infinity, alignment: .trailing)
    }
}
