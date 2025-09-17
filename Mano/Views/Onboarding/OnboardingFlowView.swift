//
//  OnboardingFlowView.swift
//  Mano
//
//  Created by Claude on 15/09/2025.
//

import SwiftUI

struct OnboardingFlowView: View {
    @State private var currentStep = 0
    @State private var preferredName = ""
    @State private var callName = ""
    @State private var jobRole = ""
    @State private var company = ""
    @State private var isLoading = false
    @State private var showError = false
    @State private var showLogoutConfirmation = false

    @ObservedObject private var profileManager = SupabaseManager.shared.profile
    @ObservedObject private var authManager = SupabaseManager.shared.auth

    private let totalSteps = 4

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Top Bar with Logout
                HStack {
                    Spacer()
                    Button(action: {
                        showLogoutConfirmation = true
                    }) {
                        Text("Log Out")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.red)
                    }
                    .padding(.trailing, 24)
                    .padding(.top, 8)
                }

                // Progress Bar
                ProgressView(value: Double(currentStep + 1), total: Double(totalSteps))
                    .progressViewStyle(LinearProgressViewStyle())
                    .padding(.horizontal, 24)
                    .padding(.top, 8)

                // Current Step View
                Group {
                    switch currentStep {
                    case 0:
                        PreferredNameStep(name: $preferredName)
                    case 1:
                        CallNameStep(callName: $callName)
                    case 2:
                        JobRoleStep(jobRole: $jobRole)
                    case 3:
                        CompanyStep(company: $company)
                    default:
                        EmptyView()
                    }
                }
                .padding(.horizontal, 24)

                Spacer()

                // Navigation Buttons
                HStack(spacing: 16) {
                    if currentStep > 0 {
                        Button("Back") {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                currentStep -= 1
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(Color(.systemGray5))
                        .foregroundColor(.primary)
                        .cornerRadius(12)
                    }

                    Button(currentStep == totalSteps - 1 ? "Complete" : "Next") {
                        handleNext()
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(canProceed && !isLoading ? Color.accentColor : Color.gray)
                    .foregroundColor(.white)
                    .cornerRadius(12)
                    .disabled(!canProceed || isLoading)
                    .overlay {
                        if isLoading && currentStep == totalSteps - 1 {
                            HStack {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    .scaleEffect(0.8)
                                Text("Saving...")
                                    .foregroundColor(.white)
                            }
                        }
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 32)
            }
            .navigationBarHidden(true)
            .alert("Error", isPresented: $showError) {
                Button("OK") { }
            } message: {
                Text(profileManager.errorMessage)
            }
            .confirmationDialog("Are you sure you want to log out?", isPresented: $showLogoutConfirmation, titleVisibility: .visible) {
                Button("Log Out", role: .destructive) {
                    Task {
                        do {
                            try await authManager.signOut()
                        } catch {
                            print("Failed to sign out: \(error)")
                        }
                    }
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("You'll need to sign in again to continue setting up your profile.")
            }
            .disabled(isLoading)
        }
    }

    private var canProceed: Bool {
        switch currentStep {
        case 0: return !preferredName.isEmpty
        case 1: return !callName.isEmpty
        case 2: return !jobRole.isEmpty
        case 3: return true // Company is optional
        default: return false
        }
    }

    private func handleNext() {
        if currentStep == totalSteps - 1 {
            // Final step - save profile and navigate to chat
            saveProfileAndComplete()
        } else {
            withAnimation(.easeInOut(duration: 0.3)) {
                currentStep += 1
            }
        }
    }

    private func saveProfileAndComplete() {
        print("🔵 [OnboardingFlow] Starting saveProfileAndComplete")
        print("🔵 [OnboardingFlow] Data to save:")
        print("   - preferredName: \(preferredName)")
        print("   - callName: \(callName)")
        print("   - jobRole: \(jobRole)")
        print("   - company: \(company)")

        isLoading = true

        Task {
            do {
                print("🔵 [OnboardingFlow] Calling updateFoundationProfile...")
                try await profileManager.updateFoundationProfile(
                    preferredName: preferredName,
                    callName: callName,
                    jobRole: jobRole,
                    company: company.isEmpty ? nil : company
                )

                print("✅ [OnboardingFlow] Profile update successful")

                await MainActor.run {
                    isLoading = false
                    print("🔵 [OnboardingFlow] Posted ProfileUpdated notification")
                    // RootView will automatically detect profile completion and transition
                }
            } catch {
                print("❌ [OnboardingFlow] Error saving profile: \(error)")
                await MainActor.run {
                    isLoading = false
                    showError = true
                }
            }
        }
    }
}

// MARK: - Individual Step Views

struct PreferredNameStep: View {
    @Binding var name: String
    @FocusState private var isTextFieldFocused: Bool

    var body: some View {
        OnboardingStepContainer(
            title: "What's your full name?",
            subtitle: "This will be used for your profile and formal settings"
        ) {
            VStack(spacing: 20) {
                TextField("Enter your full name", text: $name)
                    .font(.title2)
                    .textFieldStyle(.plain)
                    .padding(.vertical, 16)
                    .padding(.horizontal, 20)
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                    .focused($isTextFieldFocused)
                    .textInputAutocapitalization(.words)
                    .autocorrectionDisabled()

                Text("This helps maintain professionalism in shared contexts")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                isTextFieldFocused = true
            }
        }
    }
}

struct CallNameStep: View {
    @Binding var callName: String
    @FocusState private var isTextFieldFocused: Bool

    var body: some View {
        OnboardingStepContainer(
            title: "What should Mano call you?",
            subtitle: "Your preferred name - could be a nickname, first name, or however you like to be addressed"
        ) {
            VStack(spacing: 20) {
                TextField("Your preferred name", text: $callName)
                    .font(.title2)
                    .textFieldStyle(.plain)
                    .padding(.vertical, 16)
                    .padding(.horizontal, 20)
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                    .focused($isTextFieldFocused)
                    .textInputAutocapitalization(.words)
                    .autocorrectionDisabled()

                Text("Mano will use this name when talking with you")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                isTextFieldFocused = true
            }
        }
    }
}

struct JobRoleStep: View {
    @Binding var jobRole: String
    @FocusState private var isTextFieldFocused: Bool

    var body: some View {
        OnboardingStepContainer(
            title: "What's your role?",
            subtitle: "Your job title or position - this helps Mano provide relevant management advice"
        ) {
            VStack(spacing: 20) {
                TextField("Your job title", text: $jobRole)
                    .font(.title2)
                    .textFieldStyle(.plain)
                    .padding(.vertical, 16)
                    .padding(.horizontal, 20)
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                    .focused($isTextFieldFocused)
                    .textInputAutocapitalization(.words)
                    .autocorrectionDisabled()

                // Quick suggestions
                VStack(spacing: 8) {
                    Text("Common roles:")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    HStack(spacing: 8) {
                        ForEach(["Manager", "Director", "Team Lead", "VP"], id: \.self) { role in
                            Button(role) {
                                jobRole = role
                            }
                            .font(.caption)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color(.systemGray5))
                            .cornerRadius(8)
                        }
                    }
                }
            }
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                isTextFieldFocused = true
            }
        }
    }
}

struct CompanyStep: View {
    @Binding var company: String
    @FocusState private var isTextFieldFocused: Bool

    var body: some View {
        OnboardingStepContainer(
            title: "Where do you work?",
            subtitle: "Your company or organization (optional - you can skip this)"
        ) {
            VStack(spacing: 20) {
                TextField("Company name", text: $company)
                    .font(.title2)
                    .textFieldStyle(.plain)
                    .padding(.vertical, 16)
                    .padding(.horizontal, 20)
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                    .focused($isTextFieldFocused)
                    .textInputAutocapitalization(.words)
                    .autocorrectionDisabled()

                Button("Skip this step") {
                    company = ""
                }
                .font(.caption)
                .foregroundColor(.accentColor)
            }
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                isTextFieldFocused = true
            }
        }
    }
}

// MARK: - Container View

struct OnboardingStepContainer<Content: View>: View {
    let title: String
    let subtitle: String
    let content: Content

    init(title: String, subtitle: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.subtitle = subtitle
        self.content = content()
    }

    var body: some View {
        VStack(spacing: 32) {
            VStack(spacing: 12) {
                Text(title)
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .multilineTextAlignment(.center)

                Text(subtitle)
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.top, 32)

            content
        }
    }
}

#Preview {
    OnboardingFlowView()
}