//
//  ManoHomeView.swift
//  Mano
//
//  Created by Jess Wambui Olsen on 31/08/2025.
//

import SwiftUI
import Combine

@available(iOS 26.0, *)
struct ManoHomeView: View {
    @State private var selectedPerson: Person?
    @State private var showingAddPerson = false

    var body: some View {
        #if os(macOS) || os(visionOS)
        // macOS and visionOS: Always use split view
        NavigationSplitView {
            PeopleSidebarView(
                selectedPerson: $selectedPerson,
                showingAddPerson: $showingAddPerson
            )
        } detail: {
            detailView
        }
        #elseif os(iOS)
        // iOS: Use split view on iPad, navigation stack on iPhone
        if UIDevice.current.userInterfaceIdiom == .pad {
            NavigationSplitView {
                PeopleSidebarView(
                    selectedPerson: $selectedPerson,
                    showingAddPerson: $showingAddPerson
                )
            } detail: {
                detailView
            }
        } else {
            // iPhone: Keep traditional navigation stack
            PeopleListView()
        }
        #else
        // Fallback for other platforms
        PeopleListView()
        #endif
    }

    @ViewBuilder
    private var detailView: some View {
        if showingAddPerson {
            AddPersonView(
                isPresented: $showingAddPerson,
                onPersonCreated: { person in
                    withAnimation(.easeInOut(duration: 0.3)) {
                        selectedPerson = person
                    }
                }
            )
            .transition(.opacity.combined(with: .move(edge: .trailing)))
        } else if let person = selectedPerson {
            ConversationView(person: person)
                .transition(.opacity.combined(with: .move(edge: .trailing)))
        } else {
            ContentUnavailableView(
                "Select a Person",
                systemImage: "person.circle",
                description: Text("Choose someone from the sidebar to start a conversation")
            )
            .transition(.opacity)
        }
    }
}

@available(iOS 26.0, *)
#Preview {
    ManoHomeView()
}