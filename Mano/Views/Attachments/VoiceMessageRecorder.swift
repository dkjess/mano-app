//
//  VoiceMessageRecorder.swift
//  Mano
//
//  Created by Claude on 06/09/2025.
//

import SwiftUI
import AVFoundation
import Accelerate
import Combine

// MARK: - Voice Message Recorder

#if os(iOS)
@MainActor
class VoiceMessageRecorder: NSObject, ObservableObject {
    @Published var isRecording = false
    @Published var recordingTime: TimeInterval = 0
    @Published var audioLevels: [Float] = []
    @Published var hasPermission = false
    
    private var audioRecorder: AVAudioRecorder?
    private var recordingTimer: Timer?
    private var levelTimer: Timer?
    private var recordingURL: URL?
    
    override init() {
        super.init()
        setupAudioSession()
        requestPermission()
    }
    
    private func setupAudioSession() {
        do {
            try AVAudioSession.sharedInstance().setCategory(.playAndRecord, mode: .default)
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            print("Failed to set up audio session: \(error)")
        }
    }
    
    private func requestPermission() {
        Task {
            do {
                try AVAudioSession.sharedInstance().setActive(true)
                
                // Use the new iOS 17+ API
                if #available(iOS 17.0, *) {
                    let granted = await AVAudioApplication.requestRecordPermission()
                    await MainActor.run {
                        self.hasPermission = granted
                    }
                } else {
                    // Fallback for older versions
                    let granted = await withCheckedContinuation { continuation in
                        AVAudioSession.sharedInstance().requestRecordPermission { result in
                            continuation.resume(returning: result)
                        }
                    }
                    await MainActor.run {
                        self.hasPermission = granted
                    }
                }
            } catch {
                await MainActor.run {
                    self.hasPermission = false
                }
            }
        }
    }
    
    func startRecording() {
        guard hasPermission, !isRecording else { return }
        
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        recordingURL = documentsPath.appendingPathComponent("voice_message_\(Date().timeIntervalSince1970).m4a")
        
        let settings = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 44100,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]
        
        do {
            audioRecorder = try AVAudioRecorder(url: recordingURL!, settings: settings)
            audioRecorder?.delegate = self
            audioRecorder?.isMeteringEnabled = true
            audioRecorder?.record()
            
            isRecording = true
            recordingTime = 0
            audioLevels = []
            
            startTimers()
            
            // Haptic feedback
            let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
            impactFeedback.impactOccurred()
            
        } catch {
            print("Failed to start recording: \(error)")
        }
    }
    
    func stopRecording() -> URL? {
        guard isRecording else { return nil }
        
        audioRecorder?.stop()
        isRecording = false
        
        stopTimers()
        
        // Haptic feedback
        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
        impactFeedback.impactOccurred()
        
        return recordingURL
    }
    
    func cancelRecording() {
        guard isRecording else { return }
        
        audioRecorder?.stop()
        isRecording = false
        
        stopTimers()
        
        // Delete the recording file
        if let url = recordingURL {
            try? FileManager.default.removeItem(at: url)
        }
        
        recordingTime = 0
        audioLevels = []
        
        // Haptic feedback
        let notificationFeedback = UINotificationFeedbackGenerator()
        notificationFeedback.notificationOccurred(.warning)
    }
    
    private func startTimers() {
        recordingTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
            Task { @MainActor in
                self.recordingTime += 0.1
            }
        }
        
        levelTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { _ in
            Task { @MainActor in
                self.updateAudioLevels()
            }
        }
    }
    
    private func stopTimers() {
        recordingTimer?.invalidate()
        levelTimer?.invalidate()
        recordingTimer = nil
        levelTimer = nil
    }
    
    private func updateAudioLevels() {
        guard let recorder = audioRecorder, recorder.isRecording else { return }
        
        recorder.updateMeters()
        let level = recorder.averagePower(forChannel: 0)
        
        // Convert decibels to normalized level (0-1)
        let normalizedLevel = max(0, (level + 80) / 80) // -80db to 0db range
        
        audioLevels.append(normalizedLevel)
        
        // Keep only the last 100 levels for performance
        if audioLevels.count > 100 {
            audioLevels.removeFirst()
        }
    }
}

// MARK: - AVAudioRecorderDelegate

extension VoiceMessageRecorder: AVAudioRecorderDelegate {
    nonisolated func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder, successfully flag: Bool) {
        Task { @MainActor in
            self.isRecording = false
            self.stopTimers()
        }
    }
}

// MARK: - Voice Message Recording View

struct VoiceMessageRecordingView: View {
    @StateObject private var recorder = VoiceMessageRecorder()
    @State private var scale: CGFloat = 1.0
    @State private var showingWaveform = false
    
    let onRecordingComplete: (URL) -> Void
    let onCancel: () -> Void
    
    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            
            // Waveform visualization
            if recorder.isRecording {
                WaveformView(levels: recorder.audioLevels)
                    .frame(height: 100)
                    .animation(.easeInOut(duration: 0.3), value: showingWaveform)
                    .onAppear {
                        showingWaveform = true
                    }
            } else {
                VStack(spacing: 8) {
                    Image(systemName: "mic.fill")
                        .font(.system(size: 40))
                        .foregroundStyle(.blue)
                    
                    Text("Hold to Record")
                        .font(.title2)
                        .fontWeight(.medium)
                    
                    Text("Release to send, swipe up to cancel")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            
            // Timer
            if recorder.isRecording {
                Text(formatTime(recorder.recordingTime))
                    .font(.system(.title, design: .monospaced))
                    .fontWeight(.medium)
                    .foregroundStyle(.primary)
            }
            
            Spacer()
            
            // Recording controls
            HStack(spacing: 60) {
                if recorder.isRecording {
                    // Cancel button
                    Button(action: {
                        recorder.cancelRecording()
                        onCancel()
                    }) {
                        Image(systemName: "xmark")
                            .font(.title2)
                            .foregroundStyle(.red)
                            .frame(width: 56, height: 56)
                            .background(Circle().fill(.red.opacity(0.2)))
                    }
                    .buttonStyle(PlainButtonStyle())
                    
                    // Stop and send button
                    Button(action: {
                        if let url = recorder.stopRecording() {
                            onRecordingComplete(url)
                        }
                    }) {
                        Image(systemName: "arrow.up")
                            .font(.title2)
                            .foregroundStyle(.white)
                            .frame(width: 56, height: 56)
                            .background(Circle().fill(.blue))
                    }
                    .buttonStyle(PlainButtonStyle())
                    
                } else {
                    // Record button
                    Button(action: {
                        recorder.startRecording()
                    }) {
                        Circle()
                            .fill(.red)
                            .frame(width: 80, height: 80)
                            .scaleEffect(scale)
                            .overlay(
                                Circle()
                                    .stroke(.white, lineWidth: 4)
                                    .scaleEffect(0.8)
                            )
                    }
                    .buttonStyle(PlainButtonStyle())
                    .disabled(!recorder.hasPermission)
                    .onLongPressGesture(
                        minimumDuration: 0.1,
                        perform: {
                            recorder.startRecording()
                        },
                        onPressingChanged: { pressing in
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                                scale = pressing ? 1.2 : 1.0
                            }
                        }
                    )
                }
            }
            .padding(.bottom, 40)
        }
        .padding()
        .background(.ultraThinMaterial)
        .alert("Microphone Permission Required", isPresented: .constant(!recorder.hasPermission && recorder.isRecording)) {
            Button("Settings") {
                if let settingsURL = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(settingsURL)
                }
            }
            Button("Cancel", role: .cancel) {
                onCancel()
            }
        } message: {
            Text("Please allow microphone access in Settings to record voice messages.")
        }
    }
    
    private func formatTime(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

// MARK: - Waveform View

struct WaveformView: View {
    let levels: [Float]
    @State private var animatedLevels: [Float] = []
    
    var body: some View {
        Canvas { context, size in
            let barWidth: CGFloat = 3
            let barSpacing: CGFloat = 2
            let totalBars = Int(size.width / (barWidth + barSpacing))
            
            let levelsToShow = Array(animatedLevels.suffix(totalBars))
            
            for (index, level) in levelsToShow.enumerated() {
                let x = CGFloat(index) * (barWidth + barSpacing)
                let barHeight = max(4, size.height * CGFloat(level))
                let y = (size.height - barHeight) / 2
                
                let rect = CGRect(x: x, y: y, width: barWidth, height: barHeight)
                let path = RoundedRectangle(cornerRadius: barWidth / 2).path(in: rect)
                
                // Color based on level intensity
                let color = Color.blue.opacity(0.3 + Double(level) * 0.7)
                context.fill(path, with: .color(color))
            }
        }
        .onChange(of: levels) { _, newLevels in
            withAnimation(.easeOut(duration: 0.05)) {
                animatedLevels = newLevels
            }
        }
    }
}

// MARK: - Voice Message Player

struct VoiceMessagePlayer: View {
    let audioURL: URL
    let duration: TimeInterval
    
    @State private var isPlaying = false
    @State private var currentTime: TimeInterval = 0
    @State private var player: AVPlayer?
    @State private var timeObserver: Any?
    
    var body: some View {
        HStack(spacing: 12) {
            // Play/pause button
            Button(action: togglePlayback) {
                Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                    .font(.title2)
                    .foregroundStyle(.white)
                    .frame(width: 40, height: 40)
                    .background(Circle().fill(.blue))
            }
            .buttonStyle(PlainButtonStyle())
            
            // Waveform with progress
            VStack(alignment: .leading, spacing: 4) {
                // Static waveform representation
                WaveformProgressView(progress: duration > 0 ? currentTime / duration : 0)
                    .frame(height: 30)
                
                HStack {
                    Text(formatTime(currentTime))
                        .font(.caption2)
                        .monospacedDigit()
                    
                    Spacer()
                    
                    Text(formatTime(duration))
                        .font(.caption2)
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(12)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .onAppear {
            setupPlayer()
        }
        .onDisappear {
            cleanup()
        }
    }
    
    private func setupPlayer() {
        let playerItem = AVPlayerItem(url: audioURL)
        player = AVPlayer(playerItem: playerItem)
        
        let interval = CMTime(seconds: 0.1, preferredTimescale: CMTimeScale(NSEC_PER_SEC))
        timeObserver = player?.addPeriodicTimeObserver(forInterval: interval, queue: .main) { time in
            currentTime = time.seconds
            
            // Check if playback finished
            if let duration = player?.currentItem?.duration.seconds,
               currentTime >= duration {
                isPlaying = false
                currentTime = 0
                player?.seek(to: .zero)
            }
        }
    }
    
    private func togglePlayback() {
        guard let player = player else { return }
        
        if isPlaying {
            player.pause()
        } else {
            player.play()
        }
        
        isPlaying.toggle()
        
        // Haptic feedback
        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
        impactFeedback.impactOccurred()
    }
    
    private func cleanup() {
        if let timeObserver = timeObserver {
            player?.removeTimeObserver(timeObserver)
        }
        player?.pause()
        player = nil
    }
    
    private func formatTime(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

// MARK: - Waveform Progress View

struct WaveformProgressView: View {
    let progress: Double
    
    // Static waveform pattern for consistent appearance
    private let waveformData: [Float] = [
        0.3, 0.7, 0.4, 0.8, 0.2, 0.9, 0.5, 0.6, 0.3, 0.8,
        0.4, 0.5, 0.7, 0.3, 0.9, 0.2, 0.6, 0.4, 0.8, 0.5,
        0.3, 0.7, 0.4, 0.6, 0.8, 0.2, 0.5, 0.9, 0.3, 0.7
    ]
    
    var body: some View {
        Canvas { context, size in
            let barWidth: CGFloat = 2
            let barSpacing: CGFloat = 1
            let totalBars = min(waveformData.count, Int(size.width / (barWidth + barSpacing)))
            let progressBars = Int(Double(totalBars) * progress)
            
            for index in 0..<totalBars {
                let x = CGFloat(index) * (barWidth + barSpacing)
                let level = waveformData[index]
                let barHeight = max(2, size.height * CGFloat(level) * 0.8)
                let y = (size.height - barHeight) / 2
                
                let rect = CGRect(x: x, y: y, width: barWidth, height: barHeight)
                let path = RoundedRectangle(cornerRadius: barWidth / 2).path(in: rect)
                
                // Color based on progress
                let color = index < progressBars ? Color.blue : Color.gray.opacity(0.3)
                context.fill(path, with: .color(color))
            }
        }
    }
}
#endif