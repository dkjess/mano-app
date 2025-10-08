//
//  PeopleSidebarView.swift
//  Mano
//
//  Created by Claude on 08/10/2025.
//

import SwiftUI

struct PeopleSidebarView: View {
    @Binding var selectedPerson: Person?
    @Binding var showingAddPerson: Bool
    @State private var people: [Person] = []
    @State private var isLoading = true
    @State private var errorMessage = ""
    @State private var isEditMode = false
    @State private var personToEdit: Person? = nil
    @State private var personToDelete: Person? = nil
    @State private var showingDeleteConfirmation = false
    @State private var showEnvironmentPicker = false
    @State private var showingDeleteAccountConfirmation = false
    @ObservedObject private var supabase = SupabaseManager.shared
    @ObservedObject private var environmentManager = BackendEnvironmentManager.shared

    var body: some View {
        ZStack {
            if isLoading {
                ProgressView("Loading people...")
            } else if people.isEmpty {
                emptyState
            } else {
                peopleList
            }
        }
        .navigationTitle("People")
        .toolbar {
            toolbarContent
        }
        .safeAreaInset(edge: .bottom) {
            bottomToolbar
        }
        .sheet(item: $personToEdit) { person in
            editSheet(for: person)
        }
        .sheet(isPresented: $showEnvironmentPicker) {
            EnvironmentPickerView()
        }
        .alert("Delete \(personToDelete?.name ?? "Person")?", isPresented: $showingDeleteConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                if let person = personToDelete {
                    deletePerson(person)
                }
            }
        } message: {
            Text("This will permanently delete this person and all associated conversations. This action cannot be undone.")
        }
        .alert("Delete Account?", isPresented: $showingDeleteAccountConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Delete Everything", role: .destructive) {
                Task {
                    await deleteAccount()
                }
            }
        } message: {
            Text("This will permanently delete your account, all people, conversations, and data. This action cannot be undone.")
        }
        .onAppear {
            loadPeople()
        }
    }

    private var emptyState: some View {
        VStack {
            ContentUnavailableView(
                "No People Yet",
                systemImage: "person.3",
                description: Text("Start adding people you work with")
            )

            Button(action: { showingAddPerson = true }) {
                Label("Add Your First Person", systemImage: "plus.circle.fill")
                    .font(.headline)
                    .padding()
                    .background(Color.blue)
                    .foregroundStyle(.white)
                    .clipShape(Capsule())
            }
            .padding(.top, 20)
        }
    }

    private var peopleList: some View {
        List(selection: $selectedPerson) {
                    // Self person section
                    Section {
                        ForEach(people.filter { $0.isSelf == true }) { person in
                            if isEditMode {
                                PersonEditRowView(
                                    person: person,
                                    onEdit: {
                                        personToEdit = person
                                    },
                                    onDelete: {
                                        // Self person can't be deleted
                                    }
                                )
                            } else {
                                PersonRowView(person: person)
                                    .tag(person)
                            }
                        }
                    }

                    // Team section
                    Section {
                        ForEach(people.filter { $0.isSelf != true }) { person in
                            if isEditMode {
                                PersonEditRowView(
                                    person: person,
                                    onEdit: {
                                        personToEdit = person
                                    },
                                    onDelete: {
                                        personToDelete = person
                                        showingDeleteConfirmation = true
                                    }
                                )
                            } else {
                                PersonRowView(person: person)
                                    .tag(person)
                            }
                        }
                    } header: {
                        Text("My People")
                    }
            #if os(iOS)
            .listStyle(.sidebar)
            #endif
        }
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .primaryAction) {
            if !people.isEmpty && !isEditMode {
                Button(action: {
                    withAnimation {
                        isEditMode.toggle()
                    }
                }) {
                    Text("Edit")
                }
            } else if isEditMode {
                Button(action: {
                    withAnimation {
                        isEditMode.toggle()
                    }
                }) {
                    Text("Done")
                }
            }
        }
    }

    private var bottomToolbar: some View {
        HStack(spacing: 12) {
            // Add Person button
            Button(action: { showingAddPerson = true }) {
                Label("Add Person", systemImage: "plus")
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.borderless)

            Spacer()

            // Settings/Options menu
            Menu {
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
                        try? await supabase.signOut()
                    }
                }) {
                    Label("Log Out", systemImage: "rectangle.portrait.and.arrow.right")
                }
            } label: {
                Image(systemName: "ellipsis.circle")
            }
            .menuStyle(.borderlessButton)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
        .padding(.horizontal, 12)
        .padding(.bottom, 12)
        .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
    }


    @ViewBuilder
    private func editSheet(for person: Person) -> some View {
        if person.isSelf == true {
            EditSelfProfileView(
                person: person,
                onProfileUpdated: { updatedPerson in
                    // Update the person in the list
                    if let index = people.firstIndex(where: { $0.id == updatedPerson.id }) {
                        people[index] = updatedPerson
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
                    // Update the person in the list
                    if let index = people.firstIndex(where: { $0.id == updatedPerson.id }) {
                        people[index] = updatedPerson
                    }
                    personToEdit = nil
                },
                onCancel: {
                    personToEdit = nil
                }
            )
        }
    }

    private func loadPeople() {
        isLoading = true
        Task {
            do {
                let loadedPeople = try await supabase.people.fetchPeople()
                await MainActor.run {
                    people = loadedPeople
                    isLoading = false

                    // Auto-select first person if none selected
                    if selectedPerson == nil && !people.isEmpty {
                        selectedPerson = people.first(where: { $0.isSelf == true }) ?? people.first
                    }
                }
            } catch {
                await MainActor.run {
                    errorMessage = "Failed to load people: \(error.localizedDescription)"
                    isLoading = false
                }
            }
        }
    }

    private func deletePerson(_ person: Person) {
        Task {
            do {
                try await supabase.people.deletePerson(person.id)
                await MainActor.run {
                    people.removeAll { $0.id == person.id }
                    if selectedPerson?.id == person.id {
                        selectedPerson = nil
                    }
                    personToDelete = nil
                }
            } catch {
                await MainActor.run {
                    errorMessage = "Failed to delete person: \(error.localizedDescription)"
                }
            }
        }
    }

    private func deleteAccount() async {
        do {
            try await supabase.deleteAccount()
        } catch {
            await MainActor.run {
                errorMessage = "Failed to delete account: \(error.localizedDescription)"
            }
        }
    }
}
