//
//  MessageInputBar.swift
//  Mano
//
//  Created by Claude on 25/10/2025.
//  iOS 26.0+ | Swift 6.2
//

import SwiftUI
import Speech

#if os(iOS)
import UIKit
#endif

@available(iOS 26.0, *)
struct MessageInputBar: View {
    let person: Person
    @Binding var messageText: String
    @Binding var isSending: Bool
    let onSendMessage: () -> Void

    // Expose focus state to parent
    @FocusState.Binding var isTextFieldFocused: Bool

    // State management
    @State private var textEditorHeight: CGFloat = 40 // Single line height
    @State private var isDictating: Bool = false
    @State private var isPulsing: Bool = false

    // Speech recognition
    @StateObject private var speechRecognizer = SpeechRecognitionService()
    @State private var showPermissionAlert = false

    // Haptics
    #if os(iOS)
    @State private var feedbackGenerator = UIImpactFeedbackGenerator(style: .light)
    @State private var lastWordCount = 0
    #endif

    private let minHeight: CGFloat = 40
    private let maxHeight: CGFloat = 120 // ~5 lines

    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            // Mic button (left side, hidden when text present)
            if !hasContent {
                Button(action: {}) {
                    Image(systemName: isDictating ? "mic.fill" : "mic.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(.white)
                        .frame(width: 36, height: 36)
                        .background(
                            Circle()
                                .fill(ManoColors.warmYellow)
                                .scaleEffect(isDictating ? (isPulsing ? 1.15 : 1.0) : 1.0)
                        )
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
                .transition(.scale.combined(with: .opacity))
            }

            // Text input area (rounded rectangle)
            TextEditor(text: $messageText)
                .textInputAutocapitalization(.sentences)
                .autocorrectionDisabled(false)
                .scrollContentBackground(.hidden)
                .frame(height: textEditorHeight)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(ManoColors.pureWhite)
                        .stroke(ManoColors.stone, lineWidth: 1)
                )
                .focused($isTextFieldFocused)
                .disabled(isDictating)
                .background(
                    // Hidden text for height measurement
                    Text(messageText.isEmpty ? " " : messageText)
                        .font(.body)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(
                            GeometryReader { geo in
                                Color.clear.preference(
                                    key: HeightPreferenceKey.self,
                                    value: geo.size.height
                                )
                            }
                        )
                        .hidden()
                )
                .onPreferenceChange(HeightPreferenceKey.self) { newHeight in
                    withAnimation(.easeOut(duration: 0.2)) {
                        textEditorHeight = min(max(minHeight, newHeight), maxHeight)
                    }
                }

            // Send button (right side, separate circle, only when text present)
            if hasContent {
                Button(action: handleSend) {
                    Image(systemName: "arrow.up")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 36, height: 36)
                        .background(
                            Circle()
                                .fill(canSend ? ManoColors.forestGreen : ManoColors.stone)
                        )
                }
                .disabled(!canSend)
                .transition(.scale.combined(with: .opacity))
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(ManoColors.almostWhite)
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: hasContent)
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

    // MARK: - Computed Properties

    private var hasContent: Bool {
        !messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var canSend: Bool {
        hasContent && !isSending
    }

    // MARK: - Actions

    private func startDictating() {
        guard !isDictating else { return }

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
    }

    private func handleSend() {
        guard canSend else { return }

        // Hide keyboard
        isTextFieldFocused = false

        // Call parent's send function
        onSendMessage()
    }
}

// MARK: - Preference Key for Height Measurement

private struct HeightPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 40

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

@available(iOS 26.0, *)
#Preview {
    @Previewable @State var messageText = ""
    @Previewable @State var isSending = false
    @Previewable @FocusState var isInputFocused: Bool

    VStack {
        Spacer()

        MessageInputBar(
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
            },
            isTextFieldFocused: $isInputFocused
        )
    }
}
