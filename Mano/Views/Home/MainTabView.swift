//
//  MainTabView.swift
//  Mano
//
//  Created by Claude on 13/10/2025.
//

import SwiftUI

@available(iOS 26.0, *)
struct MainTabView: View {
    @State private var selectedTab = 0
    @State private var showEnvironmentPicker = false
    @State private var showingDeleteAccountConfirmation = false
    @ObservedObject private var supabase = SupabaseManager.shared
    @ObservedObject private var environmentManager = BackendEnvironmentManager.shared

    var body: some View {
        ZStack(alignment: .bottom) {
            // Main content
            Group {
                switch selectedTab {
                case 0:
                    ManoHomeView()
                case 1:
                    NavigationStack {
                        PinnedView()
                    }
                case 2:
                    NavigationStack {
                        OKRsView()
                    }
                default:
                    ManoHomeView()
                }
            }

            // Custom tab bar with settings button
            HStack(spacing: 0) {
                // Left-aligned tabs
                HStack(spacing: 8) {
                    TabButton(
                        title: "People",
                        icon: "person.fill",
                        isSelected: selectedTab == 0,
                        action: { selectedTab = 0 }
                    )

                    TabButton(
                        title: "Pins",
                        icon: "pin.fill",
                        isSelected: selectedTab == 1,
                        action: { selectedTab = 1 }
                    )

                    TabButton(
                        title: "OKRs",
                        icon: "target",
                        isSelected: selectedTab == 2,
                        action: { selectedTab = 2 }
                    )
                }
                .padding(.leading, 20)

                Spacer()

                // Settings button on the right
                Menu {
                    if environmentManager.currentEnvironment == .local {
                        Button(action: { showEnvironmentPicker = true }) {
                            Label("Switch Environment", systemImage: "network")
                        }
                        Divider()
                    }

                    Button(role: .destructive, action: {
                        showingDeleteAccountConfirmation = true
                    }) {
                        Label("Delete Account", systemImage: "trash")
                    }

                    Button(action: {
                        Task {
                            try? await supabase.auth.signOut()
                        }
                    }) {
                        Label("Sign Out", systemImage: "rectangle.portrait.and.arrow.right")
                    }
                } label: {
                    Image(systemName: "gearshape.fill")
                        .font(.system(size: 20))
                        .foregroundColor(.secondaryText)
                        .frame(width: 44, height: 44)
                }
                .padding(.trailing, 20)
            }
            .frame(height: 60)
            .background(Color.white)
            .overlay(
                Rectangle()
                    .frame(height: 0.5)
                    .foregroundColor(Color.stone),
                alignment: .top
            )
        }
        .ignoresSafeArea(.keyboard)
        .sheet(isPresented: $showEnvironmentPicker) {
            EnvironmentPickerView()
        }
        .alert("Delete Account", isPresented: $showingDeleteAccountConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Delete Account", role: .destructive) {
                Task {
                    await deleteAccount()
                }
            }
        } message: {
            Text("Are you sure you want to permanently delete your account? This will remove all your data, conversations, and people. This action cannot be undone.")
        }
    }

    private func deleteAccount() async {
        print("🗑️ MainTabView: Starting account deletion")
        do {
            try await supabase.deleteAccount()
            print("✅ MainTabView: Account deletion succeeded")
        } catch {
            print("❌ MainTabView: Failed to delete account: \(error)")
        }
    }
}

// MARK: - Tab Button Component

struct TabButton: View {
    let title: String
    let icon: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .semibold))
                Text(title)
                    .font(.system(size: 15, weight: .semibold))
            }
            .foregroundColor(isSelected ? .primaryText : .secondaryText)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(
                isSelected ? Color.almostWhite : Color.clear
            )
            .cornerRadius(20)
        }
        .buttonStyle(.plain)
    }
}

@available(iOS 26.0, *)
#Preview {
    MainTabView()
}
