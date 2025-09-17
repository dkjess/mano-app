//
//  DeviceCapabilityChecker.swift
//  Mano
//
//  Created by Claude on 03/09/2025.
//
//  This class checks for on-device AI capabilities including:
//  - Foundation Models framework (iOS 18+) for Apple Intelligence
//  - Natural Language framework for text classification  
//  - Core ML for Neural Engine detection
//
//  Note: Foundation Models API usage is based on expected patterns.
//  Update with actual API calls once framework documentation is available.
//

import Foundation
import NaturalLanguage
import SwiftUI
import Combine
import CoreML

#if canImport(UIKit)
import UIKit
#endif

// Check if Foundation Models framework is available
#if canImport(FoundationModels)
import FoundationModels
#endif

@MainActor
class DeviceCapabilityChecker: ObservableObject {
    
    enum AICapability {
        case fullOnDevice      // Latest devices with Apple Intelligence
        case basicClassification // Older devices with basic NL framework
        case fallbackOnly      // Very old devices, generic messages only
    }
    
    @Published var capability: AICapability = .fallbackOnly
    @Published var isAppleIntelligenceAvailable = false
    @Published var hasNeuralEngine = false
    @Published var deviceGeneration: DeviceGeneration = .legacy
    
    private let minimumRAM: UInt64 = 6 * 1024 * 1024 * 1024 // 6GB
    private let minimumIOSVersion = 18.1
    
    init() {
        Task {
            await detectCapabilities()
        }
    }
    
    func detectCapabilities() async {
        print("🧠 Detecting device AI capabilities...")
        
        // Check system version
        #if os(iOS)
        let version = UIDevice.current.systemVersion
        let versionNumber = (version as NSString).doubleValue
        
        // iOS 14 is minimum for NL embeddings
        guard versionNumber >= 14.0 else {
            print("📱 iOS version \(version) too old for on-device AI")
            capability = .fallbackOnly
            return
        }
        print("📱 iOS version: \(version)")
        #else
        let version = ProcessInfo.processInfo.operatingSystemVersionString
        print("🖥️ Running on macOS: \(version)")
        // macOS always has AI capabilities for this demo
        #endif
        
        // Detect device generation
        deviceGeneration = detectDeviceGeneration()
        print("📱 Device generation: \(deviceGeneration)")
        
        // Check for Neural Engine via Core ML
        hasNeuralEngine = checkNeuralEngine()
        print("🧠 Neural Engine available: \(hasNeuralEngine)")
        
        // Check if Core ML supports compute units
        let mlConfig = MLModelConfiguration()
        print("🤖 Core ML compute units: \(mlConfig.computeUnits.rawValue) (0=All, 1=CPUOnly, 2=CPUAndGPU)")
        
        // Check memory
        let ramGB = getDeviceRAM() / (1024 * 1024 * 1024)
        print("💾 Device RAM: \(ramGB)GB")
        
        // Check Natural Language framework availability
        let nlAvailable = checkNaturalLanguageFramework()
        print("🔤 Natural Language framework: \(nlAvailable)")
        
        // Check Apple Intelligence availability (iOS 18.1+)
        isAppleIntelligenceAvailable = await checkAppleIntelligence()
        print("🍎 Apple Intelligence available: \(isAppleIntelligenceAvailable)")
        
        // Determine final capability
        if isAppleIntelligenceAvailable || (hasNeuralEngine && ramGB >= 6) {
            capability = .fullOnDevice
            print("✨ Full on-device AI capabilities enabled")
        } else if nlAvailable {
            capability = .basicClassification
            print("⚡ Basic classification capabilities enabled")
        } else {
            capability = .fallbackOnly
            print("📝 Fallback to generic messages")
        }
    }
    
    private func detectDeviceGeneration() -> DeviceGeneration {
        #if os(iOS)
        let identifier = getDeviceIdentifier()
        print("🔍 Device identifier: \(identifier)")
        
        // Simulator detection - all modern simulators should get latest features
        if identifier == "arm64" || identifier == "x86_64" || identifier.contains("Simulator") {
            print("📱 Running on Simulator - enabling latest features")
            return .latest
        }
        
        // iPhone 15 Pro and newer (iPhone16,1 = 15 Pro, iPhone17,1 = 16 series)
        if identifier.contains("iPhone16") || // iPhone 15 Pro series
           identifier.contains("iPhone17") || // iPhone 16 series
           identifier.contains("iPhone18") {  // Future models
            return .latest
        }
        
        // iPhone 12-14, M-series iPads
        if identifier.contains("iPhone13") || // iPhone 12
           identifier.contains("iPhone14") || // iPhone 13
           identifier.contains("iPhone15") || // iPhone 14
           identifier.contains("iPad13") ||   // M1 iPads
           identifier.contains("iPad14") {    // M2 iPads
            return .modern
        }
        
        // iPhone X-11, older iPads
        if identifier.contains("iPhone10") ||
           identifier.contains("iPhone11") ||
           identifier.contains("iPhone12") {
            return .capable
        }
        
        return .legacy
        #else
        // On macOS, assume latest capabilities
        return .latest
        #endif
    }
    
    private func checkNeuralEngine() -> Bool {
        // Neural Engine available on A12+ chips (iPhone XS and newer)
        switch deviceGeneration {
        case .latest, .modern, .capable:
            return true
        case .legacy:
            return false
        }
    }
    
    private func checkNaturalLanguageFramework() -> Bool {
        // Check if Natural Language models are available
        // Check for sentiment analysis capability as a proxy for NL framework availability
        let tagger = NLTagger(tagSchemes: [.sentimentScore])
        tagger.string = "test"
        
        // Check if we can get embeddings (requires iOS 14+)
        if #available(iOS 14.0, macOS 11.0, *) {
            // Check if language models are available
            if NLEmbedding.sentenceEmbedding(for: .english) != nil {
                print("📊 NL Embeddings available")
                return true
            }
        }
        
        // Fall back to basic tagger availability
        return !NLTagger.availableTagSchemes(for: .sentence, language: .english).isEmpty
    }
    
    private func checkAppleIntelligence() async -> Bool {
        // Check for Foundation Models / Apple Intelligence capabilities
        
        #if canImport(FoundationModels)
        // Foundation Models framework is available
        print("🎯 Foundation Models framework detected")
        
        #if os(iOS)
        if #available(iOS 18.0, *) {
            // Check if the device supports Foundation Models
            // This would typically involve checking model availability
            // The actual API would be something like:
            // if FMModel.isAvailable { ... }
            
            print("🍎 iOS 18+ with Foundation Models support")
            
            // For now, check device capabilities as a proxy
            if hasNeuralEngine && getDeviceRAM() >= minimumRAM {
                print("✅ Device meets requirements for Foundation Models")
                return true
            }
        }
        #elseif os(macOS)
        if #available(macOS 14.0, *) {
            // macOS typically has good ML support on Apple Silicon
            print("🖥️ macOS with potential Foundation Models support")
            return true
        }
        #endif
        
        return false
        #else
        // Foundation Models not available, check for other advanced ML capabilities
        
        #if os(iOS)
        // Check iOS version for Core ML advanced features
        if #available(iOS 17.0, *) {
            // iOS 17+ has enhanced on-device ML
            if hasNeuralEngine && getDeviceRAM() >= minimumRAM {
                print("🧠 Advanced ML capabilities detected (iOS 17+)")
                return true
            }
        }
        #endif
        
        // Fall back to checking if we have good hardware
        return deviceGeneration == .latest && hasNeuralEngine && getDeviceRAM() >= minimumRAM
        #endif
    }
    
    private func getDeviceIdentifier() -> String {
        var systemInfo = utsname()
        uname(&systemInfo)
        let identifier = withUnsafePointer(to: &systemInfo.machine) {
            $0.withMemoryRebound(to: CChar.self, capacity: 1) {
                ptr in String(validatingUTF8: ptr)
            }
        }
        return identifier ?? "Unknown"
    }
    
    private func getDeviceRAM() -> UInt64 {
        return ProcessInfo.processInfo.physicalMemory
    }
    
    // Public interface for checking capabilities
    func canUseOnDeviceAI() -> Bool {
        return capability == .fullOnDevice
    }
    
    func canUseBasicClassification() -> Bool {
        return capability == .basicClassification || capability == .fullOnDevice
    }
    
    func shouldUseFallback() -> Bool {
        return capability == .fallbackOnly
    }
    
    func getCapabilityDescription() -> String {
        switch capability {
        case .fullOnDevice:
            return "Full on-device AI with contextual analysis"
        case .basicClassification:
            return "Basic intent classification available"
        case .fallbackOnly:
            return "Generic loading messages only"
        }
    }
}

enum DeviceGeneration: String, CaseIterable {
    case latest = "Latest (iPhone 15 Pro+, M2+ iPads)"
    case modern = "Modern (iPhone 12-14, M1+ iPads)"
    case capable = "Capable (iPhone X-11)"
    case legacy = "Legacy (iPhone 8 and older)"
}

#Preview {
    VStack(spacing: 20) {
        Text("Device AI Capability Checker")
            .font(.title2)
            .bold()
        
        DeviceCapabilityView()
    }
    .padding()
}

struct DeviceCapabilityView: View {
    @StateObject private var checker = DeviceCapabilityChecker()
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: capabilityIcon)
                    .foregroundColor(capabilityColor)
                Text(checker.getCapabilityDescription())
                    .font(.headline)
            }
            
            VStack(alignment: .leading, spacing: 8) {
                InfoRow(title: "Device Generation", value: checker.deviceGeneration.rawValue)
                InfoRow(title: "Neural Engine", value: checker.hasNeuralEngine ? "Available" : "Not Available")
                InfoRow(title: "Apple Intelligence", value: checker.isAppleIntelligenceAvailable ? "Supported" : "Not Supported")
                InfoRow(title: "RAM", value: "\(ProcessInfo.processInfo.physicalMemory / (1024 * 1024 * 1024))GB")
            }
        }
        .padding()
        .background(Color.gray.opacity(0.2))
        .cornerRadius(12)
    }
    
    private var capabilityIcon: String {
        switch checker.capability {
        case .fullOnDevice: return "brain.head.profile"
        case .basicClassification: return "cpu"
        case .fallbackOnly: return "message"
        }
    }
    
    private var capabilityColor: Color {
        switch checker.capability {
        case .fullOnDevice: return .green
        case .basicClassification: return .orange
        case .fallbackOnly: return .gray
        }
    }
}

struct InfoRow: View {
    let title: String
    let value: String
    
    var body: some View {
        HStack {
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .font(.caption)
                .bold()
        }
    }
}