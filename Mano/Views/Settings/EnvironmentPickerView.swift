//
//  EnvironmentPickerView.swift
//  Mano
//
//  Environment switcher for development
//

import SwiftUI

struct EnvironmentPickerView: View {
    @ObservedObject private var environmentManager = BackendEnvironmentManager.shared
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(BackendEnvironment.allCases, id: \.self) { environment in
                        Button {
                            environmentManager.currentEnvironment = environment
                            dismiss()
                        } label: {
                            HStack {
                                Image(systemName: environment.icon)
                                    .foregroundStyle(environmentManager.currentEnvironment == environment ? .blue : .secondary)
                                    .frame(width: 30)

                                VStack(alignment: .leading, spacing: 4) {
                                    Text(environment.displayName)
                                        .foregroundStyle(.primary)
                                    Text(environment.description)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }

                                Spacer()

                                if environmentManager.currentEnvironment == environment {
                                    Image(systemName: "checkmark")
                                        .foregroundStyle(.blue)
                                }
                            }
                        }
                    }
                } header: {
                    Text("Backend Environment")
                } footer: {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Current URL:")
                        Text(environmentManager.currentEnvironment.supabaseURL)
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        Text("\nShake device to access this menu")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                }
            }
            .navigationTitle("Developer Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

#Preview {
    EnvironmentPickerView()
}
