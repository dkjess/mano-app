//
//  WelcomeView.swift
//  Mano
//
//  Created by Jess Wambui Olsen on 31/08/2025.
//

import SwiftUI

struct WelcomeView: View {
    @ObservedObject private var environmentManager = BackendEnvironmentManager.shared
    @State private var showEnvironmentPicker = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 40) {
                // Environment indicator at top
                HStack {
                    Spacer()
                    Button(action: {
                        showEnvironmentPicker.toggle()
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: environmentManager.currentEnvironment.icon)
                                .font(.caption)
                            Text(environmentManager.currentEnvironment.displayName)
                                .font(.caption)
                                .fontWeight(.medium)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(
                            Capsule()
                                .fill(environmentManager.currentEnvironment == .production ?
                                     Color.green.opacity(0.1) : Color.orange.opacity(0.1))
                        )
                        .foregroundColor(environmentManager.currentEnvironment == .production ?
                                       .green : .orange)
                    }
                }
                .padding(.horizontal)

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
            .sheet(isPresented: $showEnvironmentPicker) {
                EnvironmentPickerView()
            }
        }
    }
}

struct EnvironmentPickerView: View {
    @ObservedObject private var environmentManager = BackendEnvironmentManager.shared
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(BackendEnvironment.allCases, id: \.self) { environment in
                        HStack {
                            Image(systemName: environment.icon)
                                .foregroundColor(environment == .production ? .green : .orange)
                                .frame(width: 30)

                            VStack(alignment: .leading, spacing: 4) {
                                Text(environment.displayName)
                                    .fontWeight(.medium)
                                Text(environment.description)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }

                            Spacer()

                            if environmentManager.currentEnvironment == environment {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.blue)
                            }
                        }
                        .contentShape(Rectangle())
                        .onTapGesture {
                            environmentManager.currentEnvironment = environment
                            dismiss()
                        }
                    }
                } header: {
                    Text("Select Backend Environment")
                } footer: {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Current URL:")
                            .font(.caption)
                            .fontWeight(.medium)
                        Text(environmentManager.currentEnvironment.supabaseURL)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                            .textSelection(.enabled)
                    }
                    .padding(.top, 8)
                }
            }
            .navigationTitle("Backend Environment")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

#Preview {
    WelcomeView()
}