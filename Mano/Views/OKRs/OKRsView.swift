//
//  OKRsView.swift
//  Mano
//
//  Created by Claude on 30/10/2025.
//

import SwiftUI

@available(iOS 26.0, *)
struct OKRsView: View {
    var body: some View {
        ContentUnavailableView(
            "OKRs Coming Soon",
            systemImage: "target",
            description: Text("Track your objectives and key results here")
        )
        .navigationTitle("OKRs")
        .navigationBarTitleDisplayMode(.large)
    }
}

#Preview {
    OKRsView()
}
