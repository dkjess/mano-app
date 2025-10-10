//
//  BackendEnvironment.swift
//  Mano
//
//  Backend environment management for switching between local and production
//

import Foundation
import SwiftUI
import Combine

enum BackendEnvironment: String, CaseIterable {
    case production = "Production"
    case local = "Local (ngrok)"
    case localhost = "Local (Simulator)"

    var supabaseURL: String {
        switch self {
        case .production:
            return "https://zfroutbzdkhivnpiezho.supabase.co"
        case .local:
            // Current ngrok tunnel - update when restarted
            return "https://9453b9716e22.ngrok-free.app"
        case .localhost:
            return "http://127.0.0.1:54321"
        }
    }

    var supabaseAnonKey: String {
        switch self {
        case .production:
            return "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Inpmcm91dGJ6ZGtoaXZucGllemhvIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NDk0MTY3MTAsImV4cCI6MjA2NDk5MjcxMH0.1oPaalBGxcVx1cOu_E4k8WVJIxL2OsS45bwPrbjnBt4"
        case .local, .localhost:
            return "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZS1kZW1vIiwicm9sZSI6ImFub24iLCJleHAiOjE5ODM4MTI5OTZ9.CRXP1A7WOeoJeXxjNni43kdQwgnWNReilDMblYTn_I0"
        }
    }

    var displayName: String {
        return self.rawValue
    }

    var icon: String {
        switch self {
        case .production:
            return "cloud.fill"
        case .local:
            return "network"
        case .localhost:
            return "desktopcomputer"
        }
    }

    var description: String {
        switch self {
        case .production:
            return "Production Supabase"
        case .local:
            return "Local via ngrok tunnel"
        case .localhost:
            return "Local for Simulator"
        }
    }
}

@MainActor
class BackendEnvironmentManager: ObservableObject {
    static let shared = BackendEnvironmentManager()

    @AppStorage("selectedBackend") private var storedEnvironment: String = BackendEnvironment.production.rawValue
    @Published var currentEnvironment: BackendEnvironment

    private init() {
        // Initialize currentEnvironment first
        #if DEBUG
        // Default to local for debug builds
        self.currentEnvironment = .local
        #else
        // Default to production for release builds
        self.currentEnvironment = .production
        #endif

        // Then load stored environment if available
        if let stored = BackendEnvironment(rawValue: storedEnvironment) {
            self.currentEnvironment = stored
        }

        // Set up the publisher after initialization
        $currentEnvironment
            .dropFirst() // Skip initial value
            .sink { [weak self] environment in
                self?.storedEnvironment = environment.rawValue
                // Reinitialize Supabase with new environment
                Task {
                    await SupabaseManager.shared.reinitialize(with: environment)
                }
            }
            .store(in: &cancellables)
    }

    private var cancellables = Set<AnyCancellable>()

    func updateNgrokURL(_ url: String) {
        // This could be extended to allow custom ngrok URL input
        // For now, it requires code update
    }
}