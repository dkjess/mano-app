//
//  Constants.swift
//  Mano
//
//  Created by Claude on 04/10/2025.
//

import Foundation

// MARK: - Animation Durations

enum AnimationDuration {
    /// Standard duration for scroll animations (0.3 seconds)
    static let scroll: TimeInterval = 0.3

    /// Duration for easing animations (0.25 seconds)
    static let easing: TimeInterval = 0.25

    /// Duration for quick animations (0.2 seconds)
    static let quick: TimeInterval = 0.2

    /// Duration for spring animations (0.4 seconds)
    static let spring: TimeInterval = 0.4
}

// MARK: - Timeouts

enum Timeouts {
    /// Scroll throttling interval in seconds (0.3 seconds)
    static let scrollThrottle: TimeInterval = 0.3

    /// User scroll detection timeout (3 seconds)
    static let userScrollDetection: TimeInterval = 3.0

    /// Session retry delay in nanoseconds (500 milliseconds)
    static let sessionRetry: UInt64 = 500_000_000

    /// Auto-focus delay in seconds (0.5 seconds)
    static let autoFocus: TimeInterval = 0.5

    /// Contextual thinking delay in seconds (0.05 seconds)
    static let contextualThinking: TimeInterval = 0.05
}

// MARK: - UI Dimensions

enum UIDimensions {
    /// Icon size for large icons
    static let largeIconSize: CGFloat = 60

    /// Corner radius for standard UI elements
    static let cornerRadius: CGFloat = 12
}
