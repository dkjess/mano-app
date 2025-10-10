//
//  WelcomeView.swift
//  Mano
//
//  Created by Jess Wambui Olsen on 31/08/2025.
//

import SwiftUI

struct WelcomeView: View {
    @ObservedObject private var authManager = SupabaseManager.shared.auth
    @ObservedObject private var environmentManager = BackendEnvironmentManager.shared

    @State private var email = ""
    @State private var linkSent = false
    @State private var showError = false
    @State private var showEnvironmentPicker = false

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                // Environment indicator at top (only in non-production)
                if environmentManager.currentEnvironment != .production {
                    HStack {
                        Spacer()
                        Button(action: { showEnvironmentPicker.toggle() }) {
                            HStack(spacing: 4) {
                                Image(systemName: environmentManager.currentEnvironment.icon)
                                    .font(.caption)
                                Text(environmentManager.currentEnvironment.displayName)
                                    .font(.caption)
                                    .fontWeight(.medium)
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Capsule().fill(Color.orange.opacity(0.1)))
                            .foregroundColor(.orange)
                        }
                    }
                    .padding(.horizontal)
                    .padding(.top, 8)
                }

                Spacer()
                    .frame(height: 60)

                // Main content
                VStack(spacing: 32) {
                    // Hero section
                    VStack(spacing: 16) {
                        Text("👋")
                            .font(.system(size: 80))

                        Text("Welcome to Mano")
                            .font(.largeTitle)
                            .fontWeight(.bold)

                        Text("Your AI-powered companion for better management")
                            .font(.title3)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 32)
                    }

                    // Email form section
                    if !linkSent {
                        VStack(spacing: 16) {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Get started")
                                    .font(.headline)
                                    .foregroundStyle(.secondary)

                                TextField("Enter your email", text: $email)
                                    .textInputAutocapitalization(.never)
                                    .autocorrectionDisabled()
                                    .keyboardType(.emailAddress)
                                    .textContentType(.emailAddress)
                                    .padding(16)
                                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                                    )
                            }
                            .padding(.horizontal, 32)

                            Button(action: sendMagicLink) {
                                HStack(spacing: 8) {
                                    if authManager.isLoading {
                                        ProgressView()
                                            .progressViewStyle(CircularProgressViewStyle())
                                            .tint(.white)
                                    }
                                    Text(authManager.isLoading ? "Sending link..." : "Continue with Email")
                                        .fontWeight(.semibold)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(canSend ? Color.blue : Color.gray.opacity(0.5))
                                .foregroundStyle(.white)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                            }
                            .disabled(!canSend)
                            .padding(.horizontal, 32)

                            Text("No password needed • Sign in with a magic link")
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                                .multilineTextAlignment(.center)
                        }
                        .transition(.opacity.combined(with: .move(edge: .top)))
                    } else {
                        // Success state
                        VStack(spacing: 20) {
                            Image(systemName: "envelope.badge.fill")
                                .font(.system(size: 60))
                                .foregroundStyle(.blue)

                            VStack(spacing: 8) {
                                Text("Check your email")
                                    .font(.title2)
                                    .fontWeight(.bold)

                                Text("We sent a sign-in link to")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)

                                Text(email)
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                    .foregroundStyle(.primary)
                            }
                            .multilineTextAlignment(.center)

                            VStack(spacing: 12) {
                                Text("Tap the link in your email to sign in")
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                                    .multilineTextAlignment(.center)

                                Button(action: { withAnimation { linkSent = false } }) {
                                    Text("Didn't receive it? Send again")
                                        .font(.footnote)
                                        .foregroundStyle(.blue)
                                }
                            }
                            .padding(.top, 8)
                        }
                        .padding(.horizontal, 32)
                        .transition(.opacity.combined(with: .scale))
                    }
                }

                Spacer()
                    .frame(height: 80)

                // Footer links
                VStack(spacing: 16) {
                    Divider()
                        .padding(.horizontal, 32)

                    HStack(spacing: 20) {
                        Link("Privacy Policy", destination: URL(string: "https://supermano.ai/privacy")!)
                            .font(.footnote)
                            .foregroundStyle(.secondary)

                        Text("•")
                            .foregroundStyle(.tertiary)

                        Link("Terms of Service", destination: URL(string: "https://supermano.ai/terms")!)
                            .font(.footnote)
                            .foregroundStyle(.secondary)

                        Text("•")
                            .foregroundStyle(.tertiary)

                        Link("Support", destination: URL(string: "https://supermano.ai/support")!)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.bottom, 20)
                }
            }
        }
        .alert("Error", isPresented: $showError) {
            Button("OK") { }
        } message: {
            Text(authManager.errorMessage)
        }
        .sheet(isPresented: $showEnvironmentPicker) {
            EnvironmentPickerView()
        }
        .onChange(of: authManager.errorMessage) { _, newValue in
            if !newValue.isEmpty {
                showError = true
            }
        }
    }

    private var canSend: Bool {
        !email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        email.contains("@") &&
        email.contains(".") &&
        !authManager.isLoading
    }

    private func sendMagicLink() {
        let trimmedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        Task {
            do {
                try await authManager.signInWithMagicLink(email: trimmedEmail)
                await MainActor.run {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                        linkSent = true
                    }
                }
            } catch {
                // Error is already set in authManager
                print("❌ Failed to send magic link: \(error)")
            }
        }
    }
}

struct EnvironmentPickerView: View {
    @ObservedObject private var environmentManager = BackendEnvironmentManager.shared
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(BackendEnvironment.allCases, id: \.self) { environment in
                        HStack {
                            Image(systemName: environment.icon)
                                .foregroundColor(environment == .production ? .green : .orange)
                                .frame(width: 30)

                            VStack(alignment: .leading, spacing: 4) {
                                Text(environment.displayName)
                                    .fontWeight(.medium)
                                Text(environment.description)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }

                            Spacer()

                            if environmentManager.currentEnvironment == environment {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.blue)
                            }
                        }
                        .contentShape(Rectangle())
                        .onTapGesture {
                            environmentManager.currentEnvironment = environment
                            dismiss()
                        }
                    }
                } header: {
                    Text("Select Backend Environment")
                } footer: {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Current URL:")
                            .font(.caption)
                            .fontWeight(.medium)
                        Text(environmentManager.currentEnvironment.supabaseURL)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                            .textSelection(.enabled)
                    }
                    .padding(.top, 8)
                }
            }
            .navigationTitle("Backend Environment")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                #if os(iOS)
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
                #else
                ToolbarItem(placement: .automatic) {
                    Button("Done") {
                        dismiss()
                    }
                }
                #endif
            }
        }
    }
}

#Preview {
    WelcomeView()
}
