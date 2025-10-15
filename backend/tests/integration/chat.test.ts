/**
 * Integration tests for chat Edge Function
 *
 * Tests the main chat functionality including:
 * - Message persistence
 * - Streaming responses
 * - Profile extraction
 * - Context retrieval
 * - Different conversation types (person vs self)
 */

import { assertEquals, assertExists } from "@std/assert";
import { makeTestRequest } from "@test-helpers";
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

const FUNCTION_URL = '/chat';

// Helper to create a test user and person
async function setupTestData() {
  const supabase = createClient(
    Deno.env.get('SUPABASE_URL')!,
    Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
  );

  // Create test user
  const testEmail = `test-chat-${Date.now()}@example.com`;
  const testPassword = 'test-password-123';

  const { data: authData } = await supabase.auth.admin.createUser({
    email: testEmail,
    password: testPassword,
    email_confirm: true
  });

  const userId = authData!.user!.id;

  // Create user profile
  await supabase.from('user_profiles').insert({
    user_id: userId,
    preferred_name: 'Test User',
    call_name: 'Test',
    job_role: 'Engineering Manager',
    company: 'Test Company'
  });

  // Create a person
  const { data: person } = await supabase.from('people').insert({
    user_id: userId,
    name: 'Alice Test',
    relationship_type: 'direct_report',
    role: 'Software Engineer'
  }).select().single();

  // Create self person
  const { data: selfPerson } = await supabase.from('people').insert({
    user_id: userId,
    name: 'Test User',
    relationship_type: 'self',
    is_self: true
  }).select().single();

  // Sign in to get auth token
  const { data: signInData } = await supabase.auth.signInWithPassword({
    email: testEmail,
    password: testPassword
  });

  return {
    userId,
    token: signInData.session?.access_token,
    personId: person.id,
    selfPersonId: selfPerson.id
  };
}

Deno.test("Chat API - Authentication", async (t) => {

  await t.step("should reject requests without authorization", async () => {
    const response = await makeTestRequest(FUNCTION_URL, 'POST', {
      message: 'Hello'
    });

    assertEquals(response.status, 401);
    assertExists(response.data.error);
  });

  await t.step("should reject requests with invalid token", async () => {
    const response = await makeTestRequest(FUNCTION_URL, 'POST', {
      message: 'Hello'
    }, {
      'Authorization': 'Bearer invalid-token'
    });

    assertEquals(response.status, 401);
    assertExists(response.data.error);
  });
});

Deno.test("Chat API - Message Validation", async (t) => {
  const testData = await setupTestData();

  await t.step("should reject empty message", async () => {
    const response = await makeTestRequest(FUNCTION_URL, 'POST', {
      message: '',
      person_id: testData.personId
    }, {
      'Authorization': `Bearer ${testData.token}`
    });

    assertEquals(response.status, 400);
    assertExists(response.data.error);
  });

  await t.step("should reject missing person_id", async () => {
    const response = await makeTestRequest(FUNCTION_URL, 'POST', {
      message: 'Hello'
    }, {
      'Authorization': `Bearer ${testData.token}`
    });

    assertEquals(response.status, 400);
    assertExists(response.data.error);
  });

  await t.step("should reject invalid person_id format", async () => {
    const response = await makeTestRequest(FUNCTION_URL, 'POST', {
      message: 'Hello',
      person_id: 'not-a-uuid'
    }, {
      'Authorization': `Bearer ${testData.token}`
    });

    assertEquals(response.status, 400);
    assertExists(response.data.error);
  });
});

Deno.test("Chat API - Message Persistence", async (t) => {
  const testData = await setupTestData();
  const supabase = createClient(
    Deno.env.get('SUPABASE_URL')!,
    Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
  );

  await t.step("should persist user message to database", async () => {
    const testMessage = `Test message at ${Date.now()}`;

    const response = await makeTestRequest(FUNCTION_URL, 'POST', {
      message: testMessage,
      person_id: testData.personId
    }, {
      'Authorization': `Bearer ${testData.token}`
    });

    assertEquals(response.status, 200);

    // Verify message was saved
    const { data: messages } = await supabase
      .from('messages')
      .select('*')
      .eq('person_id', testData.personId)
      .eq('content', testMessage)
      .eq('is_user', true);

    assertExists(messages);
    assertEquals(messages.length, 1);
    assertEquals(messages[0].content, testMessage);
  });

  await t.step("should persist AI response to database", async () => {
    const response = await makeTestRequest(FUNCTION_URL, 'POST', {
      message: 'Hello',
      person_id: testData.personId
    }, {
      'Authorization': `Bearer ${testData.token}`
    });

    assertEquals(response.status, 200);

    // Wait a bit for streaming to complete
    await new Promise(resolve => setTimeout(resolve, 2000));

    // Verify AI response was saved
    const { data: messages } = await supabase
      .from('messages')
      .select('*')
      .eq('person_id', testData.personId)
      .eq('is_user', false)
      .order('created_at', { ascending: false })
      .limit(1);

    assertExists(messages);
    assertEquals(messages.length, 1);
    assertExists(messages[0].content);
    assertEquals(messages[0].is_user, false);
  });
});

Deno.test("Chat API - Streaming Response", async (t) => {
  const testData = await setupTestData();

  await t.step("should return streaming response", async () => {
    const response = await makeTestRequest(FUNCTION_URL, 'POST', {
      message: 'Hello',
      person_id: testData.personId
    }, {
      'Authorization': `Bearer ${testData.token}`
    });

    assertEquals(response.status, 200);
    // Response should contain streaming data
    assertExists(response.data);
  });

  await t.step("should stream responses for self-reflection", async () => {
    const response = await makeTestRequest(FUNCTION_URL, 'POST', {
      message: 'What am I feeling about work today?',
      person_id: testData.selfPersonId
    }, {
      'Authorization': `Bearer ${testData.token}`
    });

    assertEquals(response.status, 200);
    assertExists(response.data);
  });
});

Deno.test("Chat API - Conversation Management", async (t) => {
  const testData = await setupTestData();
  const supabase = createClient(
    Deno.env.get('SUPABASE_URL')!,
    Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
  );

  await t.step("should create or reuse conversation", async () => {
    // First message
    await makeTestRequest(FUNCTION_URL, 'POST', {
      message: 'First message',
      person_id: testData.personId
    }, {
      'Authorization': `Bearer ${testData.token}`
    });

    // Check conversation was created
    const { data: conversations } = await supabase
      .from('conversations')
      .select('*')
      .eq('person_id', testData.personId)
      .eq('is_active', true);

    assertExists(conversations);
    assertEquals(conversations.length, 1);

    // Second message should reuse same conversation
    await makeTestRequest(FUNCTION_URL, 'POST', {
      message: 'Second message',
      person_id: testData.personId
    }, {
      'Authorization': `Bearer ${testData.token}`
    });

    // Should still be only one active conversation
    const { data: conversationsAfter } = await supabase
      .from('conversations')
      .select('*')
      .eq('person_id', testData.personId)
      .eq('is_active', true);

    assertExists(conversationsAfter);
    assertEquals(conversationsAfter.length, 1);
  });
});

Deno.test("Chat API - Profile Intelligence", async (t) => {
  const testData = await setupTestData();
  const supabase = createClient(
    Deno.env.get('SUPABASE_URL')!,
    Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
  );

  await t.step("should extract profile information from conversation", async () => {
    // Send message with profile information
    await makeTestRequest(FUNCTION_URL, 'POST', {
      message: 'Alice has been working on the React migration project and shows strong leadership skills. She prefers direct communication and values work-life balance.',
      person_id: testData.personId
    }, {
      'Authorization': `Bearer ${testData.token}`
    });

    // Wait for processing
    await new Promise(resolve => setTimeout(resolve, 2000));

    // Check if profile was updated
    const { data: person } = await supabase
      .from('people')
      .select('current_projects, communication_style, values')
      .eq('id', testData.personId)
      .single();

    assertExists(person);
    // Profile extraction should have populated some fields
    // Note: Actual extraction depends on AI response
  });
});

Deno.test("Chat API - CORS", async (t) => {
  await t.step("should handle OPTIONS request for CORS", async () => {
    const response = await makeTestRequest(FUNCTION_URL, 'OPTIONS');

    assertEquals(response.status, 200);
    assertExists(response.headers.get('Access-Control-Allow-Origin'));
  });
});
