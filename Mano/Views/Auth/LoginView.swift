//
//  LoginView.swift
//  Mano
//
//  Created by Jess Wambui Olsen on 31/08/2025.
//

import SwiftUI
import Combine

struct LoginView: View {
    @State private var email = "dev@mano.local"
    @State private var password = "dev123456"
    @State private var isLoading = false
    @State private var errorMessage = ""
    @State private var shouldNavigateToHome = false
    
    @ObservedObject private var supabase = SupabaseManager.shared
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 30) {
                Spacer()
                
                VStack(spacing: 20) {
                    Text("Sign In")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                    
                    Text("Enter your credentials to continue")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    // Connection status indicator
                    HStack(spacing: 8) {
                        Circle()
                            .fill(Color.green)
                            .frame(width: 8, height: 8)
                        Text(Config.supabaseURL.contains("127.0.0.1") ? "Connected to Local Supabase" : "Connected to Production")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(8)
                }
                
                VStack(spacing: 20) {
                    TextField("Email", text: $email)
                        .textFieldStyle(.roundedBorder)
                        .textContentType(.emailAddress)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .keyboardType(.emailAddress)

                    SecureField("Password", text: $password)
                        .textFieldStyle(.roundedBorder)
                        .textContentType(.password)
                        .keyboardType(.default)
                    
                    if !errorMessage.isEmpty {
                        Text(errorMessage)
                            .foregroundColor(.red)
                            .font(.caption)
                    }
                    
                    Button(action: signIn) {
                        if isLoading {
                            HStack {
                                ProgressView()
                                    .scaleEffect(0.8)
                                Text("Signing In...")
                            }
                        } else {
                            Text("Sign In")
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .disabled(isLoading || email.isEmpty || password.isEmpty)
                }
                .padding(.horizontal)
                
                Spacer()
                
                // Debug info at bottom
                VStack(spacing: 4) {
                    Button("Clear Session") {
                        Task {
                            try? await supabase.signOut()
                        }
                    }
                    .font(.caption)
                    .foregroundColor(.blue)
                    
                    Text("Supabase URL:")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    Text(Config.supabaseURL)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
                .padding(.bottom)
                
            }
            .padding()
            .navigationDestination(isPresented: $shouldNavigateToHome) {
                ManoHomeView()
            }
        }
    }
    
    private func signIn() {
        isLoading = true
        errorMessage = ""
        
        print("🔵 Attempting login with email: \(email)")
        print("🔵 Supabase URL: \(Config.supabaseURL)")
        
        Task {
            do {
                print("🟡 Calling signIn...")
                try await supabase.signIn(email: email, password: password)
                print("✅ Login successful!")
                await MainActor.run {
                    shouldNavigateToHome = true
                    isLoading = false
                }
            } catch {
                print("❌ Login error: \(error)")
                print("❌ Error type: \(type(of: error))")
                print("❌ Full error: \(String(describing: error))")
                await MainActor.run {
                    errorMessage = "Login failed: \(error.localizedDescription)"
                    isLoading = false
                }
            }
        }
    }
}

#Preview {
    LoginView()
}
