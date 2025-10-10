#!/usr/bin/env swift

import Foundation

// Simulate the Person model's decoder
struct TestPerson: Codable {
    let id: UUID
    let name: String
    let startedWorkingTogether: Date?

    enum CodingKeys: String, CodingKey {
        case id, name
        case startedWorkingTogether = "started_working_together"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)

        // Handle date-only string (YYYY-MM-DD)
        if let dateString = try container.decodeIfPresent(String.self, forKey: .startedWorkingTogether) {
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withFullDate]
            startedWorkingTogether = formatter.date(from: dateString)
        } else {
            startedWorkingTogether = nil
        }
    }
}

// Test JSON from backend (matching actual response)
let jsonString = """
{
    "id": "57e62c4a-e8f6-4ea5-949a-a79759587653",
    "name": "Test Person",
    "started_working_together": "2024-04-01"
}
"""

print("🧪 Testing Swift date-only decoder...")
print("📥 Input JSON:")
print(jsonString)
print("")

let decoder = JSONDecoder()
decoder.dateDecodingStrategy = .iso8601

do {
    let data = jsonString.data(using: .utf8)!
    let person = try decoder.decode(TestPerson.self, from: data)

    print("✅ Successfully decoded!")
    print("   - name: \(person.name)")
    print("   - started_working_together: \(person.startedWorkingTogether?.description ?? "nil")")

    if person.startedWorkingTogether != nil {
        print("\n🎉 Date parsing works!")
        exit(0)
    } else {
        print("\n❌ Date was parsed as nil!")
        exit(1)
    }
} catch {
    print("❌ Failed to decode: \(error)")
    exit(1)
}
