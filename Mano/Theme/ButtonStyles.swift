//
//  ButtonStyles.swift
//  Mano
//
//  Custom button styles following design system
//

import SwiftUI

struct PrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.vertical, Spacing.base)
            .padding(.horizontal, Spacing.xxxl)
            .background(Color.forestGreen)
            .foregroundColor(.white)
            .font(.system(size: 17, weight: .semibold))
            .cornerRadius(CornerRadius.button)
            .opacity(configuration.isPressed ? 0.8 : 1)
    }
}

struct MicButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .frame(width: 40, height: 40)
            .background(Color.warmYellow)
            .foregroundColor(.white)
            .cornerRadius(CornerRadius.button)
            .opacity(configuration.isPressed ? 0.8 : 1)
    }
}
