//
//  ConversationView.swift
//  Mano
//
//  Created by Jess Wambui Olsen on 31/08/2025.
//

import SwiftUI
import NaturalLanguage
import Auth
#if canImport(AppKit)
import AppKit
#endif

@available(iOS 26.0, *)
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
    @State private var newMessageIds: Set<UUID> = []
    @State private var showingConversationHistory = false
    @State private var showingClearConfirmation = false
    @State private var errorMessage: String? = nil
    @State private var showingErrorAlert = false
    @State private var hapticGenerator = UIImpactFeedbackGenerator(style: .light)
    @State private var lastHapticLength = 0

    var canSend: Bool {
        !messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isSending
    }

    var inputAreaHeight: CGFloat {
        // Approximate height for input area to add padding to messages
        return 100
    }

    func handleTapOutside() {
        // Dismiss keyboard when tapping outside
        isInputFocused = false

        // Additional logic for returning to idle state would be handled by the input component
        // since it manages its own state
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
        .background(ManoColors.almostWhite)
        .navigationTitle(person.name)
        #if os(iOS)
        .navigationBarTitleDisplayMode(.large)
        #endif
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    Button(action: {
                        showingConversationHistory = true
                    }) {
                        Label("Conversation History", systemImage: "clock.arrow.circlepath")
                    }

                    Button(action: {
                        Task {
                            await startNewConversation()
                        }
                    }) {
                        Label("Start New Conversation", systemImage: "plus.message")
                    }

                    Divider()

                    Button(action: {
                        exportConversation()
                    }) {
                        Label("Export Conversation", systemImage: "square.and.arrow.up")
                    }

                    Button(action: {
                        showingClearConfirmation = true
                    }) {
                        Label("Clear Messages", systemImage: "trash")
                    }
                    .foregroundColor(.red)
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .task {
            await loadMessages()
        }
        .onDisappear {
            userScrollTimer?.invalidate()
        }
        .sheet(isPresented: $showingConversationHistory) {
            ConversationHistoryView(person: person)
        }
        .alert("Clear Conversation", isPresented: $showingClearConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Clear", role: .destructive) {
                Task {
                    await clearMessages()
                }
            }
        } message: {
            Text("This will permanently delete all messages in this conversation. This action cannot be undone.")
        }
        .alert("Message Failed", isPresented: $showingErrorAlert) {
            Button("OK", role: .cancel) {
                errorMessage = nil
            }
        } message: {
            if let errorMessage = errorMessage {
                Text(errorMessage)
            }
        }
    }
    
    private var loadingView: some View {
        ProgressView("Loading conversation...")
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var emptyStateView: some View {
        ZStack(alignment: .bottom) {
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
            .padding(.bottom, inputAreaHeight)
            .contentShape(Rectangle())
            .onTapGesture {
                handleTapOutside()
            }

            // Voice-first message input component (fixed at bottom)
            MessageInputComponent(
                person: person,
                onSendMessage: { text in
                    messageText = text
                    sendMessage()
                }
            )
        }
        .ignoresSafeArea(.keyboard)
    }
    
    private var conversationContent: some View {
        ZStack(alignment: .bottom) {
            // Main conversation area
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(spacing: 12) {
                        ForEach(messages) { message in
                            Group {
                                if message.isUser {
                                    UserMessageView(message: message)
                                } else {
                                    AssistantMessageView(message: message)
                                }
                            }
                            .id(message.id)
                            .scaleEffect(newMessageIds.contains(message.id) ? 0.8 : 1.0)
                            .opacity(newMessageIds.contains(message.id) ? 0 : 1)
                            .animation(.spring(response: 0.4, dampingFraction: 0.7), value: newMessageIds.contains(message.id))
                            .onAppear {
                                if newMessageIds.contains(message.id) {
                                    _ = withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                                        newMessageIds.remove(message.id)
                                    }
                                }
                            }
                        }
                        
                        // Show only ONE thinking/loading state at a time
                        if let streamingMsg = streamingMessage {
                            if !streamingText.isEmpty {
                                // Streaming content - show the actual message with progressive reveal
                                AssistantMessageView(
                                    message: Message(
                                        id: streamingMsg.id,
                                        userId: streamingMsg.userId,
                                        content: streamingText,
                                        isUser: false,
                                        personId: streamingMsg.personId,
                                        topicId: streamingMsg.topicId,
                                        conversationId: streamingMsg.conversationId,
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
                    }
                    .padding()
                    .padding(.bottom, inputAreaHeight)  // Space for input component
                }
                .contentShape(Rectangle())  // Make entire area tappable
                .onTapGesture {
                    handleTapOutside()
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
                .onChange(of: streamingText) { oldValue, newValue in
                    // Haptic feedback on new content (every 10-15 characters)
                    if newValue.count > lastHapticLength && newValue.count - lastHapticLength >= 10 {
                        hapticGenerator.impactOccurred(intensity: 0.4)
                        lastHapticLength = newValue.count
                    }

                    // Only auto-scroll if user is not manually scrolling
                    if !newValue.isEmpty && !isUserScrolling {
                        let now = Date()
                        // Throttle scroll updates to prevent excessive animations
                        if now.timeIntervalSince(lastScrollTime) > Timeouts.scrollThrottle {
                            lastScrollTime = now
                            withAnimation(.easeOut(duration: AnimationDuration.quick)) {
                                proxy.scrollTo("streaming", anchor: .top)
                            }
                        }
                    }
                }
                .onChange(of: contextualThinkingMessage) { _, newValue in
                    if newValue != nil && streamingMessage != nil {
                        // Scroll to contextual thinking immediately when it appears
                        DispatchQueue.main.asyncAfter(deadline: .now() + Timeouts.contextualThinking) {
                            withAnimation(.easeInOut(duration: AnimationDuration.scroll)) {
                                proxy.scrollTo("contextual-thinking", anchor: .top)
                            }
                        }
                    }
                }
                .onChange(of: isInputFocused) { _, focused in
                    if focused {
                        // When keyboard appears, scroll to keep last message visible
                        DispatchQueue.main.asyncAfter(deadline: .now() + AnimationDuration.scroll) {
                            withAnimation(.easeInOut(duration: AnimationDuration.scroll)) {
                                if streamingMessage != nil {
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
                .simultaneousGesture(
                    DragGesture()
                        .onChanged { _ in
                            // User is manually scrolling
                            isUserScrolling = true
                            userScrollTimer?.invalidate()
                            userScrollTimer = Timer.scheduledTimer(withTimeInterval: Timeouts.userScrollDetection, repeats: false) { _ in
                                // Resume auto-scroll after user stops scrolling
                                isUserScrolling = false
                            }
                        }
                )
            }

            // Voice-first message input component (fixed at bottom)
            MessageInputComponent(
                person: person,
                onSendMessage: { text in
                    messageText = text
                    sendMessage()
                }
            )
        }
        .ignoresSafeArea(.keyboard)  // Let keyboard push content
    }

    // MARK: - Helper Methods
    
    private func loadMessages() async {
        print("📬 Loading messages for \(person.name)")
        isLoading = true

        // Retry logic for network timeouts
        for attempt in 1...2 {
            do {
                print("🔄 [LOAD] Attempt \(attempt)/2")
                messages = try await SupabaseManager.shared.fetchMessages(for: person.id)
                print("✅ [LOAD] Messages loaded successfully")
                break // Success, exit retry loop
            } catch let error as NSError where error.code == -1005 && attempt < 2 {
                // Network connection lost - retry once
                print("⚠️ [LOAD] Attempt \(attempt) failed with network timeout, retrying...")
                try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 second delay
                continue
            } catch {
                print("❌ Failed to load messages: \(error)")
                break // Other error - don't retry
            }
        }

        isLoading = false
    }
    
    private func sendMessage() {
        let text = messageText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        
        messageText = ""
        isSending = true

        // Unfocus input after sending message
        isInputFocused = false
        
        let userMessage = Message(
            id: UUID(),
            userId: SupabaseManager.shared.user?.id ?? UUID(),
            content: text,
            isUser: true,
            personId: person.id,
            topicId: nil,
            conversationId: nil,
            createdAt: Date()
        )

        // Add animation for new user message
        newMessageIds.insert(userMessage.id)
        messages.append(userMessage)
        
        let aiMessageId = UUID()
        streamingMessage = Message(
            id: aiMessageId,
            userId: SupabaseManager.shared.user?.id ?? UUID(),
            content: "",
            isUser: false,
            personId: person.id,
            topicId: nil,
            conversationId: nil,
            createdAt: Date()
        )
        streamingText = ""
        lastHapticLength = 0
        hapticGenerator.prepare()
        
        Task {
            do {
                print("🚀 [SEND] Starting message send for: '\(text)'")
                print("🚀 [SEND] isSending state: \(isSending)")
                print("🚀 [SEND] Person ID: \(person.id)")

                print("🤖 Starting message analysis for: \(text)")
                let analysis = await contextAnalyzer.analyzeMessage(text)
                print("📊 Analysis result - Intent: \(analysis.intent.rawValue), Message: \(analysis.contextualMessage)")

                await MainActor.run {
                    contextualThinkingMessage = analysis.contextualMessage
                    analysisResult = analysis
                    print("💭 Contextual message set: \(contextualThinkingMessage ?? "nil")")
                }

                print("📡 [SEND] About to call sendMessageWithStream...")

                // Retry logic for network timeouts (fixes "every other message fails" issue)
                var lastError: Error?
                for attempt in 1...2 {
                    do {
                        print("🔄 [SEND] Attempt \(attempt)/2")
                        try await SupabaseManager.shared.sendMessageWithStream(
                            text,
                            to: person.id
                        ) { chunk in
                            await MainActor.run {
                                streamingText += chunk
                            }
                        }
                        print("✅ [SEND] sendMessageWithStream completed successfully")
                        break // Success, exit retry loop
                    } catch let error as NSError where error.code == -1005 && attempt < 2 {
                        // Network connection lost - retry once
                        print("⚠️ [SEND] Attempt \(attempt) failed with network timeout, retrying...")
                        lastError = error
                        try await Task.sleep(nanoseconds: 500_000_000) // 0.5 second delay
                        continue
                    } catch {
                        // Other error or final attempt - throw it
                        throw error
                    }
                }

                if let error = lastError {
                    throw error
                }

                // Create the final AI message from the streamed content
                let finalAIMessage = Message(
                    id: aiMessageId,
                    userId: SupabaseManager.shared.user?.id ?? UUID(),
                    content: streamingText,
                    isUser: false,
                    personId: person.id,
                    topicId: nil,
                    conversationId: nil,
                    createdAt: Date()
                )

                await MainActor.run {
                    // Append the completed AI message to local array
                    messages.append(finalAIMessage)

                    // Clear streaming state
                    streamingMessage = nil
                    streamingText = ""
                    contextualThinkingMessage = nil
                    analysisResult = nil
                }

                // No need to reload from DB - we already have the content from streaming
                // The backend saved it asynchronously, but we don't need to wait or reload
                print("✅ [SEND] Message send flow completed successfully (no reload)")
            } catch {
                print("❌ [SEND] Failed to send message - ERROR TYPE: \(type(of: error))")
                print("❌ [SEND] Error description: \(error)")
                print("❌ [SEND] Localized description: \(error.localizedDescription)")
                if let nsError = error as NSError? {
                    print("❌ [SEND] NSError domain: \(nsError.domain)")
                    print("❌ [SEND] NSError code: \(nsError.code)")
                    print("❌ [SEND] NSError userInfo: \(nsError.userInfo)")
                }

                await MainActor.run {
                    messages.removeAll { $0.id == userMessage.id }
                    messageText = text
                    streamingMessage = nil
                    streamingText = ""
                    contextualThinkingMessage = nil
                    analysisResult = nil

                    // Show user-friendly error message
                    errorMessage = "Failed to send message. Please try again."
                    showingErrorAlert = true
                }
            }

            await MainActor.run {
                print("🏁 [SEND] Setting isSending to false")
                isSending = false
            }
        }
    }

    // MARK: - Conversation Menu Actions

    private func exportConversation() {
        let conversationText = messages
            .sorted { $0.createdAt < $1.createdAt }
            .map { message in
                let sender = message.isUser ? "You" : person.name
                let timestamp = DateFormatter.localizedString(
                    from: message.createdAt,
                    dateStyle: .short,
                    timeStyle: .short
                )
                return "\(sender) (\(timestamp)): \(message.content)"
            }
            .joined(separator: "\n\n")

        #if os(iOS)
        let activityVC = UIActivityViewController(
            activityItems: [conversationText],
            applicationActivities: nil
        )

        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first {
            window.rootViewController?.present(activityVC, animated: true)
        }
        #else
        // On macOS, copy to pasteboard
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(conversationText, forType: .string)
        #endif
    }

    private func startNewConversation() async {
        // Clear current messages and start fresh
        messages = []
        streamingMessage = nil
        streamingText = ""
        contextualThinkingMessage = nil
        analysisResult = nil

        // Get user's name for personalized greeting
        let userName: String
        do {
            if let userProfile = try await SupabaseManager.shared.profile.fetchUserProfile() {
                userName = userProfile.callName ?? userProfile.preferredName ?? "there"
            } else {
                userName = "there"
            }
        } catch {
            userName = "there"
        }

        // Create a friendly greeting from Mano
        let greetingMessage = Message(
            id: UUID(),
            userId: UUID(), // Will be filled by backend
            content: "What's on your mind, \(userName)?",
            isUser: false,
            personId: person.id,
            topicId: nil,
            conversationId: nil,
            createdAt: Date()
        )

        await MainActor.run {
            messages = [greetingMessage]
        }

        // Auto-focus input for new conversation
        DispatchQueue.main.asyncAfter(deadline: .now() + Timeouts.autoFocus) {
            isInputFocused = true
        }

        print("✅ Started new conversation with \(person.name) with friendly greeting")
    }

    private func clearMessages() async {
        // Clear messages from the current conversation
        // For now, we'll just clear the local state - in the future we might want to
        // delete from the database as well
        messages = []
        streamingMessage = nil
        streamingText = ""
        contextualThinkingMessage = nil
        analysisResult = nil

        // Auto-focus input after clearing messages
        DispatchQueue.main.asyncAfter(deadline: .now() + Timeouts.autoFocus) {
            isInputFocused = true
        }

        print("✅ Messages cleared for \(person.name)")
    }
}

// MARK: - Supporting Views
// Note: ConversationHistoryView, ConversationHistoryRow, ConversationDetailView,
// and NewConversationSheet have been extracted to separate files in Views/Conversation/

@available(iOS 26.0, *)
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
                isSelf: false,
                startedWorkingTogether: nil
            )
        )
    }
}