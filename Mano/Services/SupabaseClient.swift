//
//  SupabaseClient.swift
//  Mano
//
//  Created by Jess Wambui Olsen on 31/08/2025.
//

import Foundation
import SwiftUI
import Combine
import Supabase
import PostgREST

@MainActor
class SupabaseManager: ObservableObject {
    static let shared = SupabaseManager()

    private(set) var client: SupabaseClient

    // Sub-managers for focused responsibilities
    private(set) var auth: SupabaseAuthManager
    private(set) var people: SupabasePeopleManager
    private(set) var messages: SupabaseMessagesManager
    private(set) var profile: SupabaseProfileManager
    private(set) var conversations: SupabaseConversationManager

    // Published properties from auth manager
    @Published var isAuthenticated = false
    @Published var user: User?

    private var cancellables = Set<AnyCancellable>()
    private let environmentManager = BackendEnvironmentManager.shared

    private init() {
        print("🔷 SupabaseManager init starting...")
        let environment = environmentManager.currentEnvironment
        print("🔷 Using environment: \(environment.displayName)")
        print("🔷 Supabase URL: \(environment.supabaseURL)")
        print("🔷 Anon Key: \(String(environment.supabaseAnonKey.prefix(20)))...")

        self.client = SupabaseClient(
            supabaseURL: URL(string: environment.supabaseURL)!,
            supabaseKey: environment.supabaseAnonKey
        )

        print("🔷 SupabaseClient created successfully")

        // Initialize sub-managers
        self.auth = SupabaseAuthManager(client: client)
        self.people = SupabasePeopleManager(client: client, authManager: auth)
        self.messages = SupabaseMessagesManager(client: client, authManager: auth)
        self.profile = SupabaseProfileManager(client: client, authManager: auth)
        self.conversations = SupabaseConversationManager(client: client, authManager: auth)

        // Subscribe to auth manager changes
        auth.$isAuthenticated
            .receive(on: DispatchQueue.main)
            .assign(to: &$isAuthenticated)

        auth.$user
            .receive(on: DispatchQueue.main)
            .assign(to: &$user)
    }

    // Reinitialize with new environment
    func reinitialize(with environment: BackendEnvironment) async {
        print("🔄 Reinitializing SupabaseManager with environment: \(environment.displayName)")

        // Sign out from current session
        if isAuthenticated {
            try? await auth.signOut()
        }

        // Clear cancellables
        cancellables.removeAll()

        // Create new client with new environment
        self.client = SupabaseClient(
            supabaseURL: URL(string: environment.supabaseURL)!,
            supabaseKey: environment.supabaseAnonKey
        )

        // Reinitialize sub-managers
        self.auth = SupabaseAuthManager(client: client)
        self.people = SupabasePeopleManager(client: client, authManager: auth)
        self.messages = SupabaseMessagesManager(client: client, authManager: auth)
        self.profile = SupabaseProfileManager(client: client, authManager: auth)
        self.conversations = SupabaseConversationManager(client: client, authManager: auth)

        // Re-subscribe to auth manager changes
        auth.$isAuthenticated
            .receive(on: DispatchQueue.main)
            .assign(to: &$isAuthenticated)

        auth.$user
            .receive(on: DispatchQueue.main)
            .assign(to: &$user)

        print("✅ SupabaseManager reinitialized successfully")
    }
    
    // MARK: - Convenience methods that delegate to sub-managers

    func signOut() async throws {
        try await auth.signOut()
    }

    func deleteAccount() async throws {
        try await auth.deleteAccount()
    }

    func fetchPeople() async throws -> [Person] {
        return try await people.fetchPeople()
    }
    
    func createPerson(name: String, role: String?, relationshipType: String, startedWorkingTogether: Date? = nil) async throws -> Person {
        return try await people.createPerson(name: name, role: role, relationshipType: relationshipType, startedWorkingTogether: startedWorkingTogether)
    }
    
    func fetchMessages(for personId: UUID) async throws -> [Message] {
        return try await messages.fetchMessages(for: personId)
    }
    
    func sendMessageWithStream(_ content: String, to personId: UUID, onChunk: @escaping (String) async -> Void) async throws {
        try await messages.sendMessageWithStream(content, to: personId, onChunk: onChunk)
    }
    
    func sendMessage(_ content: String, to personId: UUID) async throws {
        try await messages.sendMessage(content, to: personId)
    }
}
