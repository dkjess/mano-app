//
//  NewConversationSheet.swift
//  Mano
//
//  Extracted from ConversationView.swift
//

import SwiftUI

struct NewConversationSheet: View {
    let person: Person
    let onNewConversation: () -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                VStack(spacing: 8) {
                    Image(systemName: "plus.message.fill")
                        .font(.system(size: 60))
                        .foregroundColor(.accentColor)

                    Text("Start New Conversation")
                        .font(.title2)
                        .fontWeight(.semibold)

                    Text("This will start a fresh conversation with \(person.name). Your current conversation will be saved in history.")
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }

                Spacer()

                VStack(spacing: 12) {
                    Button(action: {
                        onNewConversation()
                        dismiss()
                    }) {
                        Text("Start New Conversation")
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.accentColor)
                            .cornerRadius(12)
                    }

                    Button(action: {
                        dismiss()
                    }) {
                        Text("Cancel")
                            .font(.headline)
                            .foregroundColor(.accentColor)
                    }
                }
                .padding(.horizontal)
            }
            .padding()
            .navigationTitle("New Conversation")
            .navigationBarTitleDisplayMode(.large)
        }
    }
}
