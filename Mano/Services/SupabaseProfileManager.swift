//
//  SupabaseProfileManager.swift
//  Mano
//
//  Created by Claude on 15/09/2025.
//

import Foundation
import Combine
import Supabase

@MainActor
final class SupabaseProfileManager: ObservableObject {
    @Published var isLoading = false
    @Published var errorMessage = ""

    private let profileService: ProfileService
    private let client: SupabaseClient

    init(client: SupabaseClient, authManager: SupabaseAuthManager) {
        self.client = client
        self.profileService = ProfileService(client: client, authManager: authManager)
    }

    // MARK: - Foundation Profile

    func updateFoundationProfile(
        preferredName: String,
        callName: String,
        jobRole: String,
        company: String?
    ) async throws {
        print("🟣 [ProfileManager] updateFoundationProfile called")
        print("   - preferredName: \(preferredName)")
        print("   - callName: \(callName)")
        print("   - jobRole: \(jobRole)")
        print("   - company: \(company ?? "nil")")

        isLoading = true
        errorMessage = ""

        do {
            let session = try await client.auth.session
            print("🟣 [ProfileManager] Got session for user: \(session.user.id)")

            let requestBody: [String: Any] = [
                "preferred_name": preferredName,
                "call_name": callName,
                "job_role": jobRole,
                "company": company ?? ""
            ]

            let jsonData = try JSONSerialization.data(withJSONObject: requestBody)

            let supabaseURL = BackendEnvironmentManager.shared.currentEnvironment.supabaseURL
            let supabaseAnonKey = BackendEnvironmentManager.shared.currentEnvironment.supabaseAnonKey

            var request = URLRequest(url: URL(string: "\(supabaseURL)/functions/v1/user-profile-foundation")!)
            request.httpMethod = "PUT"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.setValue("Bearer \(session.accessToken)", forHTTPHeaderField: "Authorization")
            request.setValue(supabaseAnonKey, forHTTPHeaderField: "apikey")
            request.httpBody = jsonData

            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw NSError(domain: "ProfileError", code: 0, userInfo: [NSLocalizedDescriptionKey: "Invalid response"])
            }

            print("🟣 [ProfileManager] Response status: \(httpResponse.statusCode)")

            guard httpResponse.statusCode == 200 else {
                let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
                print("❌ [ProfileManager] Error response: \(errorMessage)")
                throw NSError(
                    domain: "ProfileError",
                    code: httpResponse.statusCode,
                    userInfo: [NSLocalizedDescriptionKey: "Failed to update profile: \(errorMessage)"]
                )
            }

            let responseString = String(data: data, encoding: .utf8) ?? ""
            print("✅ [ProfileManager] Success response: \(responseString)")

            // Notify that profile has been updated
            print("🟣 [ProfileManager] Posting ProfileUpdated notification")
            NotificationCenter.default.post(name: NSNotification.Name("ProfileUpdated"), object: nil)

        } catch {
            errorMessage = error.localizedDescription
            throw error
        }

        isLoading = false
    }

    func fetchUserProfile() async throws -> UserProfile? {
        return try await profileService.fetchUserProfile()
    }

    func isOnboardingComplete() async -> Bool {
        return await profileService.isOnboardingComplete()
    }

    func needsFoundationProfile() async -> Bool {
        return await profileService.needsFoundationProfile()
    }
}
