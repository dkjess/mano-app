//
//  SupabaseAuthManager.swift
//  Mano
//
//  Created by Claude on 11/09/2025.
//

import Foundation
import SwiftUI
import Combine
import Supabase
import Auth
import AuthenticationServices

@MainActor
class SupabaseAuthManager: ObservableObject {
    @Published var isAuthenticated = false
    @Published var user: User?
    @Published var isLoading = false
    @Published var errorMessage = ""

    private let client: SupabaseClient
    
    init(client: SupabaseClient) {
        self.client = client
        
        Task {
            await checkAuthState()
            await observeAuthChanges()
        }
    }
    
    private func checkAuthState() async {
        do {
            let session = try await client.auth.session
            self.user = session.user
            self.isAuthenticated = true
        } catch {
            self.user = nil
            self.isAuthenticated = false
        }
    }
    
    private func observeAuthChanges() async {
        for await state in client.auth.authStateChanges {
            self.user = state.session?.user
            self.isAuthenticated = state.session != nil
        }
    }
    
    // MARK: - Authentication Methods

    func signIn(email: String, password: String) async throws {
        isLoading = true
        errorMessage = ""

        defer {
            isLoading = false
        }

        do {
            try await client.auth.signIn(email: email, password: password)
        } catch {
            errorMessage = error.localizedDescription
            throw error
        }
    }

    func signUp(email: String, password: String) async throws {
        isLoading = true
        errorMessage = ""

        defer {
            isLoading = false
        }

        do {
            try await client.auth.signUp(email: email, password: password)
        } catch {
            errorMessage = error.localizedDescription
            throw error
        }
    }

    func signInWithApple() async throws {
        isLoading = true
        errorMessage = ""

        defer {
            isLoading = false
        }

        do {
            try await client.auth.signInWithIdToken(
                credentials: .init(
                    provider: .apple,
                    idToken: "", // Will be filled by Apple Sign In flow
                    nonce: ""
                )
            )
        } catch {
            errorMessage = error.localizedDescription
            throw error
        }
    }

    func signInWithGoogle() async throws {
        isLoading = true
        errorMessage = ""

        defer {
            isLoading = false
        }

        do {
            // This will need to be implemented with Google Sign-In SDK
            // For now, placeholder implementation
            throw NSError(domain: "AuthError", code: 0, userInfo: [NSLocalizedDescriptionKey: "Google Sign-In not yet implemented"])
        } catch {
            errorMessage = error.localizedDescription
            throw error
        }
    }

    func signOut() async throws {
        isLoading = true
        defer {
            isLoading = false
        }
        try await client.auth.signOut()
    }

    func resetPassword(email: String) async throws {
        isLoading = true
        errorMessage = ""

        defer {
            isLoading = false
        }

        do {
            try await client.auth.resetPasswordForEmail(email)
        } catch {
            errorMessage = error.localizedDescription
            throw error
        }
    }
}