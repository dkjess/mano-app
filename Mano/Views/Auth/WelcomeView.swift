//
//  WelcomeView.swift
//  Mano
//
//  Created by Jess Wambui Olsen on 31/08/2025.
//

import SwiftUI

struct WelcomeView: View {
    var body: some View {
        NavigationStack {
            VStack(spacing: 40) {
                Spacer()
                
                VStack(spacing: 20) {
                    Text("👋")
                        .font(.system(size: 80))
                    
                    Text("Welcome to Mano")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                    
                    Text("Your AI-powered companion for better management")
                        .font(.title3)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                
                Spacer()

                VStack(spacing: 16) {
                    NavigationLink("Create Account", destination: SignupView())
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)
                        .padding(.horizontal)

                    NavigationLink("Sign In", destination: LoginView())
                        .buttonStyle(.bordered)
                        .controlSize(.large)
                        .padding(.horizontal)
                }

                Spacer()
            }
            .padding()
        }
    }
}

#Preview {
    WelcomeView()
}