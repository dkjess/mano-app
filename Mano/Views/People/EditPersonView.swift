//
//  EditPersonView.swift
//  Mano
//
//  Created by Claude on 14/09/2025.
//

import SwiftUI

struct EditPersonView: View {
    let person: Person
    let onPersonUpdated: (Person) -> Void
    let onCancel: () -> Void
    
    @State private var name: String
    @State private var role: String
    @State private var selectedRelationship: RelationshipType
    @State private var team: String
    @State private var location: String
    @State private var notes: String
    @State private var emoji: String
    @State private var communicationStyle: String
    @State private var goals: String
    @State private var strengths: String
    @State private var challenges: String
    @State private var isUpdating = false
    @State private var showError = false
    @State private var errorMessage = ""
    
    @FocusState private var isNameFocused: Bool
    @ObservedObject private var supabase = SupabaseManager.shared
    
    enum RelationshipType: String, CaseIterable {
        case directReport = "direct_report"
        case peer = "peer"
        case stakeholder = "stakeholder"
        case manager = "manager"
        case other = "other"

        var displayName: String {
            switch self {
            case .manager: return "Manager"
            case .directReport: return "Direct Report"
            case .peer: return "Peer"
            case .stakeholder: return "Stakeholder"
            case .other: return "Other"
            }
        }

        var icon: String {
            switch self {
            case .manager: return "tshirt"
            case .directReport: return "person"
            case .peer: return "person.2"
            case .stakeholder: return "target"
            case .other: return "person.crop.circle"
            }
        }
    }
    
    init(person: Person, onPersonUpdated: @escaping (Person) -> Void, onCancel: @escaping () -> Void) {
        self.person = person
        self.onPersonUpdated = onPersonUpdated
        self.onCancel = onCancel
        
        // Initialize state from person
        _name = State(initialValue: person.name)
        _role = State(initialValue: person.role ?? "")
        _selectedRelationship = State(initialValue: RelationshipType(rawValue: person.relationshipType) ?? .peer)
        _team = State(initialValue: person.team ?? "")
        _location = State(initialValue: person.location ?? "")
        _notes = State(initialValue: person.notes ?? "")
        _emoji = State(initialValue: person.emoji ?? "")
        _communicationStyle = State(initialValue: person.communicationStyle ?? "")
        _goals = State(initialValue: person.goals ?? "")
        _strengths = State(initialValue: person.strengths ?? "")
        _challenges = State(initialValue: person.challenges ?? "")
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Basic Information") {
                    TextField("Name", text: $name)
                        .focused($isNameFocused)
                    
                    TextField("Role (optional)", text: $role)
                    
                    TextField("Team (optional)", text: $team)
                    
                    TextField("Location (optional)", text: $location)
                    
                    TextField("Emoji (optional)", text: $emoji)
                        .textInputAutocapitalization(.never)
                }
                
                Section("Relationship") {
                    Picker("Relationship Type", selection: $selectedRelationship) {
                        ForEach(RelationshipType.allCases, id: \.self) { type in
                            Label(type.displayName, systemImage: type.icon)
                                .tag(type)
                        }
                    }
                    .pickerStyle(.menu)
                }
                
                Section("Additional Details") {
                    TextField("Communication Style", text: $communicationStyle, axis: .vertical)
                        .lineLimit(2...4)
                    
                    TextField("Goals", text: $goals, axis: .vertical)
                        .lineLimit(2...4)
                    
                    TextField("Strengths", text: $strengths, axis: .vertical)
                        .lineLimit(2...4)
                    
                    TextField("Challenges", text: $challenges, axis: .vertical)
                        .lineLimit(2...4)
                }
                
                Section("Notes") {
                    TextField("Notes about this person", text: $notes, axis: .vertical)
                        .lineLimit(3...6)
                }
            }
            .navigationTitle("Edit Person")
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
                            await updatePerson()
                        }
                    }
                    .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isUpdating)
                }
            }
            .alert("Error", isPresented: $showError) {
                Button("OK") { }
            } message: {
                Text(errorMessage)
            }
            .onAppear {
                isNameFocused = false
            }
        }
    }
    
    private func updatePerson() async {
        isUpdating = true
        
        do {
            // Create updated person object
            let updatedPerson = Person(
                id: person.id,
                userId: person.userId,
                name: name.trimmingCharacters(in: .whitespacesAndNewlines),
                role: role.isEmpty ? nil : role.trimmingCharacters(in: .whitespacesAndNewlines),
                relationshipType: selectedRelationship.rawValue,
                team: team.isEmpty ? nil : team.trimmingCharacters(in: .whitespacesAndNewlines),
                location: location.isEmpty ? nil : location.trimmingCharacters(in: .whitespacesAndNewlines),
                createdAt: person.createdAt,
                updatedAt: Date(), // This will be updated by the backend
                notes: notes.isEmpty ? nil : notes.trimmingCharacters(in: .whitespacesAndNewlines),
                emoji: emoji.isEmpty ? nil : emoji.trimmingCharacters(in: .whitespacesAndNewlines),
                startDate: person.startDate,
                communicationStyle: communicationStyle.isEmpty ? nil : communicationStyle.trimmingCharacters(in: .whitespacesAndNewlines),
                goals: goals.isEmpty ? nil : goals.trimmingCharacters(in: .whitespacesAndNewlines),
                strengths: strengths.isEmpty ? nil : strengths.trimmingCharacters(in: .whitespacesAndNewlines),
                challenges: challenges.isEmpty ? nil : challenges.trimmingCharacters(in: .whitespacesAndNewlines),
                lastProfilePrompt: person.lastProfilePrompt,
                profileCompletionScore: person.profileCompletionScore,
                isSelf: person.isSelf,
                startedWorkingTogether: person.startedWorkingTogether
            )
            
            let resultPerson = try await supabase.people.updatePerson(updatedPerson)
            
            await MainActor.run {
                onPersonUpdated(resultPerson)
            }
        } catch {
            await MainActor.run {
                errorMessage = "Failed to update person: \(error.localizedDescription)"
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
        name: "Alice Johnson",
        role: "Senior Software Engineer",
        relationshipType: "direct_report",
        team: "Engineering",
        location: "San Francisco",
        createdAt: Date(),
        updatedAt: Date(),
        notes: "Great at problem solving",
        emoji: "👩‍💻",
        startDate: nil,
        communicationStyle: "Direct and clear",
        goals: "Wants to become a tech lead",
        strengths: "Technical expertise, mentoring",
        challenges: "Time management",
        lastProfilePrompt: nil,
        profileCompletionScore: 75,
        isSelf: false,
        startedWorkingTogether: nil
    )
    
    EditPersonView(
        person: samplePerson,
        onPersonUpdated: { _ in },
        onCancel: { }
    )
}