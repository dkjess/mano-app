//
//  ManoApp.swift
//  Mano
//
//  Created by Jess Wambui Olsen on 31/08/2025.
//

import SwiftUI
import Combine

@main
struct ManoApp: App {
    init() {
        print("🚀 ManoApp initializing...")
    }
    
    var body: some Scene {
        WindowGroup {
            RootView()
                .onAppear {
                    print("🎯 RootView appeared")
                }
        }
    }
}

struct RootView: View {
    @ObservedObject private var supabase = SupabaseManager.shared
    @State private var needsFoundationProfile = false
    @State private var isCheckingProfile = true

    init() {
        print("🔧 RootView initializing...")
        print("🔧 SupabaseManager.shared = \(SupabaseManager.shared)")
    }

    var body: some View {
        Group {
            if !supabase.isAuthenticated {
                WelcomeView()
            } else if isCheckingProfile {
                // Show loading while checking profile status
                VStack(spacing: 20) {
                    ProgressView()
                    Text("Setting up your profile...")
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(.systemBackground))
            } else if needsFoundationProfile {
                OnboardingFlowView()
            } else {
                ManoHomeView()
            }
        }
        .onAppear {
            print("📱 RootView body rendered")
            print("📱 isAuthenticated: \(supabase.isAuthenticated)")
        }
        .onChange(of: supabase.isAuthenticated) { isAuthenticated in
            if isAuthenticated {
                Task {
                    await checkProfileStatus()
                }
            } else {
                // Reset state when user logs out
                isCheckingProfile = false
                needsFoundationProfile = false
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("ProfileUpdated"))) { _ in
            print("🔴 [RootView] Received ProfileUpdated notification")
            // Re-check profile status when profile is updated
            Task {
                await checkProfileStatus()
            }
        }
        .task {
            if supabase.isAuthenticated {
                await checkProfileStatus()
            }
        }
    }

    private func checkProfileStatus() async {
        print("🔴 [RootView] checkProfileStatus called")
        isCheckingProfile = true

        do {
            print("🔴 [RootView] Calling needsFoundationProfile...")
            let needsProfile = await supabase.profile.needsFoundationProfile()
            print("🔴 [RootView] needsFoundationProfile returned: \(needsProfile)")

            await MainActor.run {
                needsFoundationProfile = needsProfile
                isCheckingProfile = false
                print("🔴 [RootView] Updated state:")
                print("   - needsFoundationProfile: \(needsFoundationProfile)")
                print("   - isCheckingProfile: \(isCheckingProfile)")
            }
        } catch {
            print("❌ [RootView] Error checking profile status: \(error)")
            await MainActor.run {
                // On error, assume they need to complete profile
                needsFoundationProfile = true
                isCheckingProfile = false
            }
        }
    }
}
