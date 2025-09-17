//
//  UserProfile.swift
//  Mano
//
//  Created by Claude on 16/09/2025.
//

import Foundation

@preconcurrency
struct UserProfile: Decodable, Sendable {
    let id: String?
    let userId: String
    let preferredName: String?
    let callName: String?
    let jobRole: String?
    let company: String?
    let onboardingCompleted: Bool?
    let onboardingStep: Int?
    let createdAt: String?
    let updatedAt: String?

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case preferredName = "preferred_name"
        case callName = "call_name"
        case jobRole = "job_role"
        case company
        case onboardingCompleted = "onboarding_completed"
        case onboardingStep = "onboarding_step"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}