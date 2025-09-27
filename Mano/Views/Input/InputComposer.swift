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
    
    @State private var backgroundOpacity: Double = 0.8
    
    var canSend: Bool {
        !messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isSending
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Input area and send button as separate elements
            HStack(alignment: .bottom, spacing: 12) {
                // Text input area
                ZStack(alignment: .leading) {
                    if messageText.isEmpty && !isInputFocused {
                        Text("Talk about \(person.name)...")
                            .foregroundStyle(.tertiary)
                            .padding(.horizontal, 12)
                            .allowsHitTesting(false)
                    }

                    TextEditor(text: $messageText)
                        .scrollContentBackground(.hidden)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .frame(minHeight: 36, maxHeight: isInputFocused ? 120 : 60) // More reasonable heights
                        .fixedSize(horizontal: false, vertical: isInputFocused ? false : true) // Only allow scrolling when focused
                        .focused($isInputFocused)
                }
                .frame(maxWidth: .infinity)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(isInputFocused ? AnyShapeStyle(.white) : AnyShapeStyle(.ultraThinMaterial))
                        .shadow(color: .black.opacity(0.08), radius: 4, x: 0, y: 2)
                )

                // Send button outside the input area - show when focused or has content
                if hasContent || isInputFocused {
                    Button(action: onSendMessage) {
                        Image(systemName: "arrow.up")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(width: 36, height: 36)
                            .background(canSend ? Color.blue : Color.gray.opacity(0.5), in: Circle())
                            .scaleEffect(isSending ? 0.9 : 1.0)
                            .animation(.spring(response: 0.2, dampingFraction: 0.7), value: isSending)
                    }
                    .disabled(!canSend)
                    .keyboardShortcut(.return, modifiers: .command)
                    .transition(.scale.combined(with: .opacity))
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .onChange(of: isInputFocused) { _, focused in
                withAnimation(.easeInOut(duration: 0.25)) {
                    backgroundOpacity = focused ? 0.4 : 0.8
                }
            }
        }
        .background(
            Rectangle()
                .fill(.ultraThinMaterial)
                .opacity(backgroundOpacity)
                .ignoresSafeArea(.container, edges: .bottom)
        )
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
            isSelf: false
        ),
        messageText: $messageText,
        isSending: $isSending,
        onSendMessage: {}
    )
    .padding()
}
