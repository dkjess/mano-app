//
//  DesignSystem.swift
//  Mano
//
//  Design system constants for spacing and corner radius
//

import SwiftUI

struct Spacing {
    static let xs: CGFloat = 4      // Tight spacing
    static let sm: CGFloat = 8      // Default gap
    static let md: CGFloat = 12     // Small padding
    static let base: CGFloat = 16   // Standard padding
    static let lg: CGFloat = 20     // Screen margins
    static let xl: CGFloat = 24     // Section spacing
    static let xxl: CGFloat = 32    // Large separation
    static let xxxl: CGFloat = 40   // Extra large
}

struct CornerRadius {
    static let badge: CGFloat = 6   // Small badges
    static let button: CGFloat = 8  // Buttons, icon buttons
    static let input: CGFloat = 12  // Input fields, cards
    static let card: CGFloat = 16   // Large cards
    static let overlay: CGFloat = 24 // Overlays (top corners only)
}
