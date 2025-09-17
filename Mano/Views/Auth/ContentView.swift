//
//  ContentView.swift
//  Mano
//
//  Created by Jess Wambui Olsen on 31/08/2025.
//

import SwiftUI

struct ContentView: View {
    var body: some View {
        NavigationView {
            VStack {
                Image(systemName: "globe")
                    .imageScale(.large)
                    .foregroundStyle(.tint)
                Text("Hello, world!")
                
                NavigationLink("Go to Wave", destination: WaveView())
                    .padding(.top, 20)
            }
            .padding()
        }
    }
}

#Preview {
    ContentView()
}
