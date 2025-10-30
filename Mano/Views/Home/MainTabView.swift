//
//  MainTabView.swift
//  Mano
//
//  Created by Claude on 13/10/2025.
//

import SwiftUI

@available(iOS 26.0, *)
struct MainTabView: View {
    var body: some View {
        TabView {
            ManoHomeView()
                .tabItem {
                    Label("People", systemImage: "person.fill")
                }

            NavigationStack {
                PinnedView()
            }
            .tabItem {
                Label("Pins", systemImage: "pin.fill")
            }

            NavigationStack {
                OKRsView()
            }
            .tabItem {
                Label("OKRs", systemImage: "target")
            }
        }
    }
}

@available(iOS 26.0, *)
#Preview {
    MainTabView()
}
