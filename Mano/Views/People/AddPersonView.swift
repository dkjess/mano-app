//
//  AddPersonView.swift
//  Mano
//
//  Created by Claude on 11/09/2025.
//

import SwiftUI

struct AddPersonView: View {
    let onPersonCreated: (Person) -> Void
    let onCancel: () -> Void

    @State private var name = ""
    @State private var role = ""
    @State private var selectedRelationship: RelationshipType? = nil
    @State private var relationshipDuration: RelationshipDuration = .sixMonthsToYear
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
                return now
            case .lessThanSixMonths:
                return calendar.date(byAdding: .month, value: -3, to: now) ?? now
            case .sixMonthsToYear:
                return calendar.date(byAdding: .month, value: -9, to: now) ?? now
            case .oneToTwoYears:
                return calendar.date(byAdding: .month, value: -18, to: now) ?? now
            case .twoToFiveYears:
                return calendar.date(byAdding: .year, value: -3, to: now) ?? now
            case .moreThanFiveYears:
                return calendar.date(byAdding: .year, value: -7, to: now) ?? now
            }
        }
    }

    enum RelationshipType: String, CaseIterable {
        case directReport = "direct_report"
        case peer = "peer"
        case manager = "manager"
        case stakeholder = "stakeholder"
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
        ScrollView {
            VStack(spacing: 32) {
                // Header
                VStack(spacing: 8) {
                    Text("Add New Person")
                        .font(.largeTitle.bold())
                    Text("Start tracking conversations with someone new")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(.top, 40)

                // Main form - adaptive layout
                #if os(macOS)
                macOSFormLayout
                #else
                if UIDevice.current.userInterfaceIdiom == .pad {
                    macOSFormLayout
                } else {
                    iPhoneFormLayout
                }
                #endif

                // Action buttons
                VStack(spacing: 12) {
                    Button(action: createPerson) {
                        HStack(spacing: 8) {
                            if isCreating {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle())
                                    .tint(.white)
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
                    .keyboardShortcut(.return, modifiers: .command)

                    Button("Cancel") {
                        onCancel()
                    }
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .keyboardShortcut(.cancelAction)
                }
                .padding(.horizontal, 40)
                .padding(.bottom, 40)
            }
        }
        .alert("Error", isPresented: $showError) {
            Button("OK") { }
        } message: {
            Text(errorMessage)
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                isNameFocused = true
            }
        }
    }

    // macOS/iPad layout: 2-column, horizontal relationship buttons
    private var macOSFormLayout: some View {
        VStack(spacing: 28) {
            // Row 1: Name and Role side-by-side
            HStack(spacing: 20) {
                // Name field
                VStack(alignment: .leading, spacing: 8) {
                    Label("Name", systemImage: "person.fill")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.secondary)

                    TextField("Enter their name", text: $name)
                        .textFieldStyle(.plain)
                        .font(.title3)
                        .padding(14)
                        #if os(iOS)
                        .background(Color(.systemGray6), in: RoundedRectangle(cornerRadius: 10))
                        #else
                        .background(Color(NSColor.controlBackgroundColor), in: RoundedRectangle(cornerRadius: 10))
                        #endif
                        .focused($isNameFocused)
                }

                // Role field
                VStack(alignment: .leading, spacing: 8) {
                    Label("Role or Title (optional)", systemImage: "briefcase")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.secondary)

                    TextField("e.g. Senior Engineer", text: $role)
                        .textFieldStyle(.plain)
                        .font(.title3)
                        .padding(14)
                        #if os(iOS)
                        .background(Color(.systemGray6), in: RoundedRectangle(cornerRadius: 10))
                        #else
                        .background(Color(NSColor.controlBackgroundColor), in: RoundedRectangle(cornerRadius: 10))
                        #endif
                }
            }

            // Row 2: Relationship - Horizontal buttons for common types
            VStack(alignment: .leading, spacing: 12) {
                Label("Relationship", systemImage: "person.2.circle")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.secondary)

                // Most common relationships in a row
                HStack(spacing: 12) {
                    CompactRelationshipButton(
                        type: .directReport,
                        isSelected: selectedRelationship == .directReport,
                        action: { selectedRelationship = .directReport }
                    )

                    CompactRelationshipButton(
                        type: .peer,
                        isSelected: selectedRelationship == .peer,
                        action: { selectedRelationship = .peer }
                    )

                    CompactRelationshipButton(
                        type: .manager,
                        isSelected: selectedRelationship == .manager,
                        action: { selectedRelationship = .manager }
                    )

                    CompactRelationshipButton(
                        type: .stakeholder,
                        isSelected: selectedRelationship == .stakeholder,
                        action: { selectedRelationship = .stakeholder }
                    )

                    CompactRelationshipButton(
                        type: .other,
                        isSelected: selectedRelationship == .other,
                        action: { selectedRelationship = .other }
                    )
                }
            }

            // Row 3: Duration
            VStack(alignment: .leading, spacing: 8) {
                Label("Working together", systemImage: "calendar")
                    .font(.subheadline.weight(.medium))
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
                    .padding(14)
                    #if os(iOS)
                    .background(Color(.systemGray6), in: RoundedRectangle(cornerRadius: 10))
                    #else
                    .background(Color(NSColor.controlBackgroundColor), in: RoundedRectangle(cornerRadius: 10))
                    #endif
                }
            }
        }
        .padding(.horizontal, 40)
    }

    // iPhone layout: Stacked, 2x2 grid for relationships
    private var iPhoneFormLayout: some View {
        VStack(spacing: 24) {
            // Name field
            VStack(alignment: .leading, spacing: 8) {
                Label("Name", systemImage: "person.fill")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.secondary)

                TextField("Enter their name", text: $name)
                    .textFieldStyle(.plain)
                    .font(.title3)
                    .padding(14)
                    .background(Color(.systemGray6), in: RoundedRectangle(cornerRadius: 10))
                    .focused($isNameFocused)
            }

            // Role field
            VStack(alignment: .leading, spacing: 8) {
                Label("Role or Title (optional)", systemImage: "briefcase")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.secondary)

                TextField("e.g. Senior Engineer", text: $role)
                    .textFieldStyle(.plain)
                    .font(.title3)
                    .padding(14)
                    .background(Color(.systemGray6), in: RoundedRectangle(cornerRadius: 10))
            }

            // Relationship selector - 2x2 grid + other
            VStack(alignment: .leading, spacing: 12) {
                Label("Relationship", systemImage: "person.2.circle")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.secondary)

                VStack(spacing: 12) {
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

                    HStack(spacing: 12) {
                        RelationshipButton(
                            type: .manager,
                            isSelected: selectedRelationship == .manager,
                            action: { selectedRelationship = .manager }
                        )

                        RelationshipButton(
                            type: .stakeholder,
                            isSelected: selectedRelationship == .stakeholder,
                            action: { selectedRelationship = .stakeholder }
                        )
                    }

                    RelationshipButton(
                        type: .other,
                        isSelected: selectedRelationship == .other,
                        action: { selectedRelationship = .other }
                    )
                }
            }

            // Duration
            VStack(alignment: .leading, spacing: 8) {
                Label("Working together", systemImage: "calendar")
                    .font(.subheadline.weight(.medium))
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
                    .padding(14)
                    .background(Color(.systemGray6), in: RoundedRectangle(cornerRadius: 10))
                }
            }
        }
        .padding(.horizontal, 24)
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

// Compact horizontal button for macOS/iPad
struct CompactRelationshipButton: View {
    let type: AddPersonView.RelationshipType
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: type.icon)
                    .font(.system(size: 24, weight: .medium))
                    .foregroundStyle(isSelected ? .white : .primary)

                Text(type.displayName)
                    .font(.caption2)
                    .fontWeight(.medium)
                    .foregroundStyle(isSelected ? .white : .primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 70)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    #if os(iOS)
                    .fill(isSelected ? Color.blue : Color(.systemGray6))
                    #else
                    .fill(isSelected ? Color.blue : Color(NSColor.controlBackgroundColor))
                    #endif
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? Color.blue : Color.gray.opacity(0.2), lineWidth: isSelected ? 2 : 1)
            )
        }
        .buttonStyle(.plain)
    }
}

// Full-size button for iPhone
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
    AddPersonView(
        onPersonCreated: { person in
            print("Created person: \(person.name)")
        },
        onCancel: {
            print("Cancelled")
        }
    )
}
