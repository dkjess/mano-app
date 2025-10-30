//
//  VoiceRecordingManager.swift
//  Mano
//
//  Voice recording and speech recognition manager
//

import Foundation
import Speech
import AVFoundation
import Combine

@available(iOS 26.0, *)
class VoiceRecordingManager: ObservableObject {
    private let speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let audioEngine = AVAudioEngine()

    @Published var transcriptionText: String = ""
    @Published var audioLevels: [CGFloat] = Array(repeating: 2, count: 25)
    @Published var isRecording: Bool = false

    // Request authorization
    func requestAuthorization() async -> Bool {
        await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status == .authorized)
            }
        }
    }

    // Start recording
    func startRecording() throws {
        // Cancel any existing task
        recognitionTask?.cancel()
        recognitionTask = nil

        // Configure audio session
        let audioSession = AVAudioSession.sharedInstance()
        try audioSession.setCategory(.record, mode: .measurement, options: .duckOthers)
        try audioSession.setActive(true, options: .notifyOthersOnDeactivation)

        // Create recognition request
        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        guard let recognitionRequest = recognitionRequest else {
            throw NSError(domain: "VoiceRecording", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to create recognition request"])
        }

        recognitionRequest.shouldReportPartialResults = true

        // Configure audio engine
        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)

        // Install tap for waveform visualization
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { [weak self] buffer, _ in
            self?.recognitionRequest?.append(buffer)
            self?.updateAudioLevels(buffer: buffer)
        }

        audioEngine.prepare()
        try audioEngine.start()

        // Start recognition
        recognitionTask = speechRecognizer?.recognitionTask(with: recognitionRequest) { [weak self] result, error in
            if let result = result {
                DispatchQueue.main.async {
                    self?.transcriptionText = result.bestTranscription.formattedString
                }
            }

            if error != nil || result?.isFinal == true {
                self?.stopRecording()
            }
        }

        isRecording = true
    }

    // Stop recording
    func stopRecording() {
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        recognitionRequest?.endAudio()
        recognitionTask?.cancel()

        recognitionRequest = nil
        recognitionTask = nil
        isRecording = false
    }

    // Reset transcription
    func reset() {
        transcriptionText = ""
        audioLevels = Array(repeating: 2, count: 25)
    }

    // Update waveform audio levels
    private func updateAudioLevels(buffer: AVAudioPCMBuffer) {
        guard let channelData = buffer.floatChannelData?[0] else { return }
        let frameLength = Int(buffer.frameLength)

        // Calculate RMS (root mean square) for amplitude
        var sum: Float = 0
        for i in 0..<frameLength {
            let sample = channelData[i]
            sum += sample * sample
        }
        let rms = sqrt(sum / Float(frameLength))
        let db = 20 * log10(rms)

        // Map to height (2-20px)
        let normalizedLevel = max(0, min(1, (db + 50) / 50))
        let height = 2 + (normalizedLevel * 18)

        // Update levels with smoothing (exponential moving average)
        DispatchQueue.main.async {
            self.audioLevels.removeFirst()
            self.audioLevels.append(CGFloat(height))
        }
    }
}
