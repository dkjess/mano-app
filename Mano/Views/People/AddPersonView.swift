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
    @State private var isCreating = false
    @State private var showError = false
    @State private var errorMessage = ""
    
    @FocusState private var isNameFocused: Bool
    
    enum RelationshipType: String, CaseIterable {
        case manager = "manager"
        case directReport = "direct_report"
        case peer = "peer"
        case stakeholder = "stakeholder"
        
        var displayName: String {
            switch self {
            case .manager: return "Manager"
            case .directReport: return "Direct Report"
            case .peer: return "Peer"
            case .stakeholder: return "Stakeholder"
            }
        }
        
        var icon: String {
            switch self {
            case .manager: return "tshirt"
            case .directReport: return "person"
            case .peer: return "person.2"
            case .stakeholder: return "target"
            }
        }
        
        var description: String {
            switch self {
            case .manager: return "Someone who manages you"
            case .directReport: return "Someone you manage"
            case .peer: return "A colleague at your level"
            case .stakeholder: return "Key partner or customer"
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
                        
                        // 2x2 Grid of relationship options
                        VStack(spacing: 12) {
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
                            
                            HStack(spacing: 12) {
                                RelationshipButton(
                                    type: .peer,
                                    isSelected: selectedRelationship == .peer,
                                    action: { selectedRelationship = .peer }
                                )
                                
                                RelationshipButton(
                                    type: .directReport,
                                    isSelected: selectedRelationship == .directReport,
                                    action: { selectedRelationship = .directReport }
                                )
                            }
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
                    relationshipType: selectedRelationship!.rawValue
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