//
//  MainTabView.swift
//  Mano
//
//  Created by Claude on 13/10/2025.
//

import SwiftUI

@available(iOS 26.0, *)
struct MainTabView: View {
    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            // People tab
            ManoHomeView()
                .tabItem {
                    Label("People", systemImage: "person.2")
                }
                .tag(0)

            // Pinned tab
            NavigationStack {
                PinnedView()
            }
            .tabItem {
                Label("Pinned", systemImage: "pin")
            }
            .tag(1)
        }
    }
}

@available(iOS 26.0, *)
#Preview {
    MainTabView()
}
