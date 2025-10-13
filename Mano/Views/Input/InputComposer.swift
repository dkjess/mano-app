//
//  InputComposer.swift
//  Mano
//
//  Created by Claude on 06/09/2025.
//

import SwiftUI
import PhotosUI
import UniformTypeIdentifiers
import Speech

struct InputComposer: View {
    let person: Person
    @Binding var messageText: String
    @Binding var isSending: Bool
    @FocusState var isInputFocused: Bool

    let onSendMessage: () -> Void

    @StateObject private var speechRecognizer = SpeechRecognitionService()
    @State private var isHoldingMic = false
    @State private var showPermissionAlert = false

    var canSend: Bool {
        !messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isSending
    }
    
    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            // Microphone button
            Button(action: {}) {
                Image(systemName: "mic.fill")
                    .font(.system(size: 20))
                    .foregroundStyle(isHoldingMic ? .white : .blue)
                    .frame(width: 40, height: 40)
                    .background(isHoldingMic ? Color.blue : Color.clear, in: Circle())
                    .scaleEffect(isHoldingMic ? 1.1 : 1.0)
                    .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isHoldingMic)
            }
            .simultaneousGesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in
                        if !isHoldingMic {
                            startRecording()
                        }
                    }
                    .onEnded { _ in
                        stopRecording()
                    }
            )
            .disabled(isSending)

            // Text input area with integrated send button
            ZStack(alignment: .bottomTrailing) {
                // Placeholder
                if messageText.isEmpty && !isInputFocused && !isHoldingMic {
                    Text("Talk about \(person.name)...")
                        .foregroundStyle(.tertiary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .allowsHitTesting(false)
                }

                // Text editor with padding for send button
                TextEditor(text: $messageText)
                    .scrollContentBackground(.hidden)
                    .padding(.leading, 12)
                    .padding(.trailing, hasContent || isInputFocused ? 48 : 12) // Extra padding for button
                    .padding(.vertical, 8)
                    .frame(minHeight: 36, maxHeight: isInputFocused ? 120 : 60)
                    .fixedSize(horizontal: false, vertical: isInputFocused ? false : true)
                    .focused($isInputFocused)
                    .disabled(isHoldingMic) // Disable editing while recording

                // Send button inside the input area - bottom right
                if hasContent || isInputFocused {
                    Button(action: onSendMessage) {
                        Image(systemName: "arrow.up")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(width: 32, height: 32)
                            .background(canSend ? Color.blue : Color.gray.opacity(0.5), in: Circle())
                            .scaleEffect(isSending ? 0.9 : 1.0)
                            .animation(.spring(response: 0.2, dampingFraction: 0.7), value: isSending)
                    }
                    .disabled(!canSend)
                    .keyboardShortcut(.return, modifiers: .command)
                    .padding(.trailing, 8)
                    .padding(.bottom, 6)
                    .transition(.scale.combined(with: .opacity))
                }
            }
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(isInputFocused ? AnyShapeStyle(.white) : AnyShapeStyle(.ultraThinMaterial))
            )
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
        .padding(.horizontal, 12)
        .padding(.bottom, 12)
        .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
        .overlay(alignment: .bottom) {
            if isHoldingMic {
                // Waveform visualization
                HStack(spacing: 2) {
                    ForEach(0..<20) { index in
                        RoundedRectangle(cornerRadius: 2)
                            .fill(Color.blue.opacity(0.6))
                            .frame(width: 3, height: CGFloat.random(in: 4...20))
                            .animation(
                                .easeInOut(duration: 0.3)
                                .repeatForever(autoreverses: true)
                                .delay(Double(index) * 0.05),
                                value: isHoldingMic
                            )
                    }
                }
                .padding(.bottom, 4)
            }
        }
        .onChange(of: speechRecognizer.transcribedText) { newText in
            // Update message text with live transcription
            if isHoldingMic && !newText.isEmpty {
                messageText = newText
            }
        }
        .alert("Microphone Access Required", isPresented: $showPermissionAlert) {
            Button("Settings") {
                if let settingsUrl = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(settingsUrl)
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Please enable microphone access in Settings to use speech-to-text.")
        }
    }

    private var hasContent: Bool {
        !messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func startRecording() {
        guard !isHoldingMic else { return }

        isHoldingMic = true
        speechRecognizer.reset()

        Task {
            // Request authorization if needed
            if speechRecognizer.authorizationStatus == .notDetermined {
                let authorized = await speechRecognizer.requestAuthorization()
                if !authorized {
                    await MainActor.run {
                        isHoldingMic = false
                        showPermissionAlert = true
                    }
                    return
                }
            }

            // Start recording
            do {
                try await speechRecognizer.startRecording()
                // Add haptic feedback
                #if os(iOS)
                let generator = UIImpactFeedbackGenerator(style: .light)
                generator.impactOccurred()
                #endif
            } catch {
                print("❌ Failed to start recording: \(error)")
                await MainActor.run {
                    isHoldingMic = false
                    showPermissionAlert = true
                }
            }
        }
    }

    private func stopRecording() {
        guard isHoldingMic else { return }

        speechRecognizer.stopRecording()
        isHoldingMic = false

        // Add haptic feedback
        #if os(iOS)
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()
        #endif
    }
}

#Preview {
    @Previewable @State var messageText = ""
    @Previewable @State var isSending = false
    
    InputComposer(
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
        onSendMessage: {}
    )
    .padding()
}
