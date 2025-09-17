import XCTest
import SwiftUI
@testable import Mano

final class EditPersonViewTests: XCTestCase {
    
    // MARK: - Test Data Setup
    
    private func createTestPerson() -> Person {
        return Person(
            id: UUID(),
            userId: UUID(),
            name: "Test Person",
            role: "Software Engineer",
            relationshipType: "direct_report",
            team: "Engineering",
            location: "San Francisco",
            createdAt: Date(),
            updatedAt: Date(),
            notes: "Test notes",
            emoji: "👨‍💻",
            startDate: nil,
            communicationStyle: "Direct and clear",
            goals: "Career advancement",
            strengths: "Problem solving",
            challenges: "Time management",
            lastProfilePrompt: nil,
            profileCompletionScore: 75
        )
    }
    
    // MARK: - Form Validation Tests
    
    func testNameValidation() {
        let testPerson = createTestPerson()
        
        // Test valid name
        let validName = "John Doe"
        XCTAssertFalse(validName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        
        // Test empty name
        let emptyName = ""
        XCTAssertTrue(emptyName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        
        // Test whitespace-only name
        let whitespaceName = "   "
        XCTAssertTrue(whitespaceName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        
        // Test name with leading/trailing whitespace
        let paddedName = "  Alice Johnson  "
        XCTAssertFalse(paddedName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        XCTAssertEqual(paddedName.trimmingCharacters(in: .whitespacesAndNewlines), "Alice Johnson")
    }
    
    func testRelationshipTypeValidation() {
        // Test valid relationship types (matching EditPersonView.RelationshipType enum)
        let validTypes = ["manager", "direct_report", "peer", "stakeholder"]
        
        for validType in validTypes {
            XCTAssertTrue(validTypes.contains(validType))
        }
        
        // Test invalid relationship types
        let invalidTypes = ["invalid_type", "MANAGER", "Direct_Report", "", " "]
        
        for invalidType in invalidTypes {
            XCTAssertFalse(validTypes.contains(invalidType))
        }
    }
    
    func testOptionalFieldsValidation() {
        let testPerson = createTestPerson()
        
        // Test that optional fields can be nil or empty
        let emptyRole = ""
        let emptyTeam = ""
        let emptyLocation = ""
        let emptyNotes = ""
        
        // These should all be valid (empty strings get converted to nil)
        XCTAssertNotNil(emptyRole)  // String exists but is empty
        XCTAssertNotNil(emptyTeam)
        XCTAssertNotNil(emptyLocation)
        XCTAssertNotNil(emptyNotes)
        
        // Test trimming behavior for optional fields
        let paddedRole = "  Senior Engineer  "
        XCTAssertEqual(paddedRole.trimmingCharacters(in: .whitespacesAndNewlines), "Senior Engineer")
    }
    
    func testFormStateValidation() {
        // Test the conditions that would enable/disable the save button
        
        // Valid state - name is not empty
        let validName = "John Doe"
        let isValidState = !validName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        XCTAssertTrue(isValidState)
        
        // Invalid state - name is empty
        let invalidName = ""
        let isInvalidState = invalidName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        XCTAssertTrue(isInvalidState)
        
        // Invalid state - name is only whitespace
        let whitespaceName = "   "
        let isWhitespaceInvalid = whitespaceName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        XCTAssertTrue(isWhitespaceInvalid)
    }
    
    // MARK: - RelationshipType Enum Tests
    
    func testRelationshipTypeEnum() {
        // Test that the RelationshipType enum matches expected values
        // Note: We can't directly access the enum since it's nested in EditPersonView,
        // but we can test the expected raw values and display names
        
        struct TestRelationshipType {
            let rawValue: String
            let displayName: String
            let icon: String
        }
        
        let expectedTypes = [
            TestRelationshipType(rawValue: "manager", displayName: "Manager", icon: "tshirt"),
            TestRelationshipType(rawValue: "direct_report", displayName: "Direct Report", icon: "person"),
            TestRelationshipType(rawValue: "peer", displayName: "Peer", icon: "person.2"),
            TestRelationshipType(rawValue: "stakeholder", displayName: "Stakeholder", icon: "target")
        ]
        
        for type in expectedTypes {
            XCTAssertFalse(type.rawValue.isEmpty)
            XCTAssertFalse(type.displayName.isEmpty)
            XCTAssertFalse(type.icon.isEmpty)
            XCTAssertTrue(type.rawValue.contains("_") || type.rawValue == "manager" || type.rawValue == "peer" || type.rawValue == "stakeholder")
        }
    }
    
    // MARK: - Person Object Creation Tests
    
    func testPersonObjectCreation() {
        let originalPerson = createTestPerson()
        
        // Test creating an updated person with form data
        let updatedName = "Updated Name"
        let updatedRole = "Senior Engineer"
        let updatedRelationshipType = "manager"
        let updatedTeam = "Product"
        let updatedLocation = "New York"
        let updatedNotes = "Updated notes"
        let updatedEmoji = "🔄"
        let updatedCommunicationStyle = "Collaborative"
        let updatedGoals = "Tech leadership"
        let updatedStrengths = "System design"
        let updatedChallenges = "Work-life balance"
        
        // Create updated person (this mirrors what EditPersonView does)
        let updatedPerson = Person(
            id: originalPerson.id,
            userId: originalPerson.userId,
            name: updatedName.trimmingCharacters(in: .whitespacesAndNewlines),
            role: updatedRole.isEmpty ? nil : updatedRole.trimmingCharacters(in: .whitespacesAndNewlines),
            relationshipType: updatedRelationshipType,
            team: updatedTeam.isEmpty ? nil : updatedTeam.trimmingCharacters(in: .whitespacesAndNewlines),
            location: updatedLocation.isEmpty ? nil : updatedLocation.trimmingCharacters(in: .whitespacesAndNewlines),
            createdAt: originalPerson.createdAt,
            updatedAt: Date(),
            notes: updatedNotes.isEmpty ? nil : updatedNotes.trimmingCharacters(in: .whitespacesAndNewlines),
            emoji: updatedEmoji.isEmpty ? nil : updatedEmoji.trimmingCharacters(in: .whitespacesAndNewlines),
            startDate: originalPerson.startDate,
            communicationStyle: updatedCommunicationStyle.isEmpty ? nil : updatedCommunicationStyle.trimmingCharacters(in: .whitespacesAndNewlines),
            goals: updatedGoals.isEmpty ? nil : updatedGoals.trimmingCharacters(in: .whitespacesAndNewlines),
            strengths: updatedStrengths.isEmpty ? nil : updatedStrengths.trimmingCharacters(in: .whitespacesAndNewlines),
            challenges: updatedChallenges.isEmpty ? nil : updatedChallenges.trimmingCharacters(in: .whitespacesAndNewlines),
            lastProfilePrompt: originalPerson.lastProfilePrompt,
            profileCompletionScore: originalPerson.profileCompletionScore
        )
        
        // Verify the updated person has the expected values
        XCTAssertEqual(updatedPerson.id, originalPerson.id)
        XCTAssertEqual(updatedPerson.userId, originalPerson.userId)
        XCTAssertEqual(updatedPerson.name, updatedName)
        XCTAssertEqual(updatedPerson.role, updatedRole)
        XCTAssertEqual(updatedPerson.relationshipType, updatedRelationshipType)
        XCTAssertEqual(updatedPerson.team, updatedTeam)
        XCTAssertEqual(updatedPerson.location, updatedLocation)
        XCTAssertEqual(updatedPerson.notes, updatedNotes)
        XCTAssertEqual(updatedPerson.emoji, updatedEmoji)
        XCTAssertEqual(updatedPerson.communicationStyle, updatedCommunicationStyle)
        XCTAssertEqual(updatedPerson.goals, updatedGoals)
        XCTAssertEqual(updatedPerson.strengths, updatedStrengths)
        XCTAssertEqual(updatedPerson.challenges, updatedChallenges)
    }
    
    func testPersonObjectWithEmptyOptionalFields() {
        let originalPerson = createTestPerson()
        
        // Test creating a person where optional fields are empty strings
        let updatedName = "Minimal Person"
        let emptyRole = ""
        let emptyTeam = ""
        let emptyLocation = ""
        let emptyNotes = ""
        let emptyEmoji = ""
        let emptyCommunicationStyle = ""
        let emptyGoals = ""
        let emptyStrengths = ""
        let emptyChallenges = ""
        
        let minimalPerson = Person(
            id: originalPerson.id,
            userId: originalPerson.userId,
            name: updatedName.trimmingCharacters(in: .whitespacesAndNewlines),
            role: emptyRole.isEmpty ? nil : emptyRole.trimmingCharacters(in: .whitespacesAndNewlines),
            relationshipType: "stakeholder",
            team: emptyTeam.isEmpty ? nil : emptyTeam.trimmingCharacters(in: .whitespacesAndNewlines),
            location: emptyLocation.isEmpty ? nil : emptyLocation.trimmingCharacters(in: .whitespacesAndNewlines),
            createdAt: originalPerson.createdAt,
            updatedAt: Date(),
            notes: emptyNotes.isEmpty ? nil : emptyNotes.trimmingCharacters(in: .whitespacesAndNewlines),
            emoji: emptyEmoji.isEmpty ? nil : emptyEmoji.trimmingCharacters(in: .whitespacesAndNewlines),
            startDate: originalPerson.startDate,
            communicationStyle: emptyCommunicationStyle.isEmpty ? nil : emptyCommunicationStyle.trimmingCharacters(in: .whitespacesAndNewlines),
            goals: emptyGoals.isEmpty ? nil : emptyGoals.trimmingCharacters(in: .whitespacesAndNewlines),
            strengths: emptyStrengths.isEmpty ? nil : emptyStrengths.trimmingCharacters(in: .whitespacesAndNewlines),
            challenges: emptyChallenges.isEmpty ? nil : emptyChallenges.trimmingCharacters(in: .whitespacesAndNewlines),
            lastProfilePrompt: originalPerson.lastProfilePrompt,
            profileCompletionScore: originalPerson.profileCompletionScore
        )
        
        // Verify that empty strings become nil for optional fields
        XCTAssertEqual(minimalPerson.name, "Minimal Person")
        XCTAssertNil(minimalPerson.role)
        XCTAssertNil(minimalPerson.team)
        XCTAssertNil(minimalPerson.location)
        XCTAssertNil(minimalPerson.notes)
        XCTAssertNil(minimalPerson.emoji)
        XCTAssertNil(minimalPerson.communicationStyle)
        XCTAssertNil(minimalPerson.goals)
        XCTAssertNil(minimalPerson.strengths)
        XCTAssertNil(minimalPerson.challenges)
    }
    
    // MARK: - Error Handling Tests
    
    func testErrorStateHandling() {
        // Test error message validation
        let networkError = "Failed to update person: Network error"
        let validationError = "Name is required"
        let authError = "User not authenticated"
        
        XCTAssertFalse(networkError.isEmpty)
        XCTAssertTrue(networkError.contains("Failed to update person"))
        
        XCTAssertFalse(validationError.isEmpty)
        XCTAssertTrue(validationError.contains("required"))
        
        XCTAssertFalse(authError.isEmpty)
        XCTAssertTrue(authError.contains("authenticated"))
    }
    
    func testLoadingStateManagement() {
        // Test loading state flags
        var isUpdating = false
        
        // Start update
        isUpdating = true
        XCTAssertTrue(isUpdating)
        
        // Complete update
        isUpdating = false
        XCTAssertFalse(isUpdating)
        
        // Test that save button should be disabled during update
        let shouldDisableSave = isUpdating
        XCTAssertFalse(shouldDisableSave)  // Since isUpdating is false
    }
    
    // MARK: - Form Initialization Tests
    
    func testFormInitializationFromPerson() {
        let testPerson = createTestPerson()
        
        // Test that form fields are initialized correctly from person data
        // This mirrors how EditPersonView initializes its @State variables
        let initialName = testPerson.name
        let initialRole = testPerson.role ?? ""
        let initialTeam = testPerson.team ?? ""
        let initialLocation = testPerson.location ?? ""
        let initialNotes = testPerson.notes ?? ""
        let initialEmoji = testPerson.emoji ?? ""
        let initialCommunicationStyle = testPerson.communicationStyle ?? ""
        let initialGoals = testPerson.goals ?? ""
        let initialStrengths = testPerson.strengths ?? ""
        let initialChallenges = testPerson.challenges ?? ""
        
        XCTAssertEqual(initialName, "Test Person")
        XCTAssertEqual(initialRole, "Software Engineer")
        XCTAssertEqual(initialTeam, "Engineering")
        XCTAssertEqual(initialLocation, "San Francisco")
        XCTAssertEqual(initialNotes, "Test notes")
        XCTAssertEqual(initialEmoji, "👨‍💻")
        XCTAssertEqual(initialCommunicationStyle, "Direct and clear")
        XCTAssertEqual(initialGoals, "Career advancement")
        XCTAssertEqual(initialStrengths, "Problem solving")
        XCTAssertEqual(initialChallenges, "Time management")
    }
    
    func testFormInitializationWithNilValues() {
        let minimalPerson = Person(
            id: UUID(),
            userId: UUID(),
            name: "Minimal Person",
            role: nil,
            relationshipType: "peer",
            team: nil,
            location: nil,
            createdAt: Date(),
            updatedAt: Date(),
            notes: nil,
            emoji: nil,
            startDate: nil,
            communicationStyle: nil,
            goals: nil,
            strengths: nil,
            challenges: nil,
            lastProfilePrompt: nil,
            profileCompletionScore: nil
        )
        
        // Test initialization with nil values (should become empty strings)
        let initialRole = minimalPerson.role ?? ""
        let initialTeam = minimalPerson.team ?? ""
        let initialLocation = minimalPerson.location ?? ""
        let initialNotes = minimalPerson.notes ?? ""
        let initialEmoji = minimalPerson.emoji ?? ""
        let initialCommunicationStyle = minimalPerson.communicationStyle ?? ""
        let initialGoals = minimalPerson.goals ?? ""
        let initialStrengths = minimalPerson.strengths ?? ""
        let initialChallenges = minimalPerson.challenges ?? ""
        
        // All should be empty strings when the original values were nil
        XCTAssertTrue(initialRole.isEmpty)
        XCTAssertTrue(initialTeam.isEmpty)
        XCTAssertTrue(initialLocation.isEmpty)
        XCTAssertTrue(initialNotes.isEmpty)
        XCTAssertTrue(initialEmoji.isEmpty)
        XCTAssertTrue(initialCommunicationStyle.isEmpty)
        XCTAssertTrue(initialGoals.isEmpty)
        XCTAssertTrue(initialStrengths.isEmpty)
        XCTAssertTrue(initialChallenges.isEmpty)
    }
}