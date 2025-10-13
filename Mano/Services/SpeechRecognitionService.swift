//
//  SpeechRecognitionService.swift
//  Mano
//
//  Created by Claude on 12/10/2025.
//

import Foundation
import Speech
import AVFoundation
import Combine

@MainActor
class SpeechRecognitionService: ObservableObject {
    @Published var transcribedText: String = ""
    @Published var isRecording: Bool = false
    @Published var authorizationStatus: SFSpeechRecognizerAuthorizationStatus = .notDetermined

    private var speechRecognizer: SFSpeechRecognizer?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private var audioEngine: AVAudioEngine?

    init() {
        speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
        authorizationStatus = SFSpeechRecognizer.authorizationStatus()
    }

    /// Request permission to use speech recognition
    func requestAuthorization() async -> Bool {
        await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                Task { @MainActor in
                    self.authorizationStatus = status
                    continuation.resume(returning: status == .authorized)
                }
            }
        }
    }

    /// Start recording and transcribing speech
    func startRecording() async throws {
        // Cancel any ongoing recognition task
        if recognitionTask != nil {
            stopRecording()
        }

        // Check authorization
        guard authorizationStatus == .authorized else {
            throw SpeechRecognitionError.notAuthorized
        }

        // Configure audio session
        let audioSession = AVAudioSession.sharedInstance()
        try audioSession.setCategory(.record, mode: .measurement, options: .duckOthers)
        try audioSession.setActive(true, options: .notifyOthersOnDeactivation)

        // Create and configure recognition request
        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        guard let recognitionRequest = recognitionRequest else {
            throw SpeechRecognitionError.unableToCreateRequest
        }

        recognitionRequest.shouldReportPartialResults = true

        // Create audio engine if needed
        if audioEngine == nil {
            audioEngine = AVAudioEngine()
        }

        guard let audioEngine = audioEngine else {
            throw SpeechRecognitionError.audioEngineUnavailable
        }

        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)

        // Install tap on audio input
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { buffer, _ in
            recognitionRequest.append(buffer)
        }

        // Start audio engine
        audioEngine.prepare()
        try audioEngine.start()

        // Start recognition task
        recognitionTask = speechRecognizer?.recognitionTask(with: recognitionRequest) { [weak self] result, error in
            guard let self = self else { return }

            Task { @MainActor in
                if let result = result {
                    // Update transcribed text with partial or final results
                    self.transcribedText = result.bestTranscription.formattedString

                    // Check if this is the final result
                    if result.isFinal {
                        self.stopRecording()
                    }
                }

                if let error = error {
                    print("❌ Speech recognition error: \(error.localizedDescription)")
                    self.stopRecording()
                }
            }
        }

        isRecording = true
    }

    /// Stop recording and transcription
    func stopRecording() {
        audioEngine?.stop()
        audioEngine?.inputNode.removeTap(onBus: 0)
        recognitionRequest?.endAudio()
        recognitionTask?.cancel()

        recognitionRequest = nil
        recognitionTask = nil

        isRecording = false
    }

    /// Reset transcription
    func reset() {
        transcribedText = ""
    }
}

enum SpeechRecognitionError: LocalizedError {
    case notAuthorized
    case unableToCreateRequest
    case audioEngineUnavailable

    var errorDescription: String? {
        switch self {
        case .notAuthorized:
            return "Speech recognition not authorized. Please enable microphone access in Settings."
        case .unableToCreateRequest:
            return "Unable to create speech recognition request."
        case .audioEngineUnavailable:
            return "Audio engine unavailable."
        }
    }
}
