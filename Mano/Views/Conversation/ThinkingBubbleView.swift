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
        "Thinking", "Pondering", "Contemplating", "Considering", "Reflecting",
        "Reasoning", "Deliberating", "Mulling", "Musing", "Brooding",
        "Ruminating", "Meditating", "Concentrating", "Focusing", "Analysing",
        "Examining", "Studying", "Investigating", "Exploring", "Evaluating",
        "Assessing", "Judging", "Weighing", "Scrutinising", "Appraising",
        "Reviewing", "Remembering", "Recalling", "Reminiscing", "Recollecting",
        "Memorising", "Puzzling", "Brainstorming", "Strategising", "Planning",
        "Calculating", "Computing", "Figuring", "Solving", "Imagining",
        "Envisioning", "Conceiving", "Dreaming", "Fantasising", "Visualising",
        "Learning", "Comprehending", "Grasping", "Absorbing", "Processing",
        "Digesting", "Deciding", "Choosing", "Selecting", "Determining",
        "Resolving", "Philosophising", "Theorising", "Hypothesising", "Speculating",
        "Supposing", "Assuming", "Presuming", "Surmising", "Inferring",
        "Deducing", "Combobulating", "Cogitating", "Percolating", "Marinating",
        "Stewing", "Brewing", "Simmering", "Churning", "Ticking over",
        "Whirring", "Scheming", "Plotting", "Cooking up", "Hatching",
        "Sussing out", "Clocking", "Twigging", "Cottoning on", "Tumbling to",
        "Clicking", "Connecting", "Brain-storming", "Mind-melding", "Thought-spinning",
        "Idea-brewing", "Concept-cooking", "Notion-nurturing", "Brain-percolating", "Grey-matter-grinding",
        "Synapse-firing", "Neuron-networking", "Thinkifying", "Ponderfying", "Cogitativating",
        "Contemplifying", "Brain-noodling", "Mind-wrestling", "Thought-wrangling", "Idea-juggling",
        "Concept-massaging", "Brain-gymnastics-ing", "Wool-gathering", "Day-dreaming", "Star-gazing",
        "Cloud-watching", "Navel-gazing", "Chin-stroking", "Head-scratching", "Brow-furrowing",
        "Hmm-ing", "Umm-ing", "Ahh-ing", "Lightbulb-ing", "Eureka-ing",
        "Aha-ing", "Buffering", "Loading", "Number-crunching", "Data-mining",
        "Algorithm-ing", "Slow-cooking", "Braising", "Fermenting", "Distilling",
        "Smarticulating", "Intelligencing", "Wisdomising", "Brillianting", "Genius-ing",
        "Einstein-ing", "Sherlock-ing"
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