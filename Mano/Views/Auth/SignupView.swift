//
//  SignupView.swift
//  Mano
//
//  Created by Claude on 15/09/2025.
//

import SwiftUI
import AuthenticationServices

struct SignupView: View {
    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var showEmailForm = false
    @State private var showError = false
    @State private var showOnboarding = false

    @ObservedObject private var authManager = SupabaseManager.shared.auth

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 32) {
                    // Header
                    VStack(spacing: 16) {
                        Text("👋")
                            .font(.system(size: 64))

                        Text("Join Mano")
                            .font(.largeTitle)
                            .fontWeight(.bold)

                        Text("Your AI-powered companion for better management")
                            .font(.body)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                    .padding(.top, 40)

                    Spacer(minLength: 40)

                    // Auth Options
                    VStack(spacing: 16) {
                    // Sign in with Apple
                    SignInWithAppleButton(.signUp) { request in
                        request.requestedScopes = [.fullName, .email]
                    } onCompletion: { result in
                        handleAppleSignIn(result: result)
                    }
                    .frame(height: 50)
                    .cornerRadius(12)

                    // Google Sign In (placeholder for now)
                    Button(action: {
                        Task {
                            try? await authManager.signInWithGoogle()
                        }
                    }) {
                        HStack {
                            Image(systemName: "globe")
                                .font(.system(size: 18, weight: .medium))
                            Text("Continue with Google")
                                .font(.system(size: 16, weight: .medium))
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(Color(.systemGray6))
                        .foregroundColor(.primary)
                        .cornerRadius(12)
                    }

                    // Divider
                    HStack {
                        Rectangle()
                            .frame(height: 1)
                            .foregroundColor(.secondary.opacity(0.3))
                        Text("or")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 16)
                        Rectangle()
                            .frame(height: 1)
                            .foregroundColor(.secondary.opacity(0.3))
                    }
                    .padding(.vertical, 8)

                    // Email/Password
                    if showEmailForm {
                        emailSignupForm
                    } else {
                        Button("Continue with Email") {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                showEmailForm = true
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(Color.accentColor)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                    }
                    }
                    .padding(.horizontal, 24)

                    Spacer(minLength: 60)

                    // Footer
                    VStack(spacing: 8) {
                        HStack {
                            Text("Already have an account?")
                                .foregroundColor(.secondary)
                            Button("Sign In") {
                                // Navigate back to login
                            }
                            .foregroundColor(.accentColor)
                        }
                        .font(.system(size: 14))

                        Text("By continuing, you agree to our Terms & Privacy Policy")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 32)
                    }
                    .padding(.bottom, 32)
                }
                .frame(maxWidth: .infinity)
                .frame(minHeight: UIScreen.main.bounds.height - 100)
            }
            .scrollDismissesKeyboard(.interactively)
            .onTapGesture {
                // Dismiss keyboard when tapping outside
                UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
            }
            .disabled(authManager.isLoading)
            .overlay {
                if authManager.isLoading {
                    Color.black.opacity(0.3)
                        .overlay {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                .scaleEffect(1.2)
                        }
                }
            }
            .alert("Error", isPresented: $showError) {
                Button("OK") { }
            } message: {
                Text(authManager.errorMessage)
            }
            .navigationDestination(isPresented: $showOnboarding) {
                OnboardingFlowView()
            }
        }
    }

    private var emailSignupForm: some View {
        VStack(spacing: 16) {
            TextField("Email", text: $email)
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .background(Color(.systemGray6))
                .cornerRadius(12)
                .textContentType(.emailAddress)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .keyboardType(.emailAddress)

            SecureField("Password", text: $password)
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .background(Color(.systemGray6))
                .cornerRadius(12)
                .textContentType(.newPassword)
                .keyboardType(.default)

            SecureField("Confirm Password", text: $confirmPassword)
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .background(Color(.systemGray6))
                .cornerRadius(12)
                .textContentType(.password)
                .keyboardType(.default)

            Button("Create Account") {
                handleEmailSignup()
            }
            .frame(maxWidth: .infinity)
            .frame(height: 50)
            .background(isEmailFormValid ? Color.accentColor : Color.gray)
            .foregroundColor(.white)
            .cornerRadius(12)
            .disabled(!isEmailFormValid)

            Button("Back") {
                withAnimation(.easeInOut(duration: 0.3)) {
                    showEmailForm = false
                    clearForm()
                }
            }
            .foregroundColor(.secondary)
        }
    }

    private var isEmailFormValid: Bool {
        !email.isEmpty &&
        !password.isEmpty &&
        password.count >= 6 &&
        password == confirmPassword &&
        email.contains("@")
    }

    private func handleAppleSignIn(result: Result<ASAuthorization, Error>) {
        switch result {
        case .success(let authorization):
            if let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential {
                Task {
                    do {
                        // For now, we'll implement a basic flow
                        // In a real implementation, we'd extract the identity token and pass it to Supabase
                        print("Apple Sign In successful: \(appleIDCredential.user)")

                        // For demo purposes, navigate to onboarding
                        await MainActor.run {
                            showOnboarding = true
                        }
                    } catch {
                        await MainActor.run {
                            authManager.errorMessage = error.localizedDescription
                            showError = true
                        }
                    }
                }
            }
        case .failure(let error):
            authManager.errorMessage = error.localizedDescription
            showError = true
        }
    }

    private func handleEmailSignup() {
        Task {
            do {
                try await authManager.signUp(email: email, password: password)
                await MainActor.run {
                    showOnboarding = true
                }
            } catch {
                await MainActor.run {
                    showError = true
                }
            }
        }
    }

    private func clearForm() {
        email = ""
        password = ""
        confirmPassword = ""
    }
}

#Preview {
    SignupView()
}