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
    @State private var newMessageIds: Set<UUID> = []
    @State private var showingConversationHistory = false
    @State private var showingClearConfirmation = false
    @State private var showingNewConversationSheet = false

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
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    Button(action: {
                        showingConversationHistory = true
                    }) {
                        Label("Conversation History", systemImage: "clock.arrow.circlepath")
                    }

                    Button(action: {
                        showingNewConversationSheet = true
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
        .sheet(isPresented: $showingNewConversationSheet) {
            NewConversationSheet(person: person, onNewConversation: {
                Task {
                    await startNewConversation()
                }
            })
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
    }
    
    private var loadingView: some View {
        ProgressView("Loading conversation...")
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 0) {
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

            // Input at bottom (no longer floating)
            InputComposer(
                person: person,
                messageText: $messageText,
                isSending: $isSending,
                isInputFocused: _isInputFocused,
                onSendMessage: sendMessage
            )
        }
        .onAppear {
            // Auto-focus input when entering empty conversation
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                isInputFocused = true
            }
        }
    }
    
    private var conversationContent: some View {
        VStack(spacing: 0) {
            // Main conversation area
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(spacing: 12) {
                        ForEach(messages) { message in
                            MessageBubbleView(message: message, isStreaming: false)
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
                                MessageBubbleView(
                                    message: Message(
                                        id: streamingMsg.id,
                                        userId: streamingMsg.userId,
                                        content: streamingText,
                                        isUser: false,
                                        personId: streamingMsg.personId,
                                        topicId: streamingMsg.topicId,
                                        conversationId: streamingMsg.conversationId,
                                        createdAt: streamingMsg.createdAt
                                    ),
                                    isStreaming: true
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
                    .padding(.bottom, 0)
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
                    // Only auto-scroll if user is not manually scrolling
                    if !newValue.isEmpty && !isUserScrolling {
                        let now = Date()
                        // Throttle scroll updates to prevent excessive animations
                        if now.timeIntervalSince(lastScrollTime) > 0.3 {
                            lastScrollTime = now
                            withAnimation(.easeOut(duration: 0.2)) {
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
                            userScrollTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: false) { _ in
                                // Resume auto-scroll after 3 seconds of no manual scrolling
                                isUserScrolling = false
                            }
                        }
                )
            }

            // Input composer at bottom (no longer floating/overlapping)
            InputComposer(
                person: person,
                messageText: $messageText,
                isSending: $isSending,
                isInputFocused: _isInputFocused,
                onSendMessage: sendMessage
            )
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

                // Simplified streaming - just add text directly, less jerky
                try await SupabaseManager.shared.sendMessageWithStream(
                    text,
                    to: person.id
                ) { chunk in
                    await MainActor.run {
                        streamingText += chunk
                    }
                }
                
                await MainActor.run {
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

        let activityVC = UIActivityViewController(
            activityItems: [conversationText],
            applicationActivities: nil
        )

        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first {
            window.rootViewController?.present(activityVC, animated: true)
        }
    }

    private func startNewConversation() async {
        // Clear current messages and start fresh
        messages = []
        streamingMessage = nil
        streamingText = ""
        contextualThinkingMessage = nil
        analysisResult = nil

        // Auto-focus input for new conversation
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            isInputFocused = true
        }

        // Create a new active conversation for this person
        // This will be handled by the conversation manager when the next message is sent
        print("✅ Ready for new conversation with \(person.name)")
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
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            isInputFocused = true
        }

        print("✅ Messages cleared for \(person.name)")
    }
}

// MARK: - Supporting Views

struct ConversationHistoryView: View {
    let person: Person
    @State private var conversations: [Conversation] = []
    @State private var isLoading = true
    @State private var selectedConversation: Conversation? = nil
    @State private var conversationMessages: [UUID: [Message]] = [:]
    @ObservedObject private var supabase = SupabaseManager.shared
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            Group {
                if isLoading {
                    ProgressView("Loading conversation history...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if conversations.isEmpty {
                    ContentUnavailableView(
                        "No Conversation History",
                        systemImage: "clock.arrow.circlepath",
                        description: Text("You haven't had any previous conversations with \(person.name) yet.")
                    )
                } else {
                    conversationList
                }
            }
            .navigationTitle("History")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .task {
                await loadConversationHistory()
            }
            .sheet(item: $selectedConversation) { conversation in
                ConversationDetailView(
                    conversation: conversation,
                    person: person,
                    messages: conversationMessages[conversation.id] ?? []
                )
            }
        }
    }

    private var conversationList: some View {
        List {
            ForEach(conversations) { conversation in
                ConversationHistoryRow(
                    conversation: conversation,
                    person: person,
                    onTap: {
                        Task {
                            await loadMessages(for: conversation)
                            selectedConversation = conversation
                        }
                    }
                )
            }
        }
    }

    private func loadConversationHistory() async {
        isLoading = true
        do {
            conversations = try await supabase.conversations.fetchConversations(for: person.id)
            print("✅ Loaded \(conversations.count) conversations for \(person.name)")
        } catch {
            print("❌ Failed to load conversation history: \(error)")
        }
        isLoading = false
    }

    private func loadMessages(for conversation: Conversation) async {
        do {
            let messages = try await supabase.conversations.fetchMessagesForConversation(conversation.id)
            conversationMessages[conversation.id] = messages
            print("✅ Loaded \(messages.count) messages for conversation \(conversation.id)")
        } catch {
            print("❌ Failed to load messages for conversation: \(error)")
        }
    }
}

struct ConversationHistoryRow: View {
    let conversation: Conversation
    let person: Person
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(conversationTitle)
                        .font(.headline)
                        .foregroundColor(.primary)
                        .lineLimit(2)

                    Spacer()

                    if conversation.isActive {
                        Text("Active")
                            .font(.caption)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(Color.green.opacity(0.2))
                            .foregroundColor(.green)
                            .cornerRadius(4)
                    }
                }

                HStack {
                    Text("Started: \(DateFormatter.conversationDate.string(from: conversation.createdAt))")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Spacer()

                    Text("Updated: \(DateFormatter.conversationDate.string(from: conversation.updatedAt))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.vertical, 4)
        }
        .buttonStyle(PlainButtonStyle())
    }

    private var conversationTitle: String {
        conversation.title ?? "Conversation with \(person.name)"
    }
}

struct ConversationDetailView: View {
    let conversation: Conversation
    let person: Person
    let messages: [Message]
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 12) {
                    if messages.isEmpty {
                        ContentUnavailableView(
                            "No Messages",
                            systemImage: "message.slash",
                            description: Text("This conversation has no messages.")
                        )
                        .padding()
                    } else {
                        ForEach(messages.sorted { $0.createdAt < $1.createdAt }) { message in
                            MessageBubbleView(message: message, isStreaming: false)
                                .padding(.horizontal)
                        }
                    }
                }
                .padding(.top)
            }
            .navigationTitle(conversationTitle)
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .primaryAction) {
                    Button(action: exportConversation) {
                        Image(systemName: "square.and.arrow.up")
                    }
                }
            }
        }
    }

    private var conversationTitle: String {
        conversation.title ?? "Conversation with \(person.name)"
    }

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

        let activityVC = UIActivityViewController(
            activityItems: [conversationText],
            applicationActivities: nil
        )

        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first {
            window.rootViewController?.present(activityVC, animated: true)
        }
    }
}

extension DateFormatter {
    static let conversationDate: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()
}

struct NewConversationSheet: View {
    let person: Person
    let onNewConversation: () -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                VStack(spacing: 8) {
                    Image(systemName: "plus.message.fill")
                        .font(.system(size: 60))
                        .foregroundColor(.accentColor)

                    Text("Start New Conversation")
                        .font(.title2)
                        .fontWeight(.semibold)

                    Text("This will start a fresh conversation with \(person.name). Your current conversation will be saved in history.")
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }

                Spacer()

                VStack(spacing: 12) {
                    Button(action: {
                        onNewConversation()
                        dismiss()
                    }) {
                        Text("Start New Conversation")
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.accentColor)
                            .cornerRadius(12)
                    }

                    Button(action: {
                        dismiss()
                    }) {
                        Text("Cancel")
                            .font(.headline)
                            .foregroundColor(.accentColor)
                    }
                }
                .padding(.horizontal)
            }
            .padding()
            .navigationTitle("New Conversation")
            .navigationBarTitleDisplayMode(.large)
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