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

    func signInWithMagicLink(email: String) async throws {
        print("📧 Sending magic link to: \(email)")
        isLoading = true
        errorMessage = ""

        defer {
            isLoading = false
        }

        do {
            try await client.auth.signInWithOTP(
                email: email,
                redirectTo: URL(string: "mano://login-callback")
            )
            print("✅ Magic link sent successfully to \(email)")
        } catch {
            print("❌ Failed to send magic link: \(error)")
            errorMessage = error.localizedDescription
            throw error
        }
    }

    func handleDeepLink(url: URL) async throws {
        print("🔗 Handling deep link: \(url)")
        isLoading = true
        errorMessage = ""

        defer {
            isLoading = false
        }

        do {
            // Supabase SDK handles the session extraction from URL
            try await client.auth.session(from: url)
            print("✅ Session created from magic link")
        } catch {
            print("❌ Failed to handle deep link: \(error)")
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

    func deleteAccount() async throws {
        isLoading = true
        errorMessage = ""

        defer {
            isLoading = false
        }

        do {
            // Verify user is authenticated
            guard user != nil else {
                throw NSError(domain: "AuthError", code: 0, userInfo: [NSLocalizedDescriptionKey: "No user logged in"])
            }

            // Call Edge Function to delete account (has service role permissions)
            try await client.functions.invoke(
                "delete-account",
                options: .init(
                    method: .delete
                )
            )

            // Sign out after successful deletion
            try await signOut()
        } catch {
            errorMessage = error.localizedDescription
            throw error
        }
    }
}