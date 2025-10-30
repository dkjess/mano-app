//
//  MessageInputComponent.swift
//  Mano
//
//  Voice-first input component with four states
//

import SwiftUI
import AVFoundation
import Combine
import UIKit

// MARK: - Auto-scrolling TextEditor wrapper

struct AutoScrollTextEditor: UIViewRepresentable {
    @Binding var text: String
    @Binding var isFocused: Bool
    @Binding var calculatedHeight: CGFloat

    func makeUIView(context: Context) -> UITextView {
        let textView = UITextView()
        textView.delegate = context.coordinator
        textView.font = UIFont.systemFont(ofSize: 17)
        textView.textColor = UIColor(ManoColors.primaryText)
        textView.backgroundColor = .clear
        textView.textContainerInset = UIEdgeInsets(top: 12, left: 12, bottom: 12, right: 12)
        textView.isScrollEnabled = true
        textView.showsVerticalScrollIndicator = true
        textView.alwaysBounceVertical = false
        textView.isUserInteractionEnabled = true
        return textView
    }

    func updateUIView(_ uiView: UITextView, context: Context) {
        if uiView.text != text {
            uiView.text = text
            // Force layout update to recalculate content size
            uiView.setNeedsLayout()
            uiView.layoutIfNeeded()
            // Scroll to cursor after text update
            DispatchQueue.main.async {
                scrollToCursor(uiView)
            }
        }

        // Handle focus state
        if isFocused && !uiView.isFirstResponder {
            uiView.becomeFirstResponder()
        } else if !isFocused && uiView.isFirstResponder {
            uiView.resignFirstResponder()
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    private func scrollToCursor(_ textView: UITextView) {
        // Scroll to the cursor position
        if let selectedRange = textView.selectedTextRange {
            let caretRect = textView.caretRect(for: selectedRange.end)
            textView.scrollRectToVisible(caretRect, animated: false)
        }
    }

    class Coordinator: NSObject, UITextViewDelegate {
        var parent: AutoScrollTextEditor

        init(_ parent: AutoScrollTextEditor) {
            self.parent = parent
        }

        func textViewDidChange(_ textView: UITextView) {
            parent.text = textView.text

            // Calculate height from content size
            let size = textView.sizeThatFits(CGSize(width: textView.frame.width, height: .infinity))
            let newHeight = max(44, min(170, size.height))

            DispatchQueue.main.async {
                self.parent.calculatedHeight = newHeight
            }

            // Scroll to cursor when text changes
            DispatchQueue.main.async {
                if let selectedRange = textView.selectedTextRange {
                    let caretRect = textView.caretRect(for: selectedRange.end)
                    textView.scrollRectToVisible(caretRect, animated: false)
                }
            }
        }

        func textViewDidBeginEditing(_ textView: UITextView) {
            parent.isFocused = true
        }

        func textViewDidEndEditing(_ textView: UITextView) {
            parent.isFocused = false
        }
    }
}

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
    @Binding var shouldDismiss: Bool

    @StateObject private var voiceManager = VoiceRecordingManager()
    @State private var inputState: VoiceInputState = .idle
    @State private var messageText: String = ""
    @State private var keyboardHeight: CGFloat = 0
    @State private var safeAreaBottom: CGFloat = 0
    @State private var textEditorHeight: CGFloat = 44
    @State private var isTextFieldFocused: Bool = false
    @State private var textBeforeRecording: String = ""

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
                    .offset(y: keyboardVisible ? -(keyboardHeight - safeAreaBottom) : 0)
            }
        }
        .background(
            GeometryReader { geometry in
                Color.clear
                    .onAppear {
                        safeAreaBottom = geometry.safeAreaInsets.bottom
                    }
                    .onChange(of: geometry.safeAreaInsets.bottom) { oldValue, newValue in
                        safeAreaBottom = newValue
                    }
            }
        )
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
        .onChange(of: shouldDismiss) { _, newValue in
            if newValue {
                dismissInput()
                // Reset the trigger
                shouldDismiss = false
            }
        }
    }

    // MARK: - Dismissal

    private func dismissInput() {
        // Only dismiss if in typing mode
        guard case .typing = inputState else { return }

        // Dismiss keyboard
        isTextFieldFocused = false

        // Return to idle state
        withAnimation(.easeOut(duration: 0.25)) {
            inputState = .idle
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
            Button {
                // Simple tap to start recording
                textBeforeRecording = messageText  // Save existing text
                withAnimation(.easeOut(duration: 0.2)) {
                    inputState = .recording
                }
                Task {
                    await startRecordingAsync()
                }
                #if os(iOS)
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                #endif
            } label: {
                Image(systemName: "mic.fill")
                    .font(.system(size: 18))
                    .foregroundColor(.white)
            }
            .frame(width: 40, height: 40)  // 40px matches typing state
            .background(Color.warmYellow)
            .cornerRadius(CornerRadius.button)
            .shadow(color: Color.warmYellow.opacity(0.4), radius: 4, x: 0, y: 0)
            .modifier(PulseModifier())  // Gentle pulse animation
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

                    Text("Listening...")
                        .font(.system(size: 13))
                        .foregroundColor(.tertiaryText)
                }

                Spacer()

                Text("Tap to finish")
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

            // Large stop/pause button (80×80px)
            Button {
                // Stop recording and transition to typing
                stopRecording()
            } label: {
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
                            Image(systemName: "pause.fill")
                                .font(.system(size: 32))
                                .foregroundColor(.white)
                        )
                        .shadow(color: Color.warmYellow.opacity(0.5), radius: 20, x: 0, y: 4)
                }
                .scaleEffect(1.05)  // Slight scale for emphasis
            }
            .buttonStyle(PlainButtonStyle())
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
            // Text editor - starts at 1 line, expands to max 6 lines
            AutoScrollTextEditor(
                text: $messageText,
                isFocused: $isTextFieldFocused,
                calculatedHeight: $textEditorHeight
            )
            .frame(height: textEditorHeight)
            .animation(.easeOut(duration: 0.2), value: textEditorHeight)
            .background(Color.almostWhite)
            .overlay(
                RoundedRectangle(cornerRadius: CornerRadius.input)
                    .stroke(Color.stone, lineWidth: 1)
            )
            .cornerRadius(CornerRadius.input)

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
                Button {
                    // Simple tap - dismiss keyboard and start recording
                    textBeforeRecording = messageText  // Save existing text
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
                } label: {
                    Image(systemName: "mic.fill")
                        .font(.system(size: 18))
                        .foregroundColor(.white)
                }
                .frame(width: 40, height: 40)  // Fixed size on right
                .background(Color.warmYellow)
                .cornerRadius(CornerRadius.button)
                // NO PulseModifier - static in typing mode
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

        // Append new transcription to existing text
        let newTranscription = voiceManager.transcriptionText
        if !textBeforeRecording.isEmpty && !newTranscription.isEmpty {
            // Add space between existing and new text
            messageText = textBeforeRecording + " " + newTranscription
        } else if !newTranscription.isEmpty {
            // No existing text, just use new transcription
            messageText = newTranscription
        } else {
            // No new transcription, keep existing text
            messageText = textBeforeRecording
        }

        textBeforeRecording = ""  // Clear saved text

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
