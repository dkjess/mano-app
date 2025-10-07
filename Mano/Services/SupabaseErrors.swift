//
//  SupabaseErrors.swift
//  Mano
//
//  Created by Claude on 04/10/2025.
//

import Foundation

// MARK: - Messaging Errors

enum MessagingError: LocalizedError {
    case notAuthenticated
    case invalidResponse
    case serverError(statusCode: Int, message: String)
    case streamingFailed(String)

    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "User not authenticated"
        case .invalidResponse:
            return "Invalid response from server"
        case .serverError(let statusCode, let message):
            return "Server error (\(statusCode)): \(message)"
        case .streamingFailed(let message):
            return "Streaming failed: \(message)"
        }
    }
}

// MARK: - People Management Errors

enum PeopleManagementError: LocalizedError {
    case notAuthenticated
    case invalidResponse
    case personCreationFailed(String)
    case personUpdateFailed(String)
    case personDeletionFailed(String)
    case serverError(statusCode: Int, message: String)

    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "User not authenticated"
        case .invalidResponse:
            return "Invalid response format"
        case .personCreationFailed(let message):
            return "Failed to create person: \(message)"
        case .personUpdateFailed(let message):
            return "Failed to update person: \(message)"
        case .personDeletionFailed(let message):
            return "Failed to delete person: \(message)"
        case .serverError(let statusCode, let message):
            return "Server error (\(statusCode)): \(message)"
        }
    }
}
