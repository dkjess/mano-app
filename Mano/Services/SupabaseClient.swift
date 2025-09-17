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
    
    let client: SupabaseClient
    
    // Sub-managers for focused responsibilities
    let auth: SupabaseAuthManager
    let people: SupabasePeopleManager
    let messages: SupabaseMessagesManager
    let profile: SupabaseProfileManager
    
    // Published properties from auth manager
    @Published var isAuthenticated = false
    @Published var user: User?
    
    private var cancellables = Set<AnyCancellable>()
    
    private init() {
        print("🔷 SupabaseManager init starting...")
        print("🔷 Supabase URL: \(Config.supabaseURL)")
        print("🔷 Anon Key: \(String(Config.supabaseAnonKey.prefix(20)))...")
        
        self.client = SupabaseClient(
            supabaseURL: URL(string: Config.supabaseURL)!,
            supabaseKey: Config.supabaseAnonKey
        )
        
        print("🔷 SupabaseClient created successfully")
        
        // Initialize sub-managers
        self.auth = SupabaseAuthManager(client: client)
        self.people = SupabasePeopleManager(client: client, authManager: auth)
        self.messages = SupabaseMessagesManager(client: client, authManager: auth)
        self.profile = SupabaseProfileManager(client: client, authManager: auth)
        
        // Subscribe to auth manager changes
        auth.$isAuthenticated
            .receive(on: DispatchQueue.main)
            .assign(to: &$isAuthenticated)
        
        auth.$user
            .receive(on: DispatchQueue.main)
            .assign(to: &$user)
    }
    
    // MARK: - Convenience methods that delegate to sub-managers
    
    func signIn(email: String, password: String) async throws {
        try await auth.signIn(email: email, password: password)
    }
    
    func signOut() async throws {
        try await auth.signOut()
    }
    
    func fetchPeople() async throws -> [Person] {
        return try await people.fetchPeople()
    }
    
    func createPerson(name: String, role: String?, relationshipType: String) async throws -> Person {
        return try await people.createPerson(name: name, role: role, relationshipType: relationshipType)
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
