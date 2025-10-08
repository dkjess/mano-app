//
//  InputComposer.swift
//  Mano
//
//  Created by Claude on 06/09/2025.
//

import SwiftUI
import PhotosUI
import UniformTypeIdentifiers

struct InputComposer: View {
    let person: Person
    @Binding var messageText: String
    @Binding var isSending: Bool
    @FocusState var isInputFocused: Bool
    
    let onSendMessage: () -> Void

    var canSend: Bool {
        !messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isSending
    }
    
    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            // Text input area with integrated send button
            ZStack(alignment: .bottomTrailing) {
                // Placeholder
                if messageText.isEmpty && !isInputFocused {
                    Text("Talk about \(person.name)...")
                        .foregroundStyle(.tertiary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .allowsHitTesting(false)
                }

                // Text editor with padding for send button
                TextEditor(text: $messageText)
                    .scrollContentBackground(.hidden)
                    .padding(.leading, 12)
                    .padding(.trailing, hasContent || isInputFocused ? 48 : 12) // Extra padding for button
                    .padding(.vertical, 8)
                    .frame(minHeight: 36, maxHeight: isInputFocused ? 120 : 60)
                    .fixedSize(horizontal: false, vertical: isInputFocused ? false : true)
                    .focused($isInputFocused)

                // Send button inside the input area - bottom right
                if hasContent || isInputFocused {
                    Button(action: onSendMessage) {
                        Image(systemName: "arrow.up")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(width: 32, height: 32)
                            .background(canSend ? Color.blue : Color.gray.opacity(0.5), in: Circle())
                            .scaleEffect(isSending ? 0.9 : 1.0)
                            .animation(.spring(response: 0.2, dampingFraction: 0.7), value: isSending)
                    }
                    .disabled(!canSend)
                    .keyboardShortcut(.return, modifiers: .command)
                    .padding(.trailing, 8)
                    .padding(.bottom, 6)
                    .transition(.scale.combined(with: .opacity))
                }
            }
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(isInputFocused ? AnyShapeStyle(.white) : AnyShapeStyle(.ultraThinMaterial))
            )
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
        .padding(.horizontal, 12)
        .padding(.bottom, 12)
        .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
    }
    private var hasContent: Bool {
        !messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}

#Preview {
    @Previewable @State var messageText = ""
    @Previewable @State var isSending = false
    
    InputComposer(
        person: Person(
            id: UUID(),
            userId: UUID(),
            name: "Alice Johnson",
            role: "Senior Engineer",
            relationshipType: "direct_report",
            team: "Engineering",
            location: "San Francisco",
            createdAt: Date(),
            updatedAt: Date(),
            notes: nil,
            emoji: "👩‍💻",
            startDate: nil,
            communicationStyle: nil,
            goals: nil,
            strengths: nil,
            challenges: nil,
            lastProfilePrompt: nil,
            profileCompletionScore: 20,
            isSelf: false,
            startedWorkingTogether: nil
        ),
        messageText: $messageText,
        isSending: $isSending,
        onSendMessage: {}
    )
    .padding()
}
