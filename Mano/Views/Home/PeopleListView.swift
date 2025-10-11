//
//  PeopleListView.swift
//  Mano
//
//  Created by Jess Wambui Olsen on 31/08/2025.
//

import SwiftUI

@available(iOS 26.0, *)
struct PeopleListView: View {
    @State private var people: [Person] = []
    @State private var isLoading = true
    @State private var errorMessage = ""
    @State private var showingAddPerson = false
    @State private var navigateToNewPerson: Person? = nil
    @State private var isEditMode = false
    @State private var personToEdit: Person? = nil
    @State private var personToDelete: Person? = nil
    @State private var showingDeleteConfirmation = false
    @State private var showEnvironmentPicker = false
    @State private var showingDeleteAccountConfirmation = false
    @ObservedObject private var supabase = SupabaseManager.shared
    @ObservedObject private var environmentManager = BackendEnvironmentManager.shared
    
    var body: some View {
        NavigationStack {
            mainContent
                .navigationTitle("People")
                .navigationDestination(item: $navigateToNewPerson) { person in
                    ConversationView(person: person)
                }
                .task {
                    await loadPeople()
                }
            .sheet(isPresented: $showingAddPerson) {
                AddPersonView(
                    isPresented: $showingAddPerson,
                    onPersonCreated: { newPerson in
                        people.append(newPerson)
                        people.sort { $0.name < $1.name }
                        navigateToNewPerson = newPerson
                    }
                )
            }
            .sheet(isPresented: $showEnvironmentPicker) {
                EnvironmentPickerView()
            }
            .sheet(item: $personToEdit) { person in
                if person.isSelf == true {
                    EditSelfProfileView(
                        person: person,
                        onProfileUpdated: { updatedPerson in
                            if let index = people.firstIndex(where: { $0.id == updatedPerson.id }) {
                                people[index] = updatedPerson
                                people.sort { $0.name < $1.name }
                            }
                            personToEdit = nil
                        },
                        onCancel: {
                            personToEdit = nil
                        }
                    )
                } else {
                    EditPersonView(
                        person: person,
                        onPersonUpdated: { updatedPerson in
                            if let index = people.firstIndex(where: { $0.id == updatedPerson.id }) {
                                people[index] = updatedPerson
                                people.sort { $0.name < $1.name }
                            }
                            personToEdit = nil
                        },
                        onCancel: {
                            personToEdit = nil
                        }
                    )
                }
            }
            .alert("Delete Person", isPresented: $showingDeleteConfirmation, presenting: personToDelete) { person in
                Button("Cancel", role: .cancel) {
                    personToDelete = nil
                }
                Button("Delete", role: .destructive) {
                    Task {
                        await deletePerson(person)
                    }
                }
            } message: { person in
                Text("Are you sure you want to delete \(person.name)? This will permanently remove all conversations and data related to this person. This action cannot be undone.")
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
    }

    @ViewBuilder
    private var mainContent: some View {
        if isLoading {
            ProgressView("Loading people...")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if people.isEmpty {
            emptyStateView
        } else {
            peopleListView
        }
    }

    private var emptyStateView: some View {
        ContentUnavailableView(
            "No People Yet",
            systemImage: "person.3",
            description: Text("Start adding people you work with to track your conversations")
        )
        .overlay(alignment: .bottom) {
            Button(action: { showingAddPerson = true }) {
                Label("Add Your First Person", systemImage: "plus.circle.fill")
                    .font(.headline)
                    .padding()
                    .background(Color.blue)
                    .foregroundStyle(.white)
                    .clipShape(Capsule())
            }
            .padding(.bottom, 40)
        }
    }

    private var peopleListView: some View {
        List {
            // Self person section
            Section {
                ForEach(people.filter { $0.isSelf == true }) { person in
                    personRow(for: person)
                }
            }

            // Team section
            Section {
                ForEach(people.filter { $0.isSelf != true }) { person in
                    personRow(for: person)
                }
            } header: {
                Text("My People")
            }

            // Bottom buttons section - outside the main sections
            Section {
                HStack() {
                    // Left: Add Person button (Primary action)
                    Button(action: { showingAddPerson = true }) {
                        Label("Add Person", systemImage: "person.badge.plus")
                    }
                    .buttonStyle(.glassProminent)
                    .tint(.blue)
                    .controlSize(.large)

                    Spacer()

                    // Right: Settings menu button (Secondary action)
                    Menu {
                        if !people.isEmpty {
                            Button(action: {
                                isEditMode.toggle()
                            }) {
                                Label(isEditMode ? "Done Editing" : "Edit People", systemImage: isEditMode ? "checkmark" : "pencil")
                            }
                            Divider()
                        }

                        if environmentManager.currentEnvironment == .local {
                            Button(action: { showEnvironmentPicker = true }) {
                                Label("Switch Environment", systemImage: "network")
                            }
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
                        Image(systemName: "gearshape")
                            .imageScale(.large)
                    }
                    .buttonStyle(.glass)
                    .tint(.secondary)
                    .controlSize(.large)
                }
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
            }
        }
        .listStyle(.insetGrouped)
    }

    @ViewBuilder
    private func personRow(for person: Person) -> some View {
        if isEditMode {
            PersonEditRowView(
                person: person,
                onEdit: {
                    personToEdit = person
                },
                onDelete: {
                    if person.isSelf != true {
                        personToDelete = person
                        showingDeleteConfirmation = true
                    }
                }
            )
        } else {
            NavigationLink(destination: ConversationView(person: person)) {
                PersonRowView(person: person)
            }
        }
    }

    private func loadPeople() async {
        isLoading = true
        do {
            people = try await supabase.people.fetchPeople()
            isLoading = false
        } catch {
            print("❌ Failed to load people: \(error)")
            errorMessage = "Failed to load people"
            isLoading = false
        }
    }
    
    private func deletePerson(_ person: Person) async {
        print("🗑️ PeopleListView: Starting deletion of \(person.name) (\(person.id))")
        do {
            try await supabase.people.deletePerson(person.id)
            print("✅ PeopleListView: Delete call succeeded, updating UI")

            // Remove from local array
            await MainActor.run {
                print("🔄 PeopleListView: Removing person from local array (current count: \(people.count))")
                people.removeAll { $0.id == person.id }
                print("✅ PeopleListView: Person removed (new count: \(people.count))")
                personToDelete = nil
                showingDeleteConfirmation = false
                print("✅ PeopleListView: UI state updated")
            }
        } catch {
            print("❌ PeopleListView: Failed to delete person: \(error)")
            print("❌ PeopleListView: Error details: \(error.localizedDescription)")
            // TODO: Show error alert to user
        }
    }

    private func deleteAccount() async {
        print("🗑️ PeopleListView: Starting account deletion")
        do {
            try await supabase.deleteAccount()
            print("✅ PeopleListView: Account deletion succeeded")
            // User will be automatically signed out via auth state change
        } catch {
            print("❌ PeopleListView: Failed to delete account: \(error)")
            print("❌ PeopleListView: Error details: \(error.localizedDescription)")
            // TODO: Show error alert to user
        }
    }
}

@available(iOS 26.0, *)
struct PersonRowView: View {
    let person: Person
    @ObservedObject private var conversationLoader = PersonConversationInfoLoader()

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    if person.isSelf == true {
                        Text("👤")
                            .font(.caption)
                    }
                    Text(person.isSelf == true ? "You" : person.name)
                        .font(.headline)
                        .foregroundColor(person.isSelf == true ? .accentColor : .primary)
                }

                if let role = person.role {
                    Text(role)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                // Show conversation info
                if let conversationInfo = conversationLoader.conversationInfo[person.id] {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(conversationInfo.displayTitle)
                            .font(.caption)
                            .foregroundStyle(.primary)
                            .lineLimit(1)

                        if let subtitle = conversationInfo.displaySubtitle {
                            Text(subtitle)
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                        }
                    }
                } else if conversationLoader.isLoading.contains(person.id) {
                    HStack(spacing: 4) {
                        ProgressView()
                            .scaleEffect(0.6)
                        Text("Loading...")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                }

                HStack {
                    Label(
                        person.isSelf == true ? "You" : person.relationshipType.replacingOccurrences(of: "_", with: " ").capitalized,
                        systemImage: relationshipIcon
                    )
                    .font(.caption)
                    .foregroundStyle(.tertiary)

                    if let team = person.team {
                        Text("·")
                            .foregroundStyle(.tertiary)
                        Text(team)
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                }
            }

            Spacer()

            if person.isSelf == true {
                Text("Profile")
                    .font(.caption)
                    .foregroundColor(.accentColor)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.accentColor.opacity(0.1))
                    .cornerRadius(8)
            }
        }
        .padding(.vertical, 4)
        .task {
            await conversationLoader.loadConversationInfo(for: person.id)
        }
    }
    
    private var relationshipIcon: String {
        if person.isSelf == true {
            return "person.crop.circle"
        }

        switch person.relationshipType {
        case "direct_report":
            return "person.fill"
        case "manager":
            return "person.fill.checkmark"
        case "colleague":
            return "person.2.fill"
        default:
            return "person"
        }
    }
}

@available(iOS 26.0, *)
struct PersonEditRowView: View {
    let person: Person
    let onEdit: () -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack {
            Button(action: onEdit) {
                HStack(spacing: 8) {
                    Image(systemName: person.isSelf == true ? "person.crop.circle.fill" : "pencil.circle.fill")
                        .foregroundColor(.blue)
                        .font(.title2)

                    if person.isSelf == true {
                        Text("Edit Profile")
                            .font(.caption)
                            .foregroundColor(.blue)
                    }
                }
            }
            .buttonStyle(PlainButtonStyle())

            PersonRowView(person: person)

            Spacer()

            // Don't show delete button for is_self person
            if person.isSelf != true {
                Button(action: onDelete) {
                    Image(systemName: "minus.circle.fill")
                        .foregroundColor(.red)
                        .font(.title2)
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .padding(.vertical, 2)
    }
}

@available(iOS 26.0, *)
#Preview {
    PeopleListView()
}
