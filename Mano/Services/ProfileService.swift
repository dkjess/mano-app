//
//  ProfileService.swift
//  Mano
//
//  Created by Claude on 16/09/2025.
//

import Foundation
import Supabase

final class ProfileService {
    private let client: SupabaseClient
    private let authManager: SupabaseAuthManager

    init(client: SupabaseClient, authManager: SupabaseAuthManager) {
        self.client = client
        self.authManager = authManager
    }

    func fetchUserProfile() async throws -> UserProfile? {
        print("[ProfileService] fetchUserProfile called")
        guard let user = await authManager.user else {
            print("[ProfileService] No authenticated user")
            throw NSError(
                domain: "AuthError",
                code: 0,
                userInfo: [NSLocalizedDescriptionKey: "No authenticated user"]
            )
        }

        print("[ProfileService] Fetching profile for user: \(user.id)")

        let data = try await client
            .from("user_profiles")
            .select()
            .eq("user_id", value: user.id)
            .execute()
            .data

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let response = try decoder.decode([UserProfile].self, from: data)

        if let profile = response.first {
            print("[ProfileService] Profile found:")
            print("  onboardingCompleted: \(profile.onboardingCompleted ?? false)")
            print("  onboardingStep: \(profile.onboardingStep ?? -1)")
            print("  preferredName: \(profile.preferredName ?? "none")")
            print("  callName: \(profile.callName ?? "none")")
        } else {
            print("[ProfileService] No profile found")
        }

        return response.first
    }

    func isOnboardingComplete() async -> Bool {
        do {
            let profile = try await fetchUserProfile()
            return profile?.onboardingCompleted ?? false
        } catch {
            return false
        }
    }

    func needsFoundationProfile() async -> Bool {
        print("[ProfileService] needsFoundationProfile called")
        do {
            let profile = try await fetchUserProfile()
            guard let profile = profile else {
                print("[ProfileService] No profile found, needs foundation")
                return true
            }

            // Check if onboarding is completed
            print("[ProfileService] Checking onboardingCompleted: \(profile.onboardingCompleted ?? false)")
            if profile.onboardingCompleted == true {
                print("[ProfileService] Onboarding is complete, no need for foundation profile")
                return false // Onboarding is complete, no need for foundation profile
            }

            // Otherwise check if foundation fields are complete
            let hasPreferredName = !(profile.preferredName?.isEmpty ?? true)
            let hasCallName = !(profile.callName?.isEmpty ?? true)
            let hasJobRole = !(profile.jobRole?.isEmpty ?? true)

            print("[ProfileService] Field check:")
            print("  hasPreferredName: \(hasPreferredName)")
            print("  hasCallName: \(hasCallName)")
            print("  hasJobRole: \(hasJobRole)")

            let needsProfile = !hasPreferredName || !hasCallName || !hasJobRole
            print("[ProfileService] needsFoundationProfile result: \(needsProfile)")
            return needsProfile
        } catch {
            print("[ProfileService] Error in needsFoundationProfile: \(error)")
            return true
        }
    }
}
