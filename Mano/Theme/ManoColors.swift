//
//  ManoColors.swift
//  Mano
//
//  Brand color palette for Mano
//  Design System: https://claude.ai/public/artifacts/47c57597-dc12-4ee5-b28f-a03da4885dad
//

import SwiftUI

/// Mano brand color palette
/// Reflects "calm professionalism with subtle character" - a steady, grounded presence
struct ManoColors {
    // MARK: - Primary Colors

    /// Forest Green - The hero color
    /// Use for primary action buttons, commitment actions.
    /// This is what makes Mano distinctive.
    static let forestGreen = Color(hex: "#335320")

    /// Warm Yellow - The inviting moment
    /// Use ONLY for mic button to signal voice input as preferred method.
    static let warmYellow = Color(hex: "#F2B824")

    // MARK: - Backgrounds

    /// Almost White - Main background
    /// Main background for entire app. Nearly white with just a whisper of warmth.
    static let almostWhite = Color(hex: "#FAFAF8")

    /// Pure white for cards, input fields, overlays
    static let pureWhite = Color.white

    // MARK: - Neutrals

    /// Stone - Borders and separators
    /// For borders, separators, subtle UI elements. Creates hierarchy without color noise.
    static let stone = Color(hex: "#E8E6E0")

    /// Pale Green - Secondary accents
    /// Derived from forest green. Use for secondary badges, hover states, subtle accents.
    static let paleGreen = Color(hex: "#E8F4E5")

    // MARK: - Text Colors

    /// Primary text - Almost black
    static let primaryText = Color(hex: "#1A1A1A")

    /// Secondary text - Medium gray
    static let secondaryText = Color(hex: "#666666")

    /// Tertiary text - Light gray
    static let tertiaryText = Color(hex: "#999999")
}

// MARK: - Color Extension for Hex Support

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 6: // RGB
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue:  Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}
