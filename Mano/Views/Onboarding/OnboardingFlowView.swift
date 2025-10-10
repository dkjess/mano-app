//
//  OnboardingFlowView.swift
//  Mano
//
//  Created by Claude on 15/09/2025.
//

import SwiftUI

struct OnboardingFlowView: View {
    @State private var currentStep = 0
    @State private var callName = ""
    @State private var jobRole = ""
    @State private var experienceLevel = ""
    @State private var tonePreference = ""
    @State private var isLoading = false
    @State private var showError = false
    @State private var showLogoutConfirmation = false

    @ObservedObject private var profileManager = SupabaseManager.shared.profile
    @ObservedObject private var authManager = SupabaseManager.shared.auth

    private let totalSteps = 3

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
                        NameStep(callName: $callName)
                            .padding(.horizontal, 24)
                    case 1:
                        RoleExperienceStep(jobRole: $jobRole, experienceLevel: $experienceLevel, callName: $callName)
                    case 2:
                        TonePreferenceStep(tonePreference: $tonePreference)
                    default:
                        EmptyView()
                    }
                }

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
                        #if os(iOS)
                        .background(Color(.systemGray5))
                        #else
                        .background(Color(NSColor.controlBackgroundColor))
                        #endif
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
            #if os(iOS)
            .navigationBarHidden(true)
            #else
            .toolbar(.hidden, for: .windowToolbar)
            #endif
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
        case 0: return !callName.isEmpty
        case 1: return !jobRole.isEmpty && !experienceLevel.isEmpty
        case 2: return !tonePreference.isEmpty
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
        print("   - callName: \(callName)")
        print("   - jobRole: \(jobRole)")
        print("   - experienceLevel: \(experienceLevel)")
        print("   - tonePreference: \(tonePreference)")

        isLoading = true

        Task {
            do {
                print("🔵 [OnboardingFlow] Calling updateFoundationProfile...")

                try await profileManager.updateFoundationProfile(
                    callName: callName,
                    jobRole: jobRole,
                    experienceLevel: experienceLevel,
                    communicationStyle: "", // Empty string - backend will skip if empty
                    tonePreference: tonePreference,
                    onboardingStep: 3
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

// Step 0: Welcome
struct WelcomeStep: View {
    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            VStack(spacing: 20) {
                Text("👋")
                    .font(.system(size: 80))

                Text("Welcome to Mano")
                    .font(.largeTitle)
                    .fontWeight(.bold)

                Text("Your thinking partner for managing people and teams.")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)

                Text("Mano helps you work through challenges, prepare for conversations, and become the manager you want to be.")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.top, 8)

                Text("Let's get to know you—this will take 2 minutes.")
                    .font(.callout)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.top, 16)
            }
            .padding(.horizontal)

            Spacer()
        }
    }
}

// Step 1: Name
struct NameStep: View {
    @Binding var callName: String
    @FocusState private var isTextFieldFocused: Bool

    var body: some View {
        OnboardingStepContainer(
            title: "What should I call you?",
            subtitle: "This is how I'll address you in our conversations. You can always change this later in settings."
        ) {
            VStack(spacing: 20) {
                TextField("Your name", text: $callName)
                    .font(.title2)
                    .textFieldStyle(.plain)
                    .padding(.vertical, 16)
                    .padding(.horizontal, 20)
                    #if os(iOS)
                    .background(Color(.systemGray6))
                    #else
                    .background(Color(NSColor.controlBackgroundColor))
                    #endif
                    .cornerRadius(12)
                    .focused($isTextFieldFocused)
                    #if os(iOS)
                    .textInputAutocapitalization(.words)
                    #endif
                    .autocorrectionDisabled()
            }
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                isTextFieldFocused = true
            }
        }
    }
}

// Step 2: Role + Experience
struct RoleExperienceStep: View {
    @Binding var jobRole: String
    @Binding var experienceLevel: String
    @Binding var callName: String
    @FocusState private var isTextFieldFocused: Bool

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                VStack(spacing: 12) {
                    Text(callName.isEmpty ? "Tell me about your role" : "Okay \(callName), tell me about your role")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .multilineTextAlignment(.center)
                }
                .padding(.top, 32)

                VStack(alignment: .leading, spacing: 12) {
                    Text("Job Title")
                        .font(.subheadline)
                        .foregroundColor(.secondary)

                    TextField("e.g., Engineering Manager", text: $jobRole)
                        .font(.body)
                        .textFieldStyle(.plain)
                        .padding(.vertical, 16)
                        .padding(.horizontal, 20)
                        #if os(iOS)
                        .background(Color(.systemGray6))
                        #else
                        .background(Color(NSColor.controlBackgroundColor))
                        #endif
                        .cornerRadius(12)
                        .focused($isTextFieldFocused)
                        #if os(iOS)
                        .textInputAutocapitalization(.words)
                        #endif
                        .autocorrectionDisabled()

                    // Quick picks
                    HStack(spacing: 8) {
                        ForEach(["Engineering Manager", "Team Lead", "Director", "VP"], id: \.self) { role in
                            Button(role) {
                                jobRole = role
                            }
                            .font(.caption)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            #if os(iOS)
                            .background(Color(.systemGray5))
                            #else
                            .background(Color(NSColor.controlBackgroundColor))
                            #endif
                            .foregroundColor(.primary)
                            .cornerRadius(8)
                        }
                    }
                }

                VStack(alignment: .leading, spacing: 12) {
                    Text("How long have you been managing people?")
                        .font(.subheadline)
                        .foregroundColor(.secondary)

                    VStack(spacing: 8) {
                        ExperienceButton(title: "New to management (< 1 year)", value: "new", selectedValue: $experienceLevel)
                        ExperienceButton(title: "Getting experienced (1-5 years)", value: "experienced", selectedValue: $experienceLevel)
                        ExperienceButton(title: "Veteran manager (5+ years)", value: "veteran", selectedValue: $experienceLevel)
                    }
                }
            }
            .padding(.horizontal, 24)
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                isTextFieldFocused = true
            }
        }
    }
}

struct ExperienceButton: View {
    let title: String
    let value: String
    @Binding var selectedValue: String

    var body: some View {
        Button(action: {
            selectedValue = value
        }) {
            HStack {
                Image(systemName: selectedValue == value ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(selectedValue == value ? .accentColor : .secondary)
                Text(title)
                    .foregroundColor(.primary)
                Spacer()
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 16)
            #if os(iOS)
            .background(selectedValue == value ? Color.accentColor.opacity(0.1) : Color(.systemGray6))
            #else
            .background(selectedValue == value ? Color.accentColor.opacity(0.1) : Color(NSColor.controlBackgroundColor))
            #endif
            .cornerRadius(12)
        }
    }
}

// Step 2: Communication Style
struct CommunicationStyleStep: View {
    @Binding var communicationStyle: String

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                VStack(spacing: 12) {
                    Text("How do you prefer to work through challenges?")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .multilineTextAlignment(.center)
                }
                .padding(.top, 32)

                VStack(spacing: 12) {
                    StyleCard(
                        icon: "💭",
                        title: "Think out loud",
                        description: "I process by talking through ideas and exploring possibilities",
                        value: "think_aloud",
                        selectedValue: $communicationStyle
                    )

                    StyleCard(
                        icon: "📝",
                        title: "Write it out",
                        description: "I need to see things written down to organize my thoughts",
                        value: "write_it_out",
                        selectedValue: $communicationStyle
                    )

                    StyleCard(
                        icon: "🎯",
                        title: "Cut to the chase",
                        description: "Give me the key insights and action items—let's move fast",
                        value: "action_oriented",
                        selectedValue: $communicationStyle
                    )

                    StyleCard(
                        icon: "🔄",
                        title: "Explore options",
                        description: "I like considering multiple angles before deciding on a path",
                        value: "explore_options",
                        selectedValue: $communicationStyle
                    )
                }
            }
            .padding(.horizontal, 24)
        }
    }
}

struct StyleCard: View {
    let icon: String
    let title: String
    let description: String
    let value: String
    @Binding var selectedValue: String

    var isSelected: Bool {
        selectedValue == value
    }

    var body: some View {
        Button(action: {
            selectedValue = value
        }) {
            HStack(alignment: .top, spacing: 12) {
                Text(icon)
                    .font(.title)

                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.headline)
                        .foregroundColor(.primary)
                    Text(description)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.leading)
                }

                Spacer()

                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(isSelected ? .accentColor : .secondary)
            }
            .padding(16)
            #if os(iOS)
            .background(isSelected ? Color.accentColor.opacity(0.1) : Color(.systemGray6))
            #else
            .background(isSelected ? Color.accentColor.opacity(0.1) : Color(NSColor.controlBackgroundColor))
            #endif
            .cornerRadius(12)
        }
    }
}

// Step 3: Tone Preference
struct TonePreferenceStep: View {
    @Binding var tonePreference: String

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                VStack(spacing: 12) {
                    Text("Pick your favorite response")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .multilineTextAlignment(.center)
                }
                .padding(.top, 32)

                VStack(alignment: .trailing, spacing: 12) {
                    HStack {
                        Spacer()
                        Text("I'm struggling with giving tough feedback to a team member.")
                            .font(.body)
                            .foregroundColor(.white)
                            .multilineTextAlignment(.leading)
                            .padding(16)
                            .background(Color.accentColor)
                            .cornerRadius(20)
                            #if os(iOS)
                            .frame(maxWidth: UIScreen.main.bounds.width * 0.8, alignment: .trailing)
                            #else
                            .frame(maxWidth: 600, alignment: .trailing)
                            #endif
                    }
                }

                VStack(spacing: 12) {
                    ToneCard(
                        response: "Tough feedback isn't optional when you're a manager. What's stopping you from being clear about what needs to change?",
                        value: "direct",
                        selectedValue: $tonePreference
                    )

                    ToneCard(
                        response: "That's really common—giving critical feedback feels vulnerable! What would make it easier for you to have that conversation?",
                        value: "warm",
                        selectedValue: $tonePreference
                    )

                    ToneCard(
                        response: "Oof, yeah, nobody loves that part! What's the feedback you're sitting on right now?",
                        value: "conversational",
                        selectedValue: $tonePreference
                    )

                    ToneCard(
                        response: "Let's break this down. What specific behavior needs to change, and what outcome are you aiming for?",
                        value: "analytical",
                        selectedValue: $tonePreference
                    )
                }
            }
            .padding(.horizontal, 24)
        }
    }
}

struct ToneCard: View {
    let response: String
    let value: String
    @Binding var selectedValue: String

    var isSelected: Bool {
        selectedValue == value
    }

    var body: some View {
        HStack {
            Button(action: {
                selectedValue = value
            }) {
                HStack(alignment: .top, spacing: 12) {
                    Text(response)
                        .font(.body)
                        .foregroundColor(.primary)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .foregroundColor(isSelected ? .accentColor : .secondary)
                        .font(.title3)
                }
                .padding(16)
                #if os(iOS)
                .background(isSelected ? Color.accentColor.opacity(0.1) : Color(.systemGray6))
                #else
                .background(isSelected ? Color.accentColor.opacity(0.1) : Color(NSColor.controlBackgroundColor))
                #endif
                .cornerRadius(20)
            }
            #if os(iOS)
            .frame(maxWidth: UIScreen.main.bounds.width * 0.8, alignment: .leading)
            #else
            .frame(maxWidth: 600, alignment: .leading)
            #endif

            Spacer()
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