//
//  ProgressiveRevealText.swift
//  Mano
//
//  Progressive reveal animation for AI messages
//

import SwiftUI

struct ProgressiveRevealText: View {
    let content: String
    let isStreaming: Bool
    let animationDelay: Double = 0.1

    @State private var visibleWords: Set<Int> = []
    @State private var animationTimer: Timer?

    private var words: [String] {
        content.components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
    }

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            VStack(alignment: .leading, spacing: 8) {
                FlowLayout(spacing: 4) {
                    ForEach(Array(words.enumerated()), id: \.offset) { index, word in
                        Text(word + " ")
                            .font(.body)
                            .foregroundColor(.primary)
                            .opacity(visibleWords.contains(index) ? 1 : 0)
                            .scaleEffect(visibleWords.contains(index) ? 1 : 0.8)
                            .animation(
                                .spring(duration: 0.4, bounce: 0.2)
                                .delay(Double(index) * animationDelay),
                                value: visibleWords.contains(index)
                            )
                    }

                    // Streaming cursor
                    if isStreaming {
                        Text("|")
                            .font(.body)
                            .foregroundColor(.primary)
                            .opacity(0.7)
                            .animation(
                                .easeInOut(duration: 0.8).repeatForever(autoreverses: true),
                                value: isStreaming
                            )
                    }
                }
            }

            Spacer()
        }
        .onAppear {
            startRevealAnimation()
        }
        .onDisappear {
            animationTimer?.invalidate()
        }
        .onChange(of: content) { _, _ in
            restartAnimation()
        }
    }

    private func startRevealAnimation() {
        visibleWords.removeAll()
        animationTimer?.invalidate()

        var currentIndex = 0
        animationTimer = Timer.scheduledTimer(withTimeInterval: animationDelay, repeats: true) { _ in
            if currentIndex < words.count {
                withAnimation {
                    visibleWords.insert(currentIndex)
                }
                currentIndex += 1
            } else {
                animationTimer?.invalidate()
            }
        }
    }

    private func restartAnimation() {
        animationTimer?.invalidate()
        startRevealAnimation()
    }
}

// Flow layout for word wrapping
struct FlowLayout: Layout {
    let spacing: CGFloat

    init(spacing: CGFloat = 8) {
        self.spacing = spacing
    }

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let sizes = subviews.map { $0.sizeThatFits(.unspecified) }
        return layout(sizes: sizes, proposal: proposal).size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let sizes = subviews.map { $0.sizeThatFits(.unspecified) }
        let positions = layout(sizes: sizes, proposal: proposal).positions

        for (index, subview) in subviews.enumerated() {
            subview.place(at: positions[index], proposal: .unspecified)
        }
    }

    private func layout(sizes: [CGSize], proposal: ProposedViewSize) -> (size: CGSize, positions: [CGPoint]) {
        let containerWidth = proposal.width ?? .infinity
        var positions: [CGPoint] = []
        var currentPosition = CGPoint.zero
        var lineHeight: CGFloat = 0
        var maxWidth: CGFloat = 0

        for size in sizes {
            if currentPosition.x + size.width > containerWidth && currentPosition.x > 0 {
                // Move to next line
                currentPosition.x = 0
                currentPosition.y += lineHeight + spacing
                lineHeight = 0
            }

            positions.append(currentPosition)
            currentPosition.x += size.width + spacing
            lineHeight = max(lineHeight, size.height)
            maxWidth = max(maxWidth, currentPosition.x)
        }

        let totalHeight = currentPosition.y + lineHeight
        return (CGSize(width: maxWidth, height: totalHeight), positions)
    }
}

#Preview {
    VStack {
        ProgressiveRevealText(
            content: "This is a sample message with multiple words that will appear progressively with a smooth animation.",
            isStreaming: true
        )
        .padding()

        ProgressiveRevealText(
            content: "Short message.",
            isStreaming: false
        )
        .padding()
    }
}