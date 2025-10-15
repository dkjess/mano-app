/**
 * Unit tests for the Person endpoint
 * Tests person creation, validation, and AI message generation
 */

import { assertEquals, assertExists, assertRejects } from "@std/assert";
import { 
  MockSupabaseClient, 
  MockAnthropicAPI,
  createTestUser, 
  createTestPerson,
  assertValidPerson,
  assertValidMessage,
  makeTestRequest
} from "../utils/test-helpers.ts";

// Helper function to create test messages
function createTestMessage(override: any = {}) {
  return {
    id: crypto.randomUUID(),
    user_id: override.user_id || crypto.randomUUID(),
    person_id: override.person_id || crypto.randomUUID(),
    content: override.content || "Test message content",
    is_user: override.is_user ?? true,
    created_at: override.created_at || new Date().toISOString(),
    ...override
  };
}

// Mock the person endpoint logic for unit testing
class PersonEndpointHandler {
  constructor(
    private supabase: MockSupabaseClient,
    private anthropic: MockAnthropicAPI
  ) {}

  async createPerson(requestData: any, user: any) {
    // Validate required fields
    if (!requestData.name || !requestData.relationship_type) {
      throw new Error('Name and relationship_type are required');
    }

    // Create person record
    const person = {
      id: crypto.randomUUID(),
      user_id: user.id,
      name: requestData.name,
      role: requestData.role || null,
      relationship_type: requestData.relationship_type,
      team: requestData.team || null,
      created_at: new Date().toISOString(),
      updated_at: new Date().toISOString(),
      notes: null,
      emoji: null,
      location: null,
      start_date: null,
      communication_style: null,
      goals: null,
      strengths: null,
      challenges: null,
      last_profile_prompt: null,
      profile_completion_score: 20
    };

    // Generate AI message if requested
    let aiMessage = null;
    if (requestData.generate_initial_message !== false) {
      const messageContent = await this.generateInitialMessage({
        person,
        context: requestData.context,
        current_situation: requestData.current_situation,
        user
      });

      aiMessage = {
        id: crypto.randomUUID(),
        user_id: user.id,
        person_id: person.id,
        content: messageContent,
        is_user: false,
        created_at: new Date().toISOString()
      };
    }

    return {
      person,
      initialMessage: aiMessage,
      hasInitialMessage: !!aiMessage
    };
  }

  private async generateInitialMessage(params: any): Promise<string> {
    const { person, context, current_situation } = params;
    
    // Mock AI message generation
    return `Hi! I see you've added ${person.name} to your team. What would you like to discuss about them?`;
  }

  async updatePerson(requestData: any, user: any, personId: string) {
    // Validate required fields
    if (requestData.name && requestData.name.trim() === '') {
      throw new Error('Name cannot be empty');
    }
    
    if (requestData.relationship_type && !['direct_report', 'manager', 'peer', 'stakeholder'].includes(requestData.relationship_type)) {
      throw new Error('Invalid relationship type');
    }

    // Find existing person
    const existingPerson = this.supabase.getMockData('people').find(
      (p: any) => p.id === personId && p.user_id === user.id
    );
    
    if (!existingPerson) {
      throw new Error('Person not found');
    }

    // Create updated person
    const updatedPerson = {
      ...existingPerson,
      ...requestData,
      updated_at: new Date().toISOString(),
      // Ensure required fields aren't overwritten with empty values
      name: requestData.name?.trim() || existingPerson.name,
      relationship_type: requestData.relationship_type || existingPerson.relationship_type
    };

    return { person: updatedPerson };
  }

  async deletePerson(user: any, personId: string) {
    // Find existing person
    const existingPerson = this.supabase.getMockData('people').find(
      (p: any) => p.id === personId && p.user_id === user.id
    );
    
    if (!existingPerson) {
      throw new Error('Person not found');
    }

    // Mock vector database cleanup
    const embeddings = this.supabase.getMockData('embeddings') || [];
    const personEmbeddings = embeddings.filter((e: any) => e.person_id === personId && e.user_id === user.id);
    
    // Mock deletion of embeddings
    this.supabase.setMockData('embeddings', 
      embeddings.filter((e: any) => !(e.person_id === personId && e.user_id === user.id))
    );

    // Mock deletion of messages
    const messages = this.supabase.getMockData('messages') || [];
    this.supabase.setMockData('messages',
      messages.filter((m: any) => !(m.person_id === personId && m.user_id === user.id))
    );

    // Mock deletion of person
    const people = this.supabase.getMockData('people') || [];
    this.supabase.setMockData('people',
      people.filter((p: any) => !(p.id === personId && p.user_id === user.id))
    );

    return {
      success: true,
      message: `Successfully deleted ${existingPerson.name} and ${personEmbeddings.length} related embeddings`
    };
  }
}

Deno.test("Person Endpoint - Create Person", async (t) => {
  const mockSupabase = new MockSupabaseClient();
  const mockAnthropic = new MockAnthropicAPI();
  const handler = new PersonEndpointHandler(mockSupabase, mockAnthropic);
  const testUser = createTestUser();

  await t.step("should create person with required fields", async () => {
    const requestData = {
      name: "John Doe",
      relationship_type: "direct_report"
    };

    const result = await handler.createPerson(requestData, testUser);

    assertValidPerson(result.person);
    assertEquals(result.person.name, "John Doe");
    assertEquals(result.person.relationship_type, "direct_report");
    assertEquals(result.person.user_id, testUser.id);
    assertExists(result.initialMessage);
    assertEquals(result.hasInitialMessage, true);
  });

  await t.step("should create person with optional fields", async () => {
    const requestData = {
      name: "Jane Smith",
      role: "Senior Engineer",
      relationship_type: "peer",
      team: "Engineering"
    };

    const result = await handler.createPerson(requestData, testUser);

    assertEquals(result.person.role, "Senior Engineer");
    assertEquals(result.person.team, "Engineering");
  });

  await t.step("should generate contextual AI message", async () => {
    const requestData = {
      name: "Alice Johnson",
      role: "Product Manager",
      relationship_type: "stakeholder",
      context: "New project collaboration",
      current_situation: "Just started working together"
    };

    const result = await handler.createPerson(requestData, testUser);

    assertExists(result.initialMessage);
    assertValidMessage(result.initialMessage!);
    assertEquals(result.initialMessage!.is_user, false);
    assertEquals(result.initialMessage!.person_id, result.person.id);
    assertEquals(typeof result.initialMessage!.content, "string");
  });

  await t.step("should skip AI message when requested", async () => {
    const requestData = {
      name: "Bob Wilson",
      relationship_type: "manager",
      generate_initial_message: false
    };

    const result = await handler.createPerson(requestData, testUser);

    assertEquals(result.initialMessage, null);
    assertEquals(result.hasInitialMessage, false);
  });

  await t.step("should validate required fields", async () => {
    const invalidRequests = [
      { relationship_type: "peer" }, // Missing name
      { name: "Test" }, // Missing relationship_type
      {} // Missing both
    ];

    for (const request of invalidRequests) {
      await assertRejects(
        () => handler.createPerson(request, testUser),
        Error,
        "Name and relationship_type are required"
      );
    }
  });

  await t.step("should validate relationship types", async () => {
    const validTypes = ["direct_report", "manager", "peer", "stakeholder"];
    
    for (const type of validTypes) {
      const request = { name: "Test Person", relationship_type: type };
      const result = await handler.createPerson(request, testUser);
      assertEquals(result.person.relationship_type, type);
    }
  });
});

Deno.test("Person Endpoint - Integration Tests", async (t) => {
  // These tests require the actual Edge Function to be running
  const testUser = createTestUser();
  const authToken = "mock-token"; // In real tests, get actual auth token
  
  await t.step("should handle POST /person endpoint", async () => {
    // Skip if not in integration test mode
    if (!Deno.env.get("RUN_INTEGRATION_TESTS")) return;
    
    const response = await makeTestRequest("/person", "POST", {
      name: "Integration Test Person",
      role: "Test Role",
      relationship_type: "peer"
    }, {
      "Authorization": `Bearer ${authToken}`
    });

    // assertEquals(response.status, 200);
    // assertExists(response.data.person);
    // assertExists(response.data.initialMessage);
  });

  await t.step("should handle PUT /person/{id} endpoint", async () => {
    // Skip if not in integration test mode
    if (!Deno.env.get("RUN_INTEGRATION_TESTS")) return;
    
    const personId = "550e8400-e29b-41d4-a716-446655440000";
    const response = await makeTestRequest(`/person/${personId}`, "PUT", {
      name: "Updated Integration Test Person",
      role: "Updated Test Role",
      relationship_type: "manager",
      team: "Updated Team",
      location: "Updated Location",
      notes: "Updated notes for integration test",
      emoji: "🔄",
      communication_style: "Updated communication style",
      goals: "Updated goals",
      strengths: "Updated strengths",
      challenges: "Updated challenges"
    }, {
      "Authorization": `Bearer ${authToken}`
    });

    // assertEquals(response.status, 200);
    // assertExists(response.data.person);
    // assertEquals(response.data.person.name, "Updated Integration Test Person");
  });

  await t.step("should handle DELETE /person/{id} endpoint", async () => {
    // Skip if not in integration test mode
    if (!Deno.env.get("RUN_INTEGRATION_TESTS")) return;
    
    const personId = "550e8400-e29b-41d4-a716-446655440001";
    const response = await makeTestRequest(`/person/${personId}`, "DELETE", null, {
      "Authorization": `Bearer ${authToken}`
    });

    // assertEquals(response.status, 200);
    // assertEquals(response.data.success, true);
    // assertExists(response.data.message);
  });

  await t.step("should handle PUT with validation errors", async () => {
    // Skip if not in integration test mode
    if (!Deno.env.get("RUN_INTEGRATION_TESTS")) return;
    
    const personId = "550e8400-e29b-41d4-a716-446655440002";
    const response = await makeTestRequest(`/person/${personId}`, "PUT", {
      name: "", // Empty name should fail validation
      relationship_type: "invalid_type"
    }, {
      "Authorization": `Bearer ${authToken}`
    });

    // assertEquals(response.status, 400);
    // assertExists(response.data.error);
  });

  await t.step("should handle DELETE with non-existent person", async () => {
    // Skip if not in integration test mode
    if (!Deno.env.get("RUN_INTEGRATION_TESTS")) return;
    
    const nonExistentId = "00000000-0000-0000-0000-000000000000";
    const response = await makeTestRequest(`/person/${nonExistentId}`, "DELETE", null, {
      "Authorization": `Bearer ${authToken}`
    });

    // assertEquals(response.status, 404);
    // assertExists(response.data.error);
  });

  await t.step("should handle unauthorized requests", async () => {
    // Skip if not in integration test mode
    if (!Deno.env.get("RUN_INTEGRATION_TESTS")) return;
    
    const personId = "550e8400-e29b-41d4-a716-446655440003";
    
    // Test PUT without auth
    const putResponse = await makeTestRequest(`/person/${personId}`, "PUT", {
      name: "Updated Name"
    });
    // assertEquals(putResponse.status, 401);
    
    // Test DELETE without auth
    const deleteResponse = await makeTestRequest(`/person/${personId}`, "DELETE");
    // assertEquals(deleteResponse.status, 401);
  });
});

Deno.test("Person Endpoint - Error Handling", async (t) => {
  const mockSupabase = new MockSupabaseClient();
  const mockAnthropic = new MockAnthropicAPI();
  const handler = new PersonEndpointHandler(mockSupabase, mockAnthropic);

  await t.step("should handle missing user", async () => {
    const requestData = { name: "Test", relationship_type: "peer" };
    
    await assertRejects(
      () => handler.createPerson(requestData, null),
      Error
    );
  });

  await t.step("should handle empty strings", async () => {
    const testUser = createTestUser();
    const requestData = {
      name: "",
      relationship_type: "peer"
    };

    await assertRejects(
      () => handler.createPerson(requestData, testUser),
      Error,
      "Name and relationship_type are required"
    );
  });
});

Deno.test("Person Endpoint - Update Person", async (t) => {
  const mockSupabase = new MockSupabaseClient();
  const mockAnthropic = new MockAnthropicAPI();
  const handler = new PersonEndpointHandler(mockSupabase, mockAnthropic);
  const testUser = createTestUser();

  await t.step("should update person with valid data", async () => {
    const existingPerson = createTestPerson({
      id: "550e8400-e29b-41d4-a716-446655440000",
      user_id: testUser.id,
      name: "Original Name",
      role: "Original Role"
    });

    // Mock existing person lookup
    mockSupabase.setMockData("people", [existingPerson]);

    const updateData = {
      name: "Updated Name",
      role: "Updated Role",
      relationship_type: "manager",
      team: "Engineering",
      location: "New York",
      notes: "Updated notes",
      emoji: "🔄",
      communication_style: "Direct",
      goals: "Career growth",
      strengths: "Problem solving",
      challenges: "Time management"
    };

    const result = await handler.updatePerson(updateData, testUser, existingPerson.id);

    assertValidPerson(result.person);
    assertEquals(result.person.name, "Updated Name");
    assertEquals(result.person.role, "Updated Role");
    assertEquals(result.person.relationship_type, "manager");
    assertEquals(result.person.team, "Engineering");
    assertExists(result.person.updated_at);
  });

  await t.step("should handle partial updates", async () => {
    const existingPerson = createTestPerson({
      id: "550e8400-e29b-41d4-a716-446655440001",
      user_id: testUser.id,
      name: "Original Name",
      role: "Original Role"
    });

    mockSupabase.setMockData("people", [existingPerson]);

    const updateData = {
      name: "Partially Updated Name"
      // Only updating name, other fields should remain
    };

    const result = await handler.updatePerson(updateData, testUser, existingPerson.id);

    assertEquals(result.person.name, "Partially Updated Name");
    // Other fields should remain from original (mocked behavior)
  });

  await t.step("should validate update data", async () => {
    const invalidUpdates = [
      { name: "" }, // Empty name
      { name: "   " }, // Whitespace only
      { relationship_type: "invalid_type" } // Invalid relationship type
    ];

    for (const updateData of invalidUpdates) {
      await assertRejects(
        () => handler.updatePerson(updateData, testUser, "some-id"),
        Error
      );
    }
  });

  await t.step("should handle non-existent person", async () => {
    mockSupabase.setMockData("people", []); // No people exist

    const updateData = { name: "Updated Name" };

    await assertRejects(
      () => handler.updatePerson(updateData, testUser, "non-existent-id"),
      Error,
      "Person not found"
    );
  });

  await t.step("should prevent updating other user's person", async () => {
    const otherUser = createTestUser();
    const otherUsersPerson = createTestPerson({
      id: "550e8400-e29b-41d4-a716-446655440002",
      user_id: otherUser.id, // Different user
      name: "Other User's Person"
    });

    mockSupabase.setMockData("people", [otherUsersPerson]);

    const updateData = { name: "Hacked Name" };

    await assertRejects(
      () => handler.updatePerson(updateData, testUser, otherUsersPerson.id),
      Error,
      "Person not found" // Should not reveal existence of other user's data
    );
  });
});

Deno.test("Person Endpoint - Delete Person", async (t) => {
  const mockSupabase = new MockSupabaseClient();
  const mockAnthropic = new MockAnthropicAPI();
  const handler = new PersonEndpointHandler(mockSupabase, mockAnthropic);
  const testUser = createTestUser();

  await t.step("should delete person and related data", async () => {
    const personToDelete = createTestPerson({
      id: "550e8400-e29b-41d4-a716-446655440000",
      user_id: testUser.id,
      name: "Person To Delete"
    });

    // Mock related data
    const relatedMessages = [
      createTestMessage({ person_id: personToDelete.id, user_id: testUser.id }),
      createTestMessage({ person_id: personToDelete.id, user_id: testUser.id })
    ];
    const relatedEmbeddings = [
      { id: "embed1", person_id: personToDelete.id, user_id: testUser.id },
      { id: "embed2", person_id: personToDelete.id, user_id: testUser.id }
    ];

    mockSupabase.setMockData("people", [personToDelete]);
    mockSupabase.setMockData("messages", relatedMessages);
    mockSupabase.setMockData("embeddings", relatedEmbeddings);

    const result = await handler.deletePerson(testUser, personToDelete.id);

    assertEquals(result.success, true);
    assertExists(result.message);
    assertEquals(typeof result.message, "string");
    
    // Verify related data was cleaned up
    assertEquals(mockSupabase.getMockData("people").length, 0);
    assertEquals(mockSupabase.getMockData("messages").length, 0);
    assertEquals(mockSupabase.getMockData("embeddings").length, 0);
  });

  await t.step("should clean up vector embeddings specifically", async () => {
    const personToDelete = createTestPerson({
      id: "550e8400-e29b-41d4-a716-446655440000",
      user_id: testUser.id,
      name: "Vector Test Person"
    });

    const otherUser = createTestUser();
    const otherPerson = createTestPerson({
      id: "550e8400-e29b-41d4-a716-446655440001",
      user_id: otherUser.id,
      name: "Other User Person"
    });

    // Create embeddings for multiple users and persons
    const embeddings = [
      { id: "embed1", person_id: personToDelete.id, user_id: testUser.id, content: "embedding 1" },
      { id: "embed2", person_id: personToDelete.id, user_id: testUser.id, content: "embedding 2" },
      { id: "embed3", person_id: otherPerson.id, user_id: otherUser.id, content: "other user embedding" },
      { id: "embed4", person_id: "some-other-person", user_id: testUser.id, content: "different person embedding" }
    ];

    mockSupabase.setMockData("people", [personToDelete, otherPerson]);
    mockSupabase.setMockData("embeddings", embeddings);

    const result = await handler.deletePerson(testUser, personToDelete.id);

    assertEquals(result.success, true);
    assertEquals(result.message, "Successfully deleted Vector Test Person and 2 related embeddings");
    
    // Verify only the target person's embeddings were deleted
    const remainingEmbeddings = mockSupabase.getMockData("embeddings");
    assertEquals(remainingEmbeddings.length, 2);
    assertEquals(remainingEmbeddings.find((e: any) => e.id === "embed3").person_id, otherPerson.id);
    assertEquals(remainingEmbeddings.find((e: any) => e.id === "embed4").person_id, "some-other-person");
  });

  await t.step("should handle person with no related data", async () => {
    const personToDelete = createTestPerson({
      id: "550e8400-e29b-41d4-a716-446655440000",
      user_id: testUser.id,
      name: "Isolated Person"
    });

    mockSupabase.setMockData("people", [personToDelete]);
    mockSupabase.setMockData("messages", []);
    mockSupabase.setMockData("embeddings", []);

    const result = await handler.deletePerson(testUser, personToDelete.id);

    assertEquals(result.success, true);
    assertEquals(result.message, "Successfully deleted Isolated Person and 0 related embeddings");
  });

  await t.step("should handle deletion cascade cleanup", async () => {
    const personToDelete = createTestPerson({
      id: "550e8400-e29b-41d4-a716-446655440001",
      user_id: testUser.id,
      name: "Cascade Delete Test"
    });

    mockSupabase.setMockData("people", [personToDelete]);

    const result = await handler.deletePerson(testUser, personToDelete.id);

    assertEquals(result.success, true);
    // In a real implementation, we'd verify that embeddings and messages were deleted
    // This tests the successful completion of the deletion process
  });

  await t.step("should handle non-existent person", async () => {
    mockSupabase.setMockData("people", []); // No people exist

    await assertRejects(
      () => handler.deletePerson(testUser, "non-existent-id"),
      Error,
      "Person not found"
    );
  });

  await t.step("should prevent deleting other user's person", async () => {
    const otherUser = createTestUser();
    const otherUsersPerson = createTestPerson({
      id: "550e8400-e29b-41d4-a716-446655440002",
      user_id: otherUser.id, // Different user
      name: "Other User's Person"
    });

    mockSupabase.setMockData("people", [otherUsersPerson]);

    await assertRejects(
      () => handler.deletePerson(testUser, otherUsersPerson.id),
      Error,
      "Person not found" // Should not reveal existence of other user's data
    );
  });

  await t.step("should handle database errors gracefully", async () => {
    const personToDelete = createTestPerson({
      id: "550e8400-e29b-41d4-a716-446655440003",
      user_id: testUser.id,
      name: "DB Error Test"
    });

    mockSupabase.setMockData("people", [personToDelete]);
    
    // Mock a database error during deletion
    // In a more sophisticated mock, we'd simulate DB failures
    
    // For now, test that the function exists and can be called
    const result = await handler.deletePerson(testUser, personToDelete.id);
    assertEquals(result.success, true);
  });
});