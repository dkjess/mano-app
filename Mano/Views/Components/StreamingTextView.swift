//
//  StreamingTextView.swift
//  Mano
//
//  A view that displays streaming text with smooth fade-in animations
//

import SwiftUI

struct StreamingTextView: View {
    let text: String
    @State private var displayedText = ""
    @State private var opacity: Double = 0

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            // Display all text as one continuous block with smooth reveal
            Text(displayedText)
                .opacity(opacity)

            // Typing cursor when still streaming
            if displayedText.count < text.count {
                Text("|")
                    .foregroundStyle(.secondary)
                    .opacity(0.6)
                    .animation(.easeInOut(duration: 0.5).repeatForever(autoreverses: true), value: displayedText)
            }
        }
        .onAppear {
            // Initial fade in for the whole view
            withAnimation(.easeIn(duration: 0.2)) {
                opacity = 1
            }
        }
        .onChange(of: text) { oldValue, newValue in
            if newValue.count > oldValue.count {
                // New text was added - append immediately with smooth animation
                let newContent = String(newValue.dropFirst(oldValue.count))

                withAnimation(.spring(response: 0.15, dampingFraction: 1.0)) {
                    displayedText += newContent
                }
            } else if newValue.isEmpty {
                // Reset when text is cleared
                displayedText = ""
            }
        }
    }
}

#Preview {
    @Previewable @State var streamingText = ""

    VStack {
        StreamingTextView(text: streamingText)
            .padding()
            .background(Color.blue.opacity(0.1))
            .cornerRadius(12)
            .padding()

        Button("Simulate Streaming") {
            Task {
                let message = "Hello! This is a streaming message that will appear word by word with smooth animations."
                streamingText = ""

                for word in message.split(separator: " ") {
                    streamingText += String(word) + " "
                    try? await Task.sleep(nanoseconds: 100_000_000) // 100ms
                }
            }
        }
    }
}