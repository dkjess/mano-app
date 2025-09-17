import XCTest
@testable import Mano

final class PersonTests: XCTestCase {
    
    // MARK: - Initialization Tests
    
    func testPersonInitialization() {
        let person = Person(
            id: UUID(),
            userId: UUID(),
            name: "John Doe",
            role: "Software Engineer",
            relationshipType: "direct_report",
            team: "Engineering",
            createdAt: Date(),
            updatedAt: Date()
        )
        
        XCTAssertEqual(person.name, "John Doe")
        XCTAssertEqual(person.role, "Software Engineer")
        XCTAssertEqual(person.relationshipType, "direct_report")
        XCTAssertEqual(person.team, "Engineering")
        XCTAssertNotNil(person.id)
        XCTAssertNotNil(person.userId)
    }
    
    func testPersonInitializationWithOptionalFields() {
        let person = Person(
            id: UUID(),
            userId: UUID(),
            name: "Jane Smith",
            role: nil,
            relationshipType: "peer",
            team: nil,
            createdAt: Date(),
            updatedAt: Date()
        )
        
        XCTAssertEqual(person.name, "Jane Smith")
        XCTAssertNil(person.role)
        XCTAssertEqual(person.relationshipType, "peer")
        XCTAssertNil(person.team)
    }
    
    // MARK: - Codable Tests
    
    func testPersonEncoding() throws {
        let person = Person(
            id: UUID(),
            userId: UUID(),
            name: "Test Person",
            role: "Test Role",
            relationshipType: "direct_report",
            team: "Test Team",
            createdAt: Date(),
            updatedAt: Date()
        )
        
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        
        let data = try encoder.encode(person)
        XCTAssertNotNil(data)
        XCTAssertGreaterThan(data.count, 0)
    }
    
    func testPersonDecoding() throws {
        let jsonString = """
        {
            "id": "550e8400-e29b-41d4-a716-446655440000",
            "user_id": "550e8400-e29b-41d4-a716-446655440001",
            "name": "Test Person",
            "role": "Test Role",
            "relationship_type": "direct_report",
            "team": "Test Team",
            "created_at": "2024-01-01T00:00:00Z",
            "updated_at": "2024-01-01T00:00:00Z"
        }
        """
        
        let data = jsonString.data(using: .utf8)!
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        
        let person = try decoder.decode(Person.self, from: data)
        
        XCTAssertEqual(person.name, "Test Person")
        XCTAssertEqual(person.role, "Test Role")
        XCTAssertEqual(person.relationshipType, "direct_report")
        XCTAssertEqual(person.team, "Test Team")
    }
    
    // MARK: - Validation Tests
    
    func testPersonDisplayName() {
        let personWithRole = Person(
            id: UUID(),
            userId: UUID(),
            name: "John Doe",
            role: "Senior Engineer",
            relationshipType: "direct_report",
            team: "Engineering",
            createdAt: Date(),
            updatedAt: Date()
        )
        
        let personWithoutRole = Person(
            id: UUID(),
            userId: UUID(),
            name: "Jane Smith",
            role: nil,
            relationshipType: "peer",
            team: "Product",
            createdAt: Date(),
            updatedAt: Date()
        )
        
        // Test display name formatting if implemented
        // This would depend on the actual implementation
    }
    
    func testRelationshipTypeValidation() {
        let validTypes = ["direct_report", "manager", "peer", "stakeholder"]
        
        for type in validTypes {
            let person = Person(
                id: UUID(),
                userId: UUID(),
                name: "Test",
                role: nil,
                relationshipType: type,
                team: nil,
                createdAt: Date(),
                updatedAt: Date()
            )
            
            XCTAssertEqual(person.relationshipType, type)
        }
    }
}