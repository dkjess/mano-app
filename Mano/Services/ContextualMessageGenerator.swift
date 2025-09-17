//
//  ContextualMessageGenerator.swift
//  Mano
//
//  Created by Claude on 03/09/2025.
//

import Foundation
import SwiftUI

class ContextualMessageGenerator {
    
    private var usedMessages: Set<String> = []
    private let maxHistorySize = 20
    
    /// Generate a contextual loading message based on detected intent
    func generateContextualMessage(for intent: MessageIntent, message: String) -> String {
        let templates = getTemplates(for: intent)
        let contextualizedTemplates = contextualizeTemplates(templates, with: message)
        
        // Select a message that hasn't been used recently
        let availableMessages = contextualizedTemplates.filter { !usedMessages.contains($0) }
        let selectedMessage = availableMessages.randomElement() ?? contextualizedTemplates.randomElement() ?? "Thinking through this carefully..."
        
        // Track usage to avoid repetition
        trackMessageUsage(selectedMessage)
        
        return selectedMessage
    }
    
    /// Generate fallback message for basic devices
    func generateFallbackMessage(for intent: MessageIntent) -> String {
        let fallbackTemplates = getFallbackTemplates(for: intent)
        let selectedMessage = fallbackTemplates.randomElement() ?? "Processing your question..."
        
        trackMessageUsage(selectedMessage)
        return selectedMessage
    }
    
    // MARK: - Template Selection
    
    private func getTemplates(for intent: MessageIntent) -> [String] {
        switch intent {
        case .performanceManagement:
            return [
                "Analyzing performance dynamics...",
                "Considering improvement strategies...",
                "Processing performance insights...",
                "Evaluating development approaches...",
                "Thinking through feedback techniques...",
                "Reviewing performance frameworks..."
            ]
            
        case .teamStructure:
            return [
                "Analyzing organizational approaches...",
                "Considering team architecture options...",
                "Processing structural dynamics...",
                "Evaluating reporting relationships...",
                "Thinking through team optimization...",
                "Reviewing organizational patterns..."
            ]
            
        case .conflictResolution:
            return [
                "Processing interpersonal dynamics...",
                "Analyzing conflict resolution strategies...",
                "Considering mediation approaches...",
                "Evaluating communication techniques...",
                "Thinking through resolution pathways...",
                "Processing relationship dynamics..."
            ]
            
        case .goalSetting:
            return [
                "Analyzing objective frameworks...",
                "Processing goal alignment strategies...",
                "Considering success metrics...",
                "Evaluating achievement pathways...",
                "Thinking through target setting...",
                "Reviewing planning approaches..."
            ]
            
        case .communication:
            return [
                "Processing communication strategies...",
                "Analyzing messaging approaches...",
                "Considering engagement techniques...",
                "Evaluating meeting dynamics...",
                "Thinking through presentation formats...",
                "Processing collaboration methods..."
            ]
            
        case .leadershipDevelopment:
            return [
                "Analyzing leadership approaches...",
                "Processing development strategies...",
                "Considering growth pathways...",
                "Evaluating mentorship techniques...",
                "Thinking through skill building...",
                "Reviewing leadership frameworks..."
            ]
            
        case .hiring:
            return [
                "Processing recruitment strategies...",
                "Analyzing candidate evaluation methods...",
                "Considering interview approaches...",
                "Evaluating selection criteria...",
                "Thinking through hiring processes...",
                "Processing team fit assessments..."
            ]
            
        case .workloadManagement:
            return [
                "Analyzing capacity considerations...",
                "Processing workload distribution...",
                "Considering resource allocation...",
                "Evaluating efficiency approaches...",
                "Thinking through prioritization...",
                "Processing time management strategies..."
            ]
            
        case .general:
            return [
                "Processing your management question...",
                "Analyzing leadership considerations...",
                "Thinking through your situation...",
                "Considering multiple approaches...",
                "Evaluating best practices...",
                "Processing strategic options..."
            ]
        }
    }
    
    private func getFallbackTemplates(for intent: MessageIntent) -> [String] {
        switch intent {
        case .performanceManagement:
            return [
                "Thinking about performance strategies...",
                "Considering development approaches...",
                "Processing improvement ideas..."
            ]
            
        case .teamStructure:
            return [
                "Analyzing team organization...",
                "Considering structural options...",
                "Processing organizational ideas..."
            ]
            
        case .conflictResolution:
            return [
                "Thinking through conflict approaches...",
                "Processing resolution strategies...",
                "Considering mediation options..."
            ]
            
        case .goalSetting:
            return [
                "Analyzing objective approaches...",
                "Processing goal strategies...",
                "Thinking through planning methods..."
            ]
            
        case .communication:
            return [
                "Considering communication approaches...",
                "Processing messaging strategies...",
                "Thinking through engagement methods..."
            ]
            
        case .leadershipDevelopment:
            return [
                "Thinking about leadership growth...",
                "Processing development strategies...",
                "Considering mentorship approaches..."
            ]
            
        case .hiring:
            return [
                "Processing recruitment considerations...",
                "Thinking through hiring approaches...",
                "Analyzing candidate strategies..."
            ]
            
        case .workloadManagement:
            return [
                "Considering workload approaches...",
                "Processing capacity strategies...",
                "Thinking through resource allocation..."
            ]
            
        case .general:
            return [
                "Processing your question...",
                "Considering the best approach...",
                "Thinking this through carefully...",
                "Analyzing your situation...",
                "Processing multiple perspectives...",
                "Evaluating different options..."
            ]
        }
    }
    
    // MARK: - Message Contextualization
    
    private func contextualizeTemplates(_ templates: [String], with message: String) -> [String] {
        // Extract key entities from the message to make templates more specific
        let entities = extractKeyEntities(from: message)
        
        return templates.map { template in
            var contextualized = template
            
            // Add specificity based on detected entities
            if entities.containsTeamReference {
                contextualized = contextualized.replacingOccurrences(of: "approaches", with: "team approaches")
            }
            
            if entities.containsIndividualReference {
                contextualized = contextualized.replacingOccurrences(of: "strategies", with: "individual strategies")
            }
            
            if entities.containsUrgencyIndicators {
                contextualized = contextualized.replacingOccurrences(of: "Thinking", with: "Quickly analyzing")
                contextualized = contextualized.replacingOccurrences(of: "Processing", with: "Rapidly processing")
            }
            
            if entities.containsTimeConstraints {
                contextualized = contextualized.replacingOccurrences(of: "approaches", with: "time-sensitive approaches")
            }
            
            return contextualized
        }
    }
    
    private func extractKeyEntities(from message: String) -> MessageEntities {
        let lowercased = message.lowercased()
        
        return MessageEntities(
            containsTeamReference: lowercased.contains("team") || lowercased.contains("group") || lowercased.contains("everyone"),
            containsIndividualReference: lowercased.contains("person") || lowercased.contains("individual") || lowercased.contains("employee") || lowercased.contains("member"),
            containsUrgencyIndicators: lowercased.contains("urgent") || lowercased.contains("asap") || lowercased.contains("immediately") || lowercased.contains("crisis"),
            containsTimeConstraints: lowercased.contains("deadline") || lowercased.contains("tomorrow") || lowercased.contains("this week") || lowercased.contains("soon")
        )
    }
    
    // MARK: - Usage Tracking
    
    private func trackMessageUsage(_ message: String) {
        usedMessages.insert(message)
        
        // Keep only recent messages to avoid infinite growth
        if usedMessages.count > maxHistorySize {
            // Remove oldest entries (this is simplified - in practice you'd want FIFO)
            let excess = usedMessages.count - maxHistorySize
            let toRemove = Array(usedMessages.prefix(excess))
            usedMessages.subtract(toRemove)
        }
    }
    
    /// Reset message history (useful for testing or session boundaries)
    func resetMessageHistory() {
        usedMessages.removeAll()
    }
}

// MARK: - Supporting Types

struct MessageEntities {
    let containsTeamReference: Bool
    let containsIndividualReference: Bool
    let containsUrgencyIndicators: Bool
    let containsTimeConstraints: Bool
}

// MARK: - Preview and Testing

#Preview {
    ContextualMessageTestView()
}

struct ContextualMessageTestView: View {
    @State private var generator = ContextualMessageGenerator()
    @State private var selectedIntent: MessageIntent = .performanceManagement
    @State private var testMessage = "How should I handle my underperforming team member?"
    @State private var generatedMessages: [String] = []
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Contextual Message Generator")
                .font(.title2)
                .bold()
            
            Picker("Intent", selection: $selectedIntent) {
                ForEach(MessageIntent.allCases, id: \.self) { intent in
                    HStack {
                        Text(intent.emoji)
                        Text(intent.rawValue)
                    }
                    .tag(intent)
                }
            }
            .pickerStyle(.menu)
            
            TextField("Test message", text: $testMessage, axis: .vertical)
                .textFieldStyle(.roundedBorder)
                .lineLimit(2...4)
            
            HStack {
                Button("Generate Contextual") {
                    let message = generator.generateContextualMessage(for: selectedIntent, message: testMessage)
                    generatedMessages.append("📱 \(message)")
                }
                .buttonStyle(.borderedProminent)
                
                Button("Generate Fallback") {
                    let message = generator.generateFallbackMessage(for: selectedIntent)
                    generatedMessages.append("💭 \(message)")
                }
                .buttonStyle(.bordered)
                
                Button("Clear") {
                    generatedMessages.removeAll()
                    generator.resetMessageHistory()
                }
                .buttonStyle(.bordered)
            }
            
            if !generatedMessages.isEmpty {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 8) {
                        ForEach(Array(generatedMessages.enumerated()), id: \.offset) { index, message in
                            Text(message)
                                .padding(8)
                                .background(Color.gray.opacity(0.2))
                                .cornerRadius(8)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                    .padding(.horizontal)
                }
                .frame(maxHeight: 200)
            }
        }
        .padding()
    }
}