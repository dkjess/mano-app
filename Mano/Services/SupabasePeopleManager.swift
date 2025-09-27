//
//  SupabasePeopleManager.swift
//  Mano
//
//  Created by Claude on 11/09/2025.
//

import Foundation
import Supabase
import PostgREST

struct CreatePersonData: @preconcurrency Codable, Sendable {
    let id: UUID
    let user_id: String
    let name: String
    let role: String?
    let relationship_type: String
    let created_at: String
    let updated_at: String
}

class SupabasePeopleManager {
    private let client: SupabaseClient
    private let authManager: SupabaseAuthManager
    
    init(client: SupabaseClient, authManager: SupabaseAuthManager) {
        self.client = client
        self.authManager = authManager
    }
    
    func fetchPeople() async throws -> [Person] {
        print("🔍 Fetching people from Supabase...")
        
        guard let userId = await authManager.user?.id else {
            print("❌ No user ID available")
            throw NSError(domain: "SupabasePeopleManager", code: 401, userInfo: [NSLocalizedDescriptionKey: "User not authenticated"])
        }
        
        print("🔍 Current user: \(userId.uuidString)")
        print("🔍 Current user email: \(await authManager.user?.email ?? "nil")")
        
        let response = try await client
            .from("people")
            .select()
            .eq("user_id", value: userId.uuidString.lowercased())
            .order("name")
            .execute()
        
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        
        let people = try decoder.decode([Person].self, from: response.data)
        print("✅ Fetched \(people.count) people")
        return people
    }
    
    func createPerson(name: String, role: String?, relationshipType: String) async throws -> Person {
        print("🆕 Creating person via new /person endpoint: \(name)")
        
        // Prepare request data for the new /person endpoint
        struct PersonCreationRequest: Codable {
            let name: String
            let role: String?
            let relationship_type: String
            let generate_initial_message: Bool
        }
        
        let requestData = PersonCreationRequest(
            name: name,
            role: role,
            relationship_type: relationshipType,
            generate_initial_message: true
        )
        
        // Use manual URLRequest approach like chat function (SDK seems to have issues with POST)
        do {
            let session = try await client.auth.session
            let jsonData = try JSONEncoder().encode(requestData)
            
            var request = URLRequest(url: URL(string: "\(BackendEnvironmentManager.shared.currentEnvironment.supabaseURL)/functions/v1/person")!)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.setValue("Bearer \(session.accessToken)", forHTTPHeaderField: "Authorization")
            request.setValue(BackendEnvironmentManager.shared.currentEnvironment.supabaseAnonKey, forHTTPHeaderField: "apikey")
            request.httpBody = jsonData
            
            print("🆕 Sending manual request to: \(BackendEnvironmentManager.shared.currentEnvironment.supabaseURL)/functions/v1/person")
            
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw NSError(domain: "SupabasePeopleManager", code: 0, userInfo: [NSLocalizedDescriptionKey: "Invalid response"])
            }
            
            print("🆕 Person create response status: \(httpResponse.statusCode)")
            
            if httpResponse.statusCode != 200 {
                let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
                print("❌ Person create API error: \(errorMessage)")
                throw NSError(domain: "SupabasePeopleManager", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: errorMessage])
            }
            
            // Log the raw response for debugging
            if let responseString = String(data: data, encoding: .utf8) {
                print("🆕 Raw response: \(responseString)")
            }
            
            // Parse response
            struct PersonCreationResponse: Codable {
                let person: Person
                let hasInitialMessage: Bool?
            }
            
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let creationResponse = try decoder.decode(PersonCreationResponse.self, from: data)
            
            print("✅ Person created successfully with initial message: \(creationResponse.hasInitialMessage ?? false)")
            return creationResponse.person
            
        } catch {
            print("❌ Person creation failed: \(error)")
            throw NSError(domain: "SupabasePeopleManager", code: 500, userInfo: [NSLocalizedDescriptionKey: "Failed to create person: \(error.localizedDescription)"])
        }
    }
    
    func updatePerson(_ person: Person) async throws -> Person {
        print("📝 Updating person: \(person.name)")
        
        // Prepare request data for the person endpoint
        struct PersonUpdateRequest: Codable {
            let name: String?
            let role: String?
            let relationship_type: String?
            let team: String?
            let location: String?
            let notes: String?
            let emoji: String?
            let communication_style: String?
            let goals: String?
            let strengths: String?
            let challenges: String?
        }
        
        let requestData = PersonUpdateRequest(
            name: person.name,
            role: person.role,
            relationship_type: person.relationshipType,
            team: person.team,
            location: person.location,
            notes: person.notes,
            emoji: person.emoji,
            communication_style: person.communicationStyle,
            goals: person.goals,
            strengths: person.strengths,
            challenges: person.challenges
        )
        
        do {
            // Use invoke without specifying response type to let SDK handle it
            let response = try await client.functions
                .invoke(
                    "person/\(person.id)",
                    options: FunctionInvokeOptions(
                        method: .put,
                        headers: ["Content-Type": "application/json"],
                        body: requestData
                    )
                )
            
            print("📝 Received update response, checking type...")
            
            // Handle response based on its actual type
            if let responseData = response as? Data {
                print("📝 Response is Data, parsing JSON...")
                
                // Log the raw response for debugging
                if let responseString = String(data: responseData, encoding: .utf8) {
                    print("📝 Raw response: \(responseString)")
                }
                
                // Parse response
                struct PersonUpdateResponse: Codable {
                    let person: Person
                }
                
                let decoder = JSONDecoder()
                decoder.dateDecodingStrategy = .iso8601
                let updateResponse = try decoder.decode(PersonUpdateResponse.self, from: responseData)
                
                print("✅ Person updated successfully")
                return updateResponse.person
            } else {
                print("❌ Response is not Data type, cannot parse person")
                throw NSError(domain: "SupabasePeopleManager", code: 500, userInfo: [NSLocalizedDescriptionKey: "Invalid response format"])
            }
            
        } catch {
            print("❌ Person update failed: \(error)")
            throw NSError(domain: "SupabasePeopleManager", code: 500, userInfo: [NSLocalizedDescriptionKey: "Failed to update person: \(error.localizedDescription)"])
        }
    }
    
    func deletePerson(_ personId: UUID) async throws {
        print("🗑️ Starting person deletion: \(personId)")
        
        do {
            // Use invoke without specifying response type to let SDK handle it
            let response = try await client.functions
                .invoke(
                    "person/\(personId)",
                    options: FunctionInvokeOptions(
                        method: .delete,
                        headers: ["Content-Type": "application/json"]
                    )
                )
            
            print("🗑️ Received delete response, checking type...")
            
            // Handle response based on its actual type
            if let responseData = response as? Data {
                print("🗑️ Response is Data, parsing JSON...")
                
                // Log the raw response for debugging
                if let responseString = String(data: responseData, encoding: .utf8) {
                    print("🗑️ Raw response: \(responseString)")
                }
                
                // Parse response to check for success
                struct PersonDeleteResponse: Codable {
                    let success: Bool
                    let message: String?
                }
                
                let decoder = JSONDecoder()
                let deleteResponse = try decoder.decode(PersonDeleteResponse.self, from: responseData)
                
                print("🗑️ Parsed response - success: \(deleteResponse.success), message: \(deleteResponse.message ?? "nil")")
                
                if deleteResponse.success {
                    print("✅ Person deleted successfully: \(deleteResponse.message ?? "")")
                } else {
                    print("❌ Delete response indicates failure")
                    throw NSError(domain: "SupabasePeopleManager", code: 500, userInfo: [NSLocalizedDescriptionKey: "Delete operation failed"])
                }
            } else {
                print("🗑️ Response is not Data type, assuming success")
                print("✅ Person deleted successfully (non-data response)")
            }
            
        } catch {
            print("❌ Person deletion failed with error: \(error)")
            print("❌ Error details: \(error.localizedDescription)")
            throw NSError(domain: "SupabasePeopleManager", code: 500, userInfo: [NSLocalizedDescriptionKey: "Failed to delete person: \(error.localizedDescription)"])
        }
    }
}