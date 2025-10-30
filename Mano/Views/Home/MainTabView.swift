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
                    Label("People", systemImage: "person.fill")
                }
                .tag(0)

            // Pins tab
            NavigationStack {
                PinnedView()
            }
            .tabItem {
                Label("Pins", systemImage: "pin.fill")
            }
            .tag(1)

            // OKRs tab
            NavigationStack {
                OKRsView()
            }
            .tabItem {
                Label("OKRs", systemImage: "target")
            }
            .tag(2)
        }
    }
}

@available(iOS 26.0, *)
#Preview {
    MainTabView()
}
