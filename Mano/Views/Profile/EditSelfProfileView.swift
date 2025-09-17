//
//  EditSelfProfileView.swift
//  Mano
//
//  Created by Claude on 15/09/2025.
//

import SwiftUI

struct EditSelfProfileView: View {
    let person: Person
    let onProfileUpdated: (Person) -> Void
    let onCancel: () -> Void

    @State private var preferredName: String
    @State private var callName: String
    @State private var jobRole: String
    @State private var company: String
    @State private var isUpdating = false
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var userProfile: UserProfile?

    @FocusState private var isNameFocused: Bool
    @ObservedObject private var profileManager = SupabaseManager.shared.profile
    @ObservedObject private var supabase = SupabaseManager.shared

    init(person: Person, onProfileUpdated: @escaping (Person) -> Void, onCancel: @escaping () -> Void) {
        self.person = person
        self.onProfileUpdated = onProfileUpdated
        self.onCancel = onCancel

        // Initialize with person data as fallback
        _preferredName = State(initialValue: person.name)
        _callName = State(initialValue: person.name)
        _jobRole = State(initialValue: person.role ?? "")
        _company = State(initialValue: person.team ?? "")
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Foundation Profile") {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Preferred Name")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        TextField("What should we call you?", text: $preferredName)
                            .focused($isNameFocused)
                            .textInputAutocapitalization(.words)
                            .autocorrectionDisabled()
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Call Name")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        TextField("What do people call you day-to-day?", text: $callName)
                            .textInputAutocapitalization(.words)
                            .autocorrectionDisabled()
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Job Role")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        TextField("Your job title", text: $jobRole)
                            .textInputAutocapitalization(.words)
                            .autocorrectionDisabled()
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Company (Optional)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        TextField("Where do you work?", text: $company)
                            .textInputAutocapitalization(.words)
                            .autocorrectionDisabled()
                    }
                }

                Section {
                    Text("This is your personal profile. Changes here will update how you appear throughout the app and in conversations.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .navigationTitle("Edit Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        onCancel()
                    }
                    .disabled(isUpdating)
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        Task {
                            await updateProfile()
                        }
                    }
                    .disabled(!isFormValid || isUpdating)
                    .overlay {
                        if isUpdating {
                            ProgressView()
                                .scaleEffect(0.8)
                        }
                    }
                }
            }
            .alert("Error", isPresented: $showError) {
                Button("OK") { }
            } message: {
                Text(errorMessage)
            }
            .task {
                await loadUserProfile()
            }
        }
    }

    private var isFormValid: Bool {
        !preferredName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !callName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !jobRole.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func loadUserProfile() async {
        do {
            userProfile = try await profileManager.fetchUserProfile()

            // Update form with actual user profile data
            await MainActor.run {
                if let profile = userProfile {
                    preferredName = profile.preferredName ?? person.name
                    callName = profile.callName ?? person.name
                    jobRole = profile.jobRole ?? person.role ?? ""
                    company = profile.company ?? person.team ?? ""
                }
            }
        } catch {
            print("Failed to load user profile: \(error)")
            // Fall back to person data (already initialized)
        }
    }

    private func updateProfile() async {
        isUpdating = true

        do {
            try await profileManager.updateFoundationProfile(
                preferredName: preferredName.trimmingCharacters(in: .whitespacesAndNewlines),
                callName: callName.trimmingCharacters(in: .whitespacesAndNewlines),
                jobRole: jobRole.trimmingCharacters(in: .whitespacesAndNewlines),
                company: company.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : company.trimmingCharacters(in: .whitespacesAndNewlines)
            )

            // Create updated person object for UI consistency
            // Note: The backend should sync user_profiles -> is_self person
            let updatedPerson = Person(
                id: person.id,
                userId: person.userId,
                name: preferredName.trimmingCharacters(in: .whitespacesAndNewlines),
                role: jobRole.trimmingCharacters(in: .whitespacesAndNewlines),
                relationshipType: person.relationshipType,
                team: company.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : company.trimmingCharacters(in: .whitespacesAndNewlines),
                location: person.location,
                createdAt: person.createdAt,
                updatedAt: Date(),
                notes: person.notes,
                emoji: person.emoji,
                startDate: person.startDate,
                communicationStyle: person.communicationStyle,
                goals: person.goals,
                strengths: person.strengths,
                challenges: person.challenges,
                lastProfilePrompt: person.lastProfilePrompt,
                profileCompletionScore: person.profileCompletionScore,
                isSelf: person.isSelf
            )

            await MainActor.run {
                onProfileUpdated(updatedPerson)
            }
        } catch {
            await MainActor.run {
                errorMessage = "Failed to update profile: \(error.localizedDescription)"
                showError = true
                isUpdating = false
            }
        }
    }
}

#Preview {
    let samplePerson = Person(
        id: UUID(),
        userId: UUID(),
        name: "You",
        role: "Engineering Manager",
        relationshipType: "self",
        team: "Acme Corp",
        location: nil,
        createdAt: Date(),
        updatedAt: Date(),
        notes: nil,
        emoji: nil,
        startDate: nil,
        communicationStyle: nil,
        goals: nil,
        strengths: nil,
        challenges: nil,
        lastProfilePrompt: nil,
        profileCompletionScore: nil,
        isSelf: true
    )

    EditSelfProfileView(
        person: samplePerson,
        onProfileUpdated: { _ in },
        onCancel: { }
    )
}