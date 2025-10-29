//
//  MessageInputComponent.swift
//  Mano
//
//  Voice-first input component with four states
//

import SwiftUI
import AVFoundation
import Combine

@available(iOS 26.0, *)
enum VoiceInputState: Equatable {
    case idle
    case recording
    case typing(keyboardVisible: Bool)
}

@available(iOS 26.0, *)
struct MessageInputComponent: View {
    let person: Person
    let onSendMessage: (String) -> Void

    @StateObject private var voiceManager = VoiceRecordingManager()
    @State private var inputState: VoiceInputState = .idle
    @State private var messageText: String = ""
    @State private var keyboardHeight: CGFloat = 0
    @FocusState private var isTextFieldFocused: Bool

    // Dynamic placeholder text
    var placeholderText: String {
        "Talk about \(person.firstName)"
    }

    var body: some View {
        Group {
            switch inputState {
            case .idle:
                idleInputView
                    .padding(.horizontal, Spacing.lg)  // 20px margins ONLY in idle
                    .padding(.bottom, Spacing.md)

            case .recording:
                recordingInputView
                // NO horizontal padding - full width

            case .typing(let keyboardVisible):
                typingInputView(keyboardVisible: keyboardVisible)
                // NO offset - let system handle keyboard avoidance
                // NO horizontal padding - full width
            }
        }
        .transition(.move(edge: .bottom).combined(with: .opacity))
        .animation(.easeOut(duration: 0.25), value: inputState)
        .onReceive(Publishers.keyboardHeight) { height in
            keyboardHeight = height
            withAnimation(.easeOut(duration: 0.25)) {
                if height > 0, case .typing = inputState {
                    inputState = .typing(keyboardVisible: true)
                } else if height == 0, case .typing = inputState {
                    inputState = .typing(keyboardVisible: false)
                }
            }
        }
    }

    // MARK: - Idle State View (56×56px pulsing mic, with margins)

    var idleInputView: some View {
        HStack(spacing: Spacing.md) {
            // Text hint (tappable to activate typing)
            TextField("", text: $messageText, prompt: Text(placeholderText).foregroundColor(.tertiaryText))
                .font(.system(size: 16))
                .foregroundColor(.primaryText)
                .disabled(true)  // Disable direct editing
                .allowsHitTesting(true)  // Ensure taps work
                .contentShape(Rectangle())  // Make entire area tappable
                .onTapGesture {
                    // IMMEDIATELY transition to typing mode
                    withAnimation(.easeOut(duration: 0.25)) {
                        inputState = .typing(keyboardVisible: true)
                    }
                    // Focus text field (keyboard appears in parallel)
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                        isTextFieldFocused = true
                    }
                }

            // Mic button (56×56px with pulse)
            Button {} label: {
                Image(systemName: "mic.fill")
                    .font(.system(size: 24))
                    .foregroundColor(.white)
            }
            .frame(width: 56, height: 56)  // 56px in idle
            .background(Color.warmYellow)
            .cornerRadius(CornerRadius.button)
            .shadow(color: Color.warmYellow.opacity(0.4), radius: 4, x: 0, y: 0)
            .modifier(PulseModifier())  // Gentle pulse animation
            .onLongPressGesture(minimumDuration: 0.1, maximumDistance: 50) {
                // Gesture complete
            } onPressingChanged: { isPressing in
                if isPressing {
                    // Finger down - start recording immediately
                    if inputState == .idle {
                        withAnimation(.easeOut(duration: 0.2)) {
                            inputState = .recording
                        }
                        Task {
                            await startRecordingAsync()
                        }
                        #if os(iOS)
                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                        #endif
                    }
                } else {
                    // Finger lifted - stop recording
                    if inputState == .recording {
                        stopRecording()
                    }
                }
            }
        }
        .padding(.horizontal, Spacing.md)
        .padding(.vertical, Spacing.sm)
        .frame(height: 64)
        .background(Color.white)
        .cornerRadius(CornerRadius.input)  // 12px all corners
        .overlay(
            RoundedRectangle(cornerRadius: CornerRadius.input)
                .stroke(Color.stone, lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.08), radius: 20, x: 0, y: -4)
    }

    // MARK: - Recording State View (80×80px visual indicator, full width)

    var recordingInputView: some View {
        VStack(spacing: Spacing.base) {
            // Instructions row
            HStack {
                HStack(spacing: Spacing.sm) {
                    Circle()
                        .fill(Color.warmYellow)
                        .frame(width: 8, height: 8)
                        .modifier(PulseDotModifier())

                    Text("Hold to continue speaking")
                        .font(.system(size: 13))
                        .foregroundColor(.tertiaryText)
                }

                Spacer()

                Text("Release to finish")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.primaryText)
            }
            .padding(.horizontal, Spacing.lg)

            // Transcription area (scrollable)
            ScrollView {
                Text(voiceManager.transcriptionText.isEmpty ? "Listening..." : voiceManager.transcriptionText)
                    .font(.system(size: 17))
                    .foregroundColor(voiceManager.transcriptionText.isEmpty ? .tertiaryText : .primaryText)
                    .lineSpacing(8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, Spacing.lg)
            }
            .frame(minHeight: 80, maxHeight: 160)

            // Waveform visualization
            HStack(spacing: 4) {
                ForEach(0..<25, id: \.self) { index in
                    Rectangle()
                        .fill(Color.warmYellow.opacity(0.6))
                        .frame(width: 2, height: voiceManager.audioLevels[index])
                        .cornerRadius(1)
                        .animation(.linear(duration: 0.05), value: voiceManager.audioLevels[index])
                }
            }
            .frame(height: 24)
            .padding(.bottom, Spacing.base)

            // Large visual mic indicator (80×80px)
            ZStack {
                // Outer glow
                Circle()
                    .fill(Color.warmYellow.opacity(0.2))
                    .frame(width: 100, height: 100)
                    .blur(radius: 10)

                // Main circle (80×80px when recording)
                Circle()
                    .fill(Color.warmYellow)
                    .frame(width: 80, height: 80)
                    .overlay(
                        Image(systemName: "mic.fill")
                            .font(.system(size: 32))
                            .foregroundColor(.white)
                    )
                    .shadow(color: Color.warmYellow.opacity(0.5), radius: 20, x: 0, y: 4)
            }
            .scaleEffect(1.05)  // Slight scale for emphasis
        }
        .padding(.vertical, Spacing.lg)
        .frame(minHeight: 280, maxHeight: 360)
        .background(Color.white)
        .cornerRadius(24, corners: [.topLeft, .topRight])  // 24px top, 0px bottom
        .overlay(
            Rectangle()
                .frame(height: 1)
                .foregroundColor(.stone),
            alignment: .top
        )
        .shadow(color: Color.black.opacity(0.12), radius: 24, x: 0, y: -4)
    }

    // MARK: - Typing State View (40×40px mic, full width)

    func typingInputView(keyboardVisible: Bool) -> some View {
        VStack(spacing: Spacing.md) {
            // Text editor
            TextEditor(text: $messageText)
                .focused($isTextFieldFocused)
                .font(.system(size: 17))
                .foregroundColor(.primaryText)
                .lineSpacing(8)
                .padding(Spacing.md)
                .frame(minHeight: keyboardVisible ? 44 : 60, maxHeight: keyboardVisible ? 88 : 120)
                .background(Color.almostWhite)
                .overlay(
                    RoundedRectangle(cornerRadius: CornerRadius.input)
                        .stroke(Color.stone, lineWidth: 1)
                )
                .cornerRadius(CornerRadius.input)
                .scrollContentBackground(.hidden)

            // Button row - SEND FIRST, MIC LAST
            HStack(spacing: Spacing.md) {
                // Send button (expands to fill available space)
                Button {
                    sendMessage()
                } label: {
                    Text("Send")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                }
                .frame(maxWidth: .infinity)  // Expands to fill
                .frame(height: 40)
                .background(messageText.isEmpty ? Color.secondaryText : Color.forestGreen)
                .cornerRadius(CornerRadius.button)
                .disabled(messageText.isEmpty)

                // Small mic button (40×40px, NO PULSE) - Fixed on right
                Button {} label: {
                    Image(systemName: "mic.fill")
                        .font(.system(size: 18))
                        .foregroundColor(.white)
                }
                .frame(width: 40, height: 40)  // Fixed size on right
                .background(Color.warmYellow)
                .cornerRadius(CornerRadius.button)
                // NO PulseModifier - static in typing mode
                .onLongPressGesture(minimumDuration: 0.1, maximumDistance: 50) {
                    // Gesture complete
                } onPressingChanged: { isPressing in
                    if isPressing {
                        // Finger down - dismiss keyboard and start recording
                        isTextFieldFocused = false
                        withAnimation(.easeOut(duration: 0.2)) {
                            inputState = .recording
                        }
                        Task {
                            await startRecordingAsync()
                        }
                        #if os(iOS)
                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                        #endif
                    } else {
                        // Finger lifted - stop recording
                        if inputState == .recording {
                            stopRecording()
                        }
                    }
                }
            }
        }
        .padding(Spacing.base)
        .background(Color.white)
        .cornerRadius(24, corners: [.topLeft, .topRight])  // 24px top, 0px bottom
        .overlay(
            Rectangle()
                .frame(height: 1)
                .foregroundColor(.stone),
            alignment: .top
        )
        .shadow(color: Color.black.opacity(0.12), radius: 24, x: 0, y: -4)
        .padding(.bottom, keyboardVisible ? 0 : Spacing.md)  // NO gap when keyboard visible
    }

    // MARK: - Actions

    func startRecordingAsync() async {
        // Request speech recognition authorization if needed
        let authorized = await voiceManager.requestAuthorization()
        if !authorized {
            // TODO: Show alert that authorization is required
            return
        }

        do {
            try voiceManager.startRecording()

            // Trigger haptic feedback
            #if os(iOS)
            let generator = UIImpactFeedbackGenerator(style: .medium)
            generator.impactOccurred()
            #endif
        } catch {
            print("❌ Recording failed: \(error)")
            // TODO: Show error alert
        }
    }

    func stopRecording() {
        voiceManager.stopRecording()
        messageText = voiceManager.transcriptionText
        withAnimation(.easeOut(duration: 0.2)) {
            inputState = .typing(keyboardVisible: false)
        }

        // Haptic feedback
        #if os(iOS)
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()
        #endif
    }

    func sendMessage() {
        guard !messageText.isEmpty else { return }

        let message = messageText
        messageText = ""
        voiceManager.reset()
        isTextFieldFocused = false

        withAnimation(.easeOut(duration: 0.25)) {
            inputState = .idle
        }

        // Call the send callback
        onSendMessage(message)
    }
}
