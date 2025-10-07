//
//  AddPersonView.swift
//  Mano
//
//  Created by Claude on 11/09/2025.
//

import SwiftUI

struct AddPersonView: View {
    @Binding var isPresented: Bool
    let onPersonCreated: (Person) -> Void
    
    @State private var name = ""
    @State private var role = ""
    @State private var selectedRelationship: RelationshipType? = nil
    @State private var relationshipDuration: RelationshipDuration = .justStarted
    @State private var isCreating = false
    @State private var showError = false
    @State private var errorMessage = ""

    @FocusState private var isNameFocused: Bool
    
    enum RelationshipDuration: String, CaseIterable {
        case justStarted = "just_started"
        case lessThanSixMonths = "less_than_6_months"
        case sixMonthsToYear = "6_months_to_1_year"
        case oneToTwoYears = "1_to_2_years"
        case twoToFiveYears = "2_to_5_years"
        case moreThanFiveYears = "5_plus_years"

        var displayName: String {
            switch self {
            case .justStarted: return "Just started"
            case .lessThanSixMonths: return "Less than 6 months"
            case .sixMonthsToYear: return "6 months - 1 year"
            case .oneToTwoYears: return "1-2 years"
            case .twoToFiveYears: return "2-5 years"
            case .moreThanFiveYears: return "5+ years"
            }
        }

        func toDate() -> Date {
            let calendar = Calendar.current
            let now = Date()

            switch self {
            case .justStarted:
                return now // Just started today
            case .lessThanSixMonths:
                return calendar.date(byAdding: .month, value: -3, to: now) ?? now // ~3 months ago
            case .sixMonthsToYear:
                return calendar.date(byAdding: .month, value: -9, to: now) ?? now // ~9 months ago
            case .oneToTwoYears:
                return calendar.date(byAdding: .month, value: -18, to: now) ?? now // ~1.5 years ago
            case .twoToFiveYears:
                return calendar.date(byAdding: .year, value: -3, to: now) ?? now // ~3 years ago
            case .moreThanFiveYears:
                return calendar.date(byAdding: .year, value: -7, to: now) ?? now // ~7 years ago
            }
        }
    }

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

        var description: String {
            switch self {
            case .manager: return "Someone who manages you"
            case .directReport: return "Someone you manage"
            case .peer: return "A colleague at your level"
            case .stakeholder: return "Key partner or customer"
            case .other: return "Cross-functional or informal"
            }
        }
    }
    
    var canCreate: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && 
        selectedRelationship != nil && 
        !isCreating
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Header
                    VStack(spacing: 8) {
                        Text("Add New Person")
                            .font(.largeTitle.bold())
                        Text("Start tracking conversations with someone new")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.top)

                    // Form fields
                    VStack(spacing: 20) {
                    // Name field
                    VStack(alignment: .leading, spacing: 8) {
                        Label("Name", systemImage: "person.fill")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        
                        TextField("Enter their name", text: $name)
                            .textFieldStyle(.plain)
                            .font(.title3)
                            .padding(12)
                            .background(Color(.systemGray6), in: RoundedRectangle(cornerRadius: 12))
                            .focused($isNameFocused)
                    }
                    
                    // Role field (optional)
                    VStack(alignment: .leading, spacing: 8) {
                        Label("Role or Title (optional)", systemImage: "briefcase")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        
                        TextField("e.g. Senior Engineer", text: $role)
                            .textFieldStyle(.plain)
                            .font(.title3)
                            .padding(12)
                            .background(Color(.systemGray6), in: RoundedRectangle(cornerRadius: 12))
                    }
                    
                    // Relationship selector
                    VStack(alignment: .leading, spacing: 12) {
                        Label("Relationship", systemImage: "person.2.circle")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        // Grid of relationship options (prioritized order)
                        VStack(spacing: 12) {
                            // Row 1: Most common
                            HStack(spacing: 12) {
                                RelationshipButton(
                                    type: .directReport,
                                    isSelected: selectedRelationship == .directReport,
                                    action: { selectedRelationship = .directReport }
                                )

                                RelationshipButton(
                                    type: .peer,
                                    isSelected: selectedRelationship == .peer,
                                    action: { selectedRelationship = .peer }
                                )
                            }

                            // Row 2: Formal relationships
                            HStack(spacing: 12) {
                                RelationshipButton(
                                    type: .stakeholder,
                                    isSelected: selectedRelationship == .stakeholder,
                                    action: { selectedRelationship = .stakeholder }
                                )

                                RelationshipButton(
                                    type: .manager,
                                    isSelected: selectedRelationship == .manager,
                                    action: { selectedRelationship = .manager }
                                )
                            }

                            // Row 3: Catch-all (full width for emphasis)
                            RelationshipButton(
                                type: .other,
                                isSelected: selectedRelationship == .other,
                                action: { selectedRelationship = .other }
                            )
                        }
                    }

                    // Relationship Duration Picker
                    VStack(alignment: .leading, spacing: 8) {
                        Label("Working together", systemImage: "calendar")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        Menu {
                            ForEach(RelationshipDuration.allCases, id: \.self) { duration in
                                Button(duration.displayName) {
                                    relationshipDuration = duration
                                }
                            }
                        } label: {
                            HStack {
                                Text(relationshipDuration.displayName)
                                    .foregroundStyle(.primary)
                                Spacer()
                                Image(systemName: "chevron.up.chevron.down")
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                            }
                            .padding(12)
                            .background(Color(.systemGray6), in: RoundedRectangle(cornerRadius: 12))
                        }
                    }
                }
                .padding(.horizontal)

                Spacer()
                
                // Action buttons
                VStack(spacing: 12) {
                    Button(action: createPerson) {
                        HStack {
                            if isCreating {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle())
                                    .scaleEffect(0.8)
                            } else {
                                Image(systemName: "message.fill")
                                Text("Start Conversation")
                            }
                        }
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(canCreate ? Color.blue : Color.gray)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                    .disabled(!canCreate)
                    
                    Button("Cancel") {
                        isPresented = false
                    }
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                }
                .padding(.horizontal)
                .padding(.bottom)
                }
            }
            .interactiveDismissDisabled(isCreating)
            .alert("Error", isPresented: $showError) {
                Button("OK") { }
            } message: {
                Text(errorMessage)
            }
            .onAppear {
                isNameFocused = true
            }
        }
    }
    
    private func createPerson() {
        guard canCreate else { return }
        
        isCreating = true
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedRole = role.trimmingCharacters(in: .whitespacesAndNewlines)
        
        Task {
            do {
                let person = try await SupabaseManager.shared.createPerson(
                    name: trimmedName,
                    role: trimmedRole.isEmpty ? nil : trimmedRole,
                    relationshipType: selectedRelationship!.rawValue,
                    startedWorkingTogether: relationshipDuration.toDate()
                )
                
                await MainActor.run {
                    onPersonCreated(person)
                    isPresented = false
                }
            } catch {
                await MainActor.run {
                    errorMessage = "Failed to create person: \(error.localizedDescription)"
                    showError = true
                    isCreating = false
                }
            }
        }
    }
}

struct RelationshipButton: View {
    let type: AddPersonView.RelationshipType
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: type.icon)
                    .font(.system(size: 28, weight: .medium))
                    .foregroundStyle(isSelected ? .white : .primary)
                
                Text(type.displayName)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundStyle(isSelected ? .white : .primary)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 90)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(isSelected ? Color.blue : Color(.systemGray6))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(isSelected ? Color.blue : Color.clear, lineWidth: 2)
            )
            .scaleEffect(isSelected ? 0.95 : 1.0)
            .animation(.spring(response: 0.2, dampingFraction: 0.7), value: isSelected)
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    @Previewable @State var isPresented = true
    
    AddPersonView(
        isPresented: $isPresented,
        onPersonCreated: { person in
            print("Created person: \(person.name)")
        }
    )
}