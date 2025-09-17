//
//  ConversationView.swift
//  Mano
//
//  Created by Jess Wambui Olsen on 31/08/2025.
//

import SwiftUI
import NaturalLanguage
import Auth

struct ConversationView: View {
    let person: Person
    @State private var messages: [Message] = []
    @State private var isLoading = true
    @State private var messageText = ""
    @State private var isSending = false
    @State private var streamingMessage: Message? = nil
    @State private var streamingText = ""
    @State private var contextualThinkingMessage: String? = nil
    @State private var analysisResult: AnalysisResult? = nil
    @State private var lastScrollTime = Date()
    @State private var isUserScrolling = false
    @State private var userScrollTimer: Timer?
    @StateObject private var contextAnalyzer = MessageContextAnalyzer()
    @Environment(\.dismiss) private var dismiss
    @FocusState private var isInputFocused: Bool
    
    var canSend: Bool {
        !messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isSending
    }
    
    var body: some View {
        VStack(spacing: 0) {
            if isLoading {
                loadingView
            } else if messages.isEmpty {
                emptyStateView
            } else {
                conversationContent
            }
        }
        .navigationTitle(person.name)
        .navigationBarTitleDisplayMode(.large)
        .task {
            await loadMessages()
        }
        .onDisappear {
            userScrollTimer?.invalidate()
        }
    }
    
    private var loadingView: some View {
        ProgressView("Loading conversation...")
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var emptyStateView: some View {
        ZStack {
            // Empty state content
            VStack {
                Spacer()
                ContentUnavailableView(
                    "No messages yet",
                    systemImage: "message",
                    description: Text("Start a conversation about \(person.name)")
                )
                Spacer()
            }
            
            // Floating input at bottom (same as conversationContent)
            VStack {
                Spacer()
                InputComposer(
                    person: person,
                    messageText: $messageText,
                    isSending: $isSending,
                    isInputFocused: _isInputFocused,
                    onSendMessage: sendMessage
                )
            }
        }
    }
    
    private var conversationContent: some View {
        ZStack {
            // Main conversation area
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(spacing: 12) {
                        ForEach(messages) { message in
                            MessageBubbleView(message: message)
                                .id(message.id)
                        }
                        
                        // Show only ONE thinking/loading state at a time
                        if let streamingMsg = streamingMessage {
                            if !streamingText.isEmpty {
                                // Streaming content - show the actual message with typing cursor
                                MessageBubbleView(
                                    message: Message(
                                        id: streamingMsg.id,
                                        userId: streamingMsg.userId,
                                        content: streamingText + "|", // Add slim typing cursor
                                        isUser: false,
                                        personId: streamingMsg.personId,
                                        topicId: streamingMsg.topicId,
                                        createdAt: streamingMsg.createdAt
                                    )
                                )
                                .id("streaming")
                            } else if let contextualMessage = contextualThinkingMessage,
                                      let analysis = analysisResult {
                                // Show contextual analysis while waiting
                                ContextualThinkingBubbleView(
                                    message: contextualMessage,
                                    analysisResult: analysis
                                )
                                .id("contextual-thinking")
                            } else {
                                // Simple thinking bubble as fallback
                                ThinkingBubbleView()
                                    .id("thinking")
                            }
                        }
                        
                        // Spacer for floating input - ensure messages are visible above input
                        Spacer()
                            .frame(height: 160)
                    }
                    .padding()
                    .padding(.bottom, 20)
                }
                .onAppear {
                    if let lastMessage = messages.last {
                        proxy.scrollTo(lastMessage.id, anchor: .top)
                    }
                }
                .onChange(of: messages.count) { _, _ in
                    if let lastMessage = messages.last {
                        withAnimation {
                            proxy.scrollTo(lastMessage.id, anchor: .top)
                        }
                    }
                }
                .onChange(of: streamingMessage) { _, newValue in
                    if newValue != nil {
                        // Always scroll to show the loader immediately
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                if !streamingText.isEmpty {
                                    proxy.scrollTo("streaming", anchor: .top)
                                } else if contextualThinkingMessage != nil {
                                    proxy.scrollTo("contextual-thinking", anchor: .top)
                                } else {
                                    proxy.scrollTo("thinking", anchor: .top)
                                }
                            }
                        }
                    }
                }
                .onChange(of: streamingText) { _, newValue in
                    if !newValue.isEmpty && !isUserScrolling {
                        let now = Date()
                        // Throttle scroll updates to prevent excessive animations (max 60fps)
                        if now.timeIntervalSince(lastScrollTime) > 0.016 {
                            lastScrollTime = now
                            withAnimation(.easeOut(duration: 0.1)) {
                                proxy.scrollTo("streaming", anchor: .top)
                            }
                        }
                    }
                }
                .onChange(of: contextualThinkingMessage) { _, newValue in
                    if newValue != nil && streamingMessage != nil {
                        // Scroll to contextual thinking immediately when it appears
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                proxy.scrollTo("contextual-thinking", anchor: .top)
                            }
                        }
                    }
                }
                .onChange(of: isInputFocused) { _, focused in
                    if focused {
                        // When keyboard appears, scroll to keep last message visible
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                if let streamingMsg = streamingMessage {
                                    if !streamingText.isEmpty {
                                        proxy.scrollTo("streaming", anchor: .top)
                                    } else if contextualThinkingMessage != nil {
                                        proxy.scrollTo("contextual-thinking", anchor: .top)
                                    } else {
                                        proxy.scrollTo("thinking", anchor: .top)
                                    }
                                } else if let lastMessage = messages.last {
                                    proxy.scrollTo(lastMessage.id, anchor: .top)
                                }
                            }
                        }
                    }
                }
                .contentShape(Rectangle())
                .onTapGesture {
                    // Dismiss keyboard and collapse input when tapping conversation
                    isInputFocused = false
                }
                .simultaneousGesture(
                    DragGesture()
                        .onChanged { _ in
                            // User is manually scrolling
                            isUserScrolling = true
                            userScrollTimer?.invalidate()
                            userScrollTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: false) { _ in
                                // Resume auto-scroll after 2 seconds of no manual scrolling
                                isUserScrolling = false
                            }
                        }
                )
            }
            
            // Floating input at bottom
            VStack {
                Spacer()
                InputComposer(
                    person: person,
                    messageText: $messageText,
                    isSending: $isSending,
                    isInputFocused: _isInputFocused,
                    onSendMessage: sendMessage
                )
            }
        }
    }
    
    // MARK: - Helper Methods
    
    private func loadMessages() async {
        print("📬 Loading messages for \(person.name)")
        isLoading = true
        
        do {
            messages = try await SupabaseManager.shared.fetchMessages(for: person.id)
        } catch {
            print("❌ Failed to load messages: \(error)")
        }
        
        isLoading = false
    }
    
    private func sendMessage() {
        let text = messageText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        
        messageText = ""
        isSending = true
        
        let userMessage = Message(
            id: UUID(),
            userId: SupabaseManager.shared.user?.id ?? UUID(),
            content: text,
            isUser: true,
            personId: person.id,
            topicId: nil,
            createdAt: Date()
        )
        
        messages.append(userMessage)
        
        let aiMessageId = UUID()
        streamingMessage = Message(
            id: aiMessageId,
            userId: SupabaseManager.shared.user?.id ?? UUID(),
            content: "",
            isUser: false,
            personId: person.id,
            topicId: nil,
            createdAt: Date()
        )
        streamingText = ""
        
        Task {
            do {
                print("🤖 Starting message analysis for: \(text)")
                let analysis = await contextAnalyzer.analyzeMessage(text)
                print("📊 Analysis result - Intent: \(analysis.intent.rawValue), Message: \(analysis.contextualMessage)")
                
                await MainActor.run {
                    contextualThinkingMessage = analysis.contextualMessage
                    analysisResult = analysis
                    print("💭 Contextual message set: \(contextualThinkingMessage ?? "nil")")
                }
                
                try await SupabaseManager.shared.sendMessageWithStream(
                    text,
                    to: person.id
                ) { chunk in
                    await MainActor.run {
                        streamingText += chunk
                    }
                }
                
                await MainActor.run {
                    if !streamingText.isEmpty {
                        // Remove the typing cursor from the final message
                        let cleanContent = streamingText.replacingOccurrences(of: "|", with: "")
                        let finalMessage = Message(
                            id: aiMessageId,
                            userId: SupabaseManager.shared.user?.id ?? UUID(),
                            content: cleanContent,
                            isUser: false,
                            personId: person.id,
                            topicId: nil,
                            createdAt: Date()
                        )
                        messages.append(finalMessage)
                    }
                    streamingMessage = nil
                    streamingText = ""
                    contextualThinkingMessage = nil
                    analysisResult = nil
                }
                
                await loadMessages()
            } catch {
                print("❌ Failed to send message: \(error)")
                await MainActor.run {
                    messages.removeAll { $0.id == userMessage.id }
                    messageText = text
                    streamingMessage = nil
                    streamingText = ""
                    contextualThinkingMessage = nil
                    analysisResult = nil
                }
            }
            
            await MainActor.run {
                isSending = false
            }
        }
    }
}

#Preview {
    NavigationStack {
        ConversationView(
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
            )
        )
    }
}