//
//  MessageInputOverlay.swift
//  Mano
//
//  Created by Claude on 24/10/2025.
//  iOS 26.0+ | Swift 6.2
//

import SwiftUI
import Speech

#if os(iOS)
import UIKit
#endif

/// Input state machine for message composition
enum InputState: Equatable {
    case initial           // Both buttons visible, no overlay
    case typing           // Overlay up, keyboard visible, T hidden
    case dictating        // Overlay up, button pulsing, T hidden
    case hasText          // Overlay up, text present, ready to send
}

@available(iOS 26.0, *)
struct MessageInputOverlay: View {
    let person: Person
    @Binding var messageText: String
    @Binding var isSending: Bool
    let onSendMessage: () -> Void

    // State management
    @State private var inputState: InputState = .initial
    @State private var showOverlay: Bool = false
    @State private var isDictating: Bool = false
    @State private var isPulsing: Bool = false
    @State private var dragOffset: CGFloat = 0

    // Speech recognition
    @StateObject private var speechRecognizer = SpeechRecognitionService()
    @State private var showPermissionAlert = false

    // Haptics
    #if os(iOS)
    @State private var feedbackGenerator = UIImpactFeedbackGenerator(style: .light)
    @State private var lastWordCount = 0
    #endif

    // Focus state
    @FocusState private var isTextFieldFocused: Bool

    var body: some View {
        ZStack(alignment: .bottom) {
            // Tap-to-dismiss background (only when overlay is showing)
            if showOverlay {
                Color.black.opacity(0.001)
                    .ignoresSafeArea()
                    .onTapGesture {
                        dismissOverlay()
                    }
            }

            // Initial state buttons (centered at bottom)
            if inputState == .initial {
                initialStateButtons
                    .transition(.opacity.combined(with: .scale))
            }

            // Input overlay (slides up from bottom, ignores keyboard)
            if showOverlay {
                inputOverlay
                    .transition(.move(edge: .bottom))
                    .ignoresSafeArea(.keyboard)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: showOverlay)
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: inputState)
        .onChange(of: speechRecognizer.transcribedText) { _, newText in
            if isDictating && !newText.isEmpty {
                messageText = newText

                // Haptic feedback on new words
                #if os(iOS)
                let wordCount = newText.split(separator: " ").count
                if wordCount > lastWordCount {
                    feedbackGenerator.impactOccurred()
                    lastWordCount = wordCount
                }
                #endif
            }
        }
        .alert("Microphone Access Required", isPresented: $showPermissionAlert) {
            #if os(iOS)
            Button("Settings") {
                if let settingsUrl = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(settingsUrl)
                }
            }
            #endif
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Please enable microphone access in Settings to use speech-to-text.")
        }
    }

    // MARK: - Initial State Buttons

    private var initialStateButtons: some View {
        HStack(spacing: 32) {
            // T button (keyboard)
            Button(action: startTyping) {
                Image(systemName: "keyboard")
                    .font(.system(size: 32, weight: .medium))
                    .foregroundStyle(.blue)
                    .frame(width: 72, height: 72)
                    .background(.ultraThinMaterial, in: Circle())
            }
            .disabled(isSending)

            // Dictation button
            Button(action: {}) {
                Image(systemName: "mic.circle.fill")
                    .font(.system(size: 36, weight: .medium))
                    .foregroundStyle(.blue)
                    .frame(width: 72, height: 72)
                    .background(.ultraThinMaterial, in: Circle())
            }
            .simultaneousGesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in
                        if inputState == .initial {
                            startDictating()
                        }
                    }
                    .onEnded { _ in
                        if isDictating {
                            stopDictating()
                        }
                    }
            )
            .disabled(isSending)
        }
        .padding(.bottom, 60)
    }

    // MARK: - Input Overlay

    private var inputOverlay: some View {
        GeometryReader { geometry in
            let overlayHeight = geometry.size.height * 0.45

            ZStack(alignment: .bottom) {
                // Gradient background (this IS the text input area)
                LinearGradient(
                    gradient: Gradient(stops: [
                        .init(color: .white.opacity(0.2), location: 0.0),
                        .init(color: .white, location: 0.3)
                    ]),
                    startPoint: .top,
                    endPoint: .bottom
                )
                .clipShape(UnevenRoundedRectangle(cornerRadii: .init(topLeading: 20, topTrailing: 20)))
                .shadow(color: .black.opacity(0.1), radius: 20, x: 0, y: -5)

                VStack(spacing: 0) {
                    // Text editor directly on gradient background
                    ZStack(alignment: .bottomTrailing) {
                        TextEditor(text: $messageText)
                            .textInputAutocapitalization(.sentences)
                            .autocorrectionDisabled(false)
                            .scrollContentBackground(.hidden)
                            .background(Color.clear)
                            .padding(.horizontal, 20)
                            .padding(.top, 20)
                            .padding(.bottom, 100)
                            .focused($isTextFieldFocused)
                            .disabled(isDictating)

                        // Send button (appears when text is present)
                        if hasContent {
                            Button(action: handleSend) {
                                Image(systemName: "arrow.up.circle.fill")
                                    .font(.system(size: 36))
                                    .foregroundStyle(canSend ? .blue : .gray)
                                    .scaleEffect(isSending ? 0.9 : 1.0)
                                    .animation(.spring(response: 0.2, dampingFraction: 0.7), value: isSending)
                            }
                            .disabled(!canSend)
                            .padding(.trailing, 24)
                            .padding(.bottom, 100)
                            .transition(.scale.combined(with: .opacity))
                        }
                    }

                    Spacer()

                    // Dictation button at bottom
                    if inputState != .initial {
                        Button(action: {}) {
                            Image(systemName: "mic.circle.fill")
                                .font(.system(size: 32, weight: .medium))
                                .foregroundStyle(isDictating ? .white : .blue)
                                .frame(width: 64, height: 64)
                                .background(isDictating ? Color.blue : Color.clear, in: Circle())
                                .scaleEffect(isDictating ? (isPulsing ? 1.3 : 1.2) : 1.0)
                                .animation(.easeInOut(duration: 0.2), value: isDictating)
                        }
                        .simultaneousGesture(
                            DragGesture(minimumDistance: 0)
                                .onChanged { _ in
                                    if !isDictating {
                                        startDictating()
                                    }
                                }
                                .onEnded { _ in
                                    if isDictating {
                                        stopDictating()
                                    }
                                }
                        )
                        .disabled(isSending)
                        .padding(.bottom, 30)
                    }
                }
            }
            .frame(height: overlayHeight)
            .frame(maxWidth: .infinity, alignment: .bottom)
            .offset(y: dragOffset)
            .gesture(
                DragGesture()
                    .onChanged { value in
                        // Only allow downward drags
                        if value.translation.height > 0 {
                            dragOffset = value.translation.height
                        }
                    }
                    .onEnded { value in
                        // Dismiss if dragged down more than 100pt
                        if value.translation.height > 100 {
                            dismissOverlay()
                        } else {
                            // Snap back
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                dragOffset = 0
                            }
                        }
                    }
            )
        }
    }

    // MARK: - Computed Properties

    private var hasContent: Bool {
        !messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var canSend: Bool {
        hasContent && !isSending
    }

    // MARK: - Actions

    private func startTyping() {
        inputState = .typing
        showOverlay = true

        // Auto-focus text field
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            isTextFieldFocused = true
        }
    }

    private func startDictating() {
        guard !isDictating else { return }

        inputState = .dictating
        showOverlay = true
        isDictating = true

        // Prepare haptics
        #if os(iOS)
        feedbackGenerator.prepare()
        lastWordCount = messageText.split(separator: " ").count
        #endif

        // Reset speech recognizer
        speechRecognizer.reset()

        // Start pulsing animation
        withAnimation(.easeInOut(duration: 0.6).repeatForever(autoreverses: true)) {
            isPulsing = true
        }

        Task {
            // Request authorization if needed
            if speechRecognizer.authorizationStatus == .notDetermined {
                let authorized = await speechRecognizer.requestAuthorization()
                if !authorized {
                    await MainActor.run {
                        isDictating = false
                        isPulsing = false
                        showPermissionAlert = true
                    }
                    return
                }
            }

            // Start recording
            do {
                try await speechRecognizer.startRecording()

                #if os(iOS)
                feedbackGenerator.impactOccurred()
                #endif
            } catch {
                print("❌ Failed to start recording: \(error)")
                await MainActor.run {
                    isDictating = false
                    isPulsing = false
                    showPermissionAlert = true
                }
            }
        }
    }

    private func stopDictating() {
        guard isDictating else { return }

        speechRecognizer.stopRecording()
        isDictating = false
        isPulsing = false

        // Haptic feedback
        #if os(iOS)
        feedbackGenerator.impactOccurred()
        #endif

        // Update state
        if hasContent {
            inputState = .hasText
        } else {
            // If no text, return to initial
            dismissOverlay()
        }
    }

    private func handleSend() {
        guard canSend else { return }

        // Call parent's send function
        onSendMessage()

        // Reset state
        inputState = .initial
        showOverlay = false
        isTextFieldFocused = false
        dragOffset = 0
    }

    private func dismissOverlay() {
        // Clear text if user explicitly dismisses
        if !hasContent {
            messageText = ""
        }

        inputState = .initial
        showOverlay = false
        isTextFieldFocused = false
        isDictating = false
        isPulsing = false

        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            dragOffset = 0
        }
    }
}

@available(iOS 26.0, *)
#Preview {
    @Previewable @State var messageText = ""
    @Previewable @State var isSending = false

    MessageInputOverlay(
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
        ),
        messageText: $messageText,
        isSending: $isSending,
        onSendMessage: {
            print("Send message: \(messageText)")
        }
    )
}
