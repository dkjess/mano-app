//
//  ThinkingBubbleView.swift
//  Mano
//
//  Created by Claude on 06/09/2025.
//

import SwiftUI

struct ThinkingBubbleView: View {
    @State private var animationPhase = 0
    @State private var dotCount = 0
    @State private var thinkingWord = ""
    
    let thinkingWords = [
        // Quirky favorites
        "Thinking", "Pondering", "Contemplating", "Sizzling", "Vibing",
        "Percolating", "Marinating", "Brewing", "Scheming", "Noodling",

        // Made-up delights
        "Combobulating", "Thinkifying", "Ponderfying", "Cogitativating",
        "Contemplifying", "Smarticulating", "Intelligencing", "Wisdomising",

        // Brain activities
        "Brain-noodling", "Mind-melding", "Thought-spinning", "Idea-brewing",
        "Synapse-firing", "Neuron-networking", "Grey-matter-grinding",

        // Fun processes
        "Slow-cooking", "Fermenting", "Distilling", "Tinkering",

        // Genius vibes
        "Brillianting", "Genius-ing", "Einstein-ing", "Sherlock-ing",

        // Delightful moments
        "Lightbulb-ing", "Eureka-ing", "Aha-ing", "Clicking"
    ]
    
    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle())
                        .scaleEffect(0.8)
                    
                    Text(thinkingWord + String(repeating: ".", count: dotCount))
                        .font(.system(size: 14))
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 18)
                        .fill(Color.gray.opacity(0.2))
                )
            }
            
            Spacer(minLength: 60)
        }
        .padding(.horizontal, 4)
        .onAppear {
            thinkingWord = thinkingWords.randomElement() ?? "Thinking"
            
            Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { timer in
                dotCount = (dotCount + 1) % 4
            }
        }
    }
}

#Preview {
    ThinkingBubbleView()
        .padding()
}