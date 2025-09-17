import XCTest
@testable import Mano

final class MessageTests: XCTestCase {
    
    // MARK: - Initialization Tests
    
    func testMessageInitialization() {
        let messageId = UUID()
        let userId = UUID()
        let personId = UUID()
        let now = Date()
        
        let message = Message(
            id: messageId,
            userId: userId,
            content: "Hello, world!",
            isUser: true,
            personId: personId,
            topicId: nil,
            createdAt: now
        )
        
        XCTAssertEqual(message.id, messageId)
        XCTAssertEqual(message.userId, userId)
        XCTAssertEqual(message.content, "Hello, world!")
        XCTAssertTrue(message.isUser)
        XCTAssertEqual(message.personId, personId)
        XCTAssertNil(message.topicId)
        XCTAssertEqual(message.createdAt, now)
    }
    
    func testSystemMessageInitialization() {
        let message = Message(
            id: UUID(),
            userId: UUID(),
            content: "System generated message",
            isUser: false,
            personId: nil,
            topicId: UUID(),
            createdAt: Date()
        )
        
        XCTAssertFalse(message.isUser)
        XCTAssertNil(message.personId)
        XCTAssertNotNil(message.topicId)
    }
    
    // MARK: - Codable Tests
    
    func testMessageEncoding() throws {
        let message = Message(
            id: UUID(),
            userId: UUID(),
            content: "Test message",
            isUser: true,
            personId: UUID(),
            topicId: nil,
            createdAt: Date()
        )
        
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        
        let data = try encoder.encode(message)
        XCTAssertNotNil(data)
        XCTAssertGreaterThan(data.count, 0)
    }
    
    func testMessageDecoding() throws {
        let jsonString = """
        {
            "id": "550e8400-e29b-41d4-a716-446655440000",
            "user_id": "550e8400-e29b-41d4-a716-446655440001",
            "content": "Test message content",
            "is_user": true,
            "person_id": "550e8400-e29b-41d4-a716-446655440002",
            "topic_id": null,
            "created_at": "2024-01-01T12:00:00Z"
        }
        """
        
        let data = jsonString.data(using: .utf8)!
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        
        let message = try decoder.decode(Message.self, from: data)
        
        XCTAssertEqual(message.content, "Test message content")
        XCTAssertTrue(message.isUser)
        XCTAssertNotNil(message.personId)
        XCTAssertNil(message.topicId)
    }
    
    func testMessageDecodingWithNullPersonId() throws {
        let jsonString = """
        {
            "id": "550e8400-e29b-41d4-a716-446655440000",
            "user_id": "550e8400-e29b-41d4-a716-446655440001",
            "content": "System message",
            "is_user": false,
            "person_id": null,
            "topic_id": "550e8400-e29b-41d4-a716-446655440003",
            "created_at": "2024-01-01T12:00:00Z"
        }
        """
        
        let data = jsonString.data(using: .utf8)!
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        
        let message = try decoder.decode(Message.self, from: data)
        
        XCTAssertEqual(message.content, "System message")
        XCTAssertFalse(message.isUser)
        XCTAssertNil(message.personId)
        XCTAssertNotNil(message.topicId)
    }
    
    // MARK: - Content Validation Tests
    
    func testEmptyMessageContent() {
        let message = Message(
            id: UUID(),
            userId: UUID(),
            content: "",
            isUser: true,
            personId: nil,
            topicId: nil,
            createdAt: Date()
        )
        
        XCTAssertEqual(message.content, "")
        XCTAssertTrue(message.content.isEmpty)
    }
    
    func testLongMessageContent() {
        let longContent = String(repeating: "This is a very long message. ", count: 100)
        
        let message = Message(
            id: UUID(),
            userId: UUID(),
            content: longContent,
            isUser: true,
            personId: nil,
            topicId: nil,
            createdAt: Date()
        )
        
        XCTAssertEqual(message.content, longContent)
        XCTAssertGreaterThan(message.content.count, 1000)
    }
    
    // MARK: - Helper Methods Tests
    
    func testMessageSorting() {
        let now = Date()
        let earlier = now.addingTimeInterval(-3600) // 1 hour ago
        let later = now.addingTimeInterval(3600) // 1 hour from now
        
        let message1 = Message(
            id: UUID(),
            userId: UUID(),
            content: "First",
            isUser: true,
            personId: nil,
            topicId: nil,
            createdAt: earlier
        )
        
        let message2 = Message(
            id: UUID(),
            userId: UUID(),
            content: "Second",
            isUser: true,
            personId: nil,
            topicId: nil,
            createdAt: now
        )
        
        let message3 = Message(
            id: UUID(),
            userId: UUID(),
            content: "Third",
            isUser: true,
            personId: nil,
            topicId: nil,
            createdAt: later
        )
        
        let messages = [message3, message1, message2]
        let sortedMessages = messages.sorted { $0.createdAt < $1.createdAt }
        
        XCTAssertEqual(sortedMessages[0].content, "First")
        XCTAssertEqual(sortedMessages[1].content, "Second")
        XCTAssertEqual(sortedMessages[2].content, "Third")
    }
}