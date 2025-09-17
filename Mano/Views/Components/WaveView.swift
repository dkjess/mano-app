//
//  WaveView.swift
//  Mano
//
//  Created by Jess Wambui Olsen on 31/08/2025.
//

import SwiftUI

struct WaveView: View {
    var body: some View {
        NavigationView {
            VStack {
                Text("👋")
                    .font(.system(size: 100))
                
                NavigationLink("Back to Hello", destination: ContentView())
                    .padding(.top, 20)
            }
            .padding()
        }
    }
}

#Preview {
    WaveView()
}