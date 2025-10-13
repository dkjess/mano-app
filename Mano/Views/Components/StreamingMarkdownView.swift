//
//  StreamingMarkdownView.swift
//  Mano
//
//  A view that displays streaming markdown text with smooth fade-in animations
//  Similar to Apple Foundation Models example - no cursor, just smooth text appearance
//

import SwiftUI

struct StreamingMarkdownView: View {
    let text: String
    let isUserMessage: Bool
    @State private var displayedText = ""
    @State private var opacity: Double = 0

    var body: some View {
        MarkdownView(content: displayedText, isUserMessage: isUserMessage)
            .opacity(opacity)
            .onAppear {
                // Initial fade in for the whole view
                withAnimation(.easeIn(duration: 0.2)) {
                    opacity = 1
                }
            }
            .onChange(of: text) { oldValue, newValue in
                if newValue.count > oldValue.count {
                    // New text was added - append smoothly
                    withAnimation(.easeOut(duration: 0.15)) {
                        displayedText = newValue
                    }
                } else if newValue.isEmpty {
                    // Reset when text is cleared
                    displayedText = ""
                    opacity = 0
                }
            }
    }
}

#Preview {
    @Previewable @State var streamingText = ""

    VStack(spacing: 20) {
        StreamingMarkdownView(text: streamingText, isUserMessage: false)
            .padding()
            .background(Color.gray.opacity(0.1))
            .cornerRadius(12)

        Button("Simulate Markdown Streaming") {
            Task {
                let chunks = [
                    "**Welcome!** ",
                    "I'm here to help. ",
                    "\n\nHere's what I can do:\n",
                    "- Help with *management* challenges\n",
                    "- Spot patterns you might miss\n",
                    "- Think through `tricky situations`"
                ]

                streamingText = ""

                for chunk in chunks {
                    streamingText += chunk
                    try? await Task.sleep(nanoseconds: 300_000_000) // 300ms
                }
            }
        }
    }
    .padding()
}
