//
//  ContextualThinkingBubbleView.swift
//  Mano
//
//  Created by Claude on 06/09/2025.
//

import SwiftUI

struct ContextualThinkingBubbleView: View {
    let message: String
    let analysisResult: AnalysisResult?
    
    @State private var animationPhase = 0
    @State private var glowIntensity: Double = 0.3
    @State private var showingDetails = false
    
    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            HStack(spacing: 8) {
                Text(message)
                    .font(.system(size: 15))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.leading)
                
                HStack(spacing: 4) {
                    ForEach(0..<3) { index in
                        Circle()
                            .fill(Color.blue)
                            .frame(width: 8, height: 8)
                            .scaleEffect(animationPhase == index ? 1.3 : 1.0)
                            .opacity(animationPhase == index ? 1.0 : 0.6)
                            .animation(
                                .easeInOut(duration: 0.8)
                                .repeatForever()
                                .delay(Double(index) * 0.3),
                                value: animationPhase
                            )
                    }
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 18)
                    .fill(Color.gray.opacity(0.2))
            )
            
            Spacer(minLength: 60)
        }
        .padding(.horizontal, 4)
        .onAppear {
            animationPhase = 1
            withAnimation(.easeInOut(duration: 2).repeatForever(autoreverses: true)) {
                glowIntensity = 0.8
            }
        }
        .onTapGesture {
            showingDetails.toggle()
        }
        .popover(isPresented: $showingDetails) {
            if let result = analysisResult {
                AnalysisDetailsView(result: result)
                    .presentationCompactAdaptation(.popover)
            }
        }
    }
    
    private func confidenceColor(_ confidence: Double) -> Color {
        if confidence > 0.8 { return .green }
        if confidence > 0.6 { return .orange }
        return .red
    }
}

struct AnalysisDetailsView: View {
    let result: AnalysisResult
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(result.intent.emoji)
                Text(result.intent.rawValue)
                    .font(.headline)
            }
            
            Text("Analysis Method: \(result.method.rawValue)")
                .font(.caption)
                .foregroundColor(.secondary)
            
            HStack {
                Text("Confidence: \(String(format: "%.0f", result.confidence * 100))%")
                Spacer()
                Text("Time: \(String(format: "%.0f", result.processingTime * 1000))ms")
            }
            .font(.caption2)
            .foregroundColor(.secondary)
        }
        .padding()
        .frame(width: 200)
    }
}

#Preview {
    ContextualThinkingBubbleView(
        message: "Analyzing your request...",
        analysisResult: AnalysisResult(
            intent: .general,
            contextualMessage: "Processing your question",
            confidence: 0.85,
            processingTime: 0.15,
            method: .naturalLanguage
        )
    )
    .padding()
}