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
    private let cacheManager = CacheManager.shared

    init(client: SupabaseClient, authManager: SupabaseAuthManager) {
        self.client = client
        self.authManager = authManager
    }

    func fetchPeople() async throws -> [Person] {
        print("🔍 Fetching people from Supabase...")

        guard let userId = await authManager.user?.id else {
            print("❌ No user ID available")
            // Return cached data if offline
            let cached = await cacheManager.getCachedPeople()
            if !cached.isEmpty {
                print("📦 Returning \(cached.count) cached people (offline)")
                return cached
            }
            throw PeopleManagementError.notAuthenticated
        }

        print("🔍 Current user: \(userId.uuidString)")
        print("🔍 Current user email: \(await authManager.user?.email ?? "nil")")

        do {
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

            // Cache the fetched data
            await cacheManager.cachePeople(people)

            return people
        } catch {
            // If network fails, return cached data
            print("⚠️ Network error, falling back to cache: \(error)")
            let cached = await cacheManager.getCachedPeople()
            if !cached.isEmpty {
                print("📦 Returning \(cached.count) cached people (offline fallback)")
                return cached
            }
            throw error
        }
    }
    
    func createPerson(name: String, role: String?, relationshipType: String, startedWorkingTogether: Date? = nil) async throws -> Person {
        print("🆕 Creating person via new /person endpoint: \(name)")

        // Prepare request data for the new /person endpoint
        struct PersonCreationRequest: Codable {
            let name: String
            let role: String?
            let relationship_type: String
            let generate_initial_message: Bool
            let started_working_together: String?
        }

        // Format date as ISO string if provided
        let dateFormatter = ISO8601DateFormatter()
        let dateString = startedWorkingTogether.map { dateFormatter.string(from: $0) }

        let requestData = PersonCreationRequest(
            name: name,
            role: role,
            relationship_type: relationshipType,
            generate_initial_message: true,
            started_working_together: dateString
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
            request.timeoutInterval = 60 // Increase timeout for AI message generation

            print("🆕 Sending manual request to: \(BackendEnvironmentManager.shared.currentEnvironment.supabaseURL)/functions/v1/person")
            
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw PeopleManagementError.invalidResponse
            }
            
            print("🆕 Person create response status: \(httpResponse.statusCode)")
            
            if httpResponse.statusCode != 200 {
                let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
                print("❌ Person create API error: \(errorMessage)")
                throw PeopleManagementError.serverError(statusCode: httpResponse.statusCode, message: errorMessage)
            }
            
            // Log the raw response for debugging
            if let responseString = String(data: data, encoding: .utf8) {
                print("🆕 Raw response: \(responseString)")
            }
            
            // Parse response
            struct PersonCreationResponse: Codable {
                let person: Person
                let hasInitialMessage: Bool?
                let initialMessage: Message? // Backend returns this but we don't need it
            }
            
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let creationResponse = try decoder.decode(PersonCreationResponse.self, from: data)
            
            print("✅ Person created successfully with initial message: \(creationResponse.hasInitialMessage ?? false)")
            return creationResponse.person
            
        } catch {
            print("❌ Person creation failed: \(error)")

            // Provide more specific error messages
            if let urlError = error as? URLError {
                switch urlError.code {
                case .timedOut:
                    throw PeopleManagementError.personCreationFailed("Request timed out. Please check your internet connection and try again.")
                case .notConnectedToInternet, .networkConnectionLost:
                    throw PeopleManagementError.personCreationFailed("No internet connection. Please check your network and try again.")
                case .cannotFindHost, .cannotConnectToHost:
                    throw PeopleManagementError.personCreationFailed("Cannot connect to server. Please try again later.")
                default:
                    throw PeopleManagementError.personCreationFailed("Network error: \(urlError.localizedDescription)")
                }
            }

            throw PeopleManagementError.personCreationFailed(error.localizedDescription)
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
                throw PeopleManagementError.invalidResponse
            }
            
        } catch {
            print("❌ Person update failed: \(error)")
            throw PeopleManagementError.personUpdateFailed(error.localizedDescription)
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
                    throw PeopleManagementError.personDeletionFailed("Delete operation failed")
                }
            } else {
                print("🗑️ Response is not Data type, assuming success")
                print("✅ Person deleted successfully (non-data response)")
            }
            
        } catch {
            print("❌ Person deletion failed with error: \(error)")
            print("❌ Error details: \(error.localizedDescription)")
            throw PeopleManagementError.personDeletionFailed(error.localizedDescription)
        }
    }
}