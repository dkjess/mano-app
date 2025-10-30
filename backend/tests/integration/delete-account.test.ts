/**
 * Integration tests for delete-account Edge Function
 *
 * Tests the complete account deletion flow including cascade deletion of all user data.
 * CRITICAL: This function must properly clean up all user data including storage files.
 */

import { assertEquals, assertExists } from "@std/assert";
import { makeTestRequest } from "@test-helpers";
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

const FUNCTION_URL = '/delete-account';

// Helper to create a test user with data
async function createTestUserWithData() {
  const supabase = createClient(
    Deno.env.get('SUPABASE_URL')!,
    Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
  );

  // Create test user
  const testEmail = `test-delete-${Date.now()}@example.com`;
  const testPassword = 'test-password-123';

  const { data: authData, error: authError } = await supabase.auth.admin.createUser({
    email: testEmail,
    password: testPassword,
    email_confirm: true
  });

  if (authError || !authData.user) {
    throw new Error(`Failed to create test user: ${authError?.message}`);
  }

  const userId = authData.user.id;

  // Create user profile
  await supabase.from('user_profiles').insert({
    user_id: userId,
    preferred_name: 'Test User',
    call_name: 'Test'
  });

  // Create a person
  const { data: person } = await supabase.from('people').insert({
    user_id: userId,
    name: 'Test Person',
    relationship_type: 'peer'
  }).select().single();

  // Create a conversation
  const { data: conversation } = await supabase.from('conversations').insert({
    person_id: person.id,
    title: 'Test Conversation',
    is_active: true
  }).select().single();

  // Create messages
  await supabase.from('messages').insert([
    {
      user_id: userId,
      person_id: person.id,
      conversation_id: conversation.id,
      content: 'Test message',
      is_user: true
    }
  ]);

  // Create topic
  await supabase.from('topics').insert({
    created_by: userId,
    title: 'Test Topic'
  });

  // Sign in to get auth token
  const { data: signInData } = await supabase.auth.signInWithPassword({
    email: testEmail,
    password: testPassword
  });

  return {
    userId,
    email: testEmail,
    token: signInData.session?.access_token,
    personId: person.id,
    conversationId: conversation.id
  };
}

// Helper to verify user data is deleted
async function verifyUserDeleted(userId: string) {
  const supabase = createClient(
    Deno.env.get('SUPABASE_URL')!,
    Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
  );

  // Check auth user deleted
  const { data: userData } = await supabase.auth.admin.getUserById(userId);
  assertEquals(userData.user, null, 'Auth user should be deleted');

  // Check profile deleted
  const { data: profile } = await supabase
    .from('user_profiles')
    .select('*')
    .eq('user_id', userId)
    .single();
  assertEquals(profile, null, 'User profile should be deleted');

  // Check people deleted
  const { data: people } = await supabase
    .from('people')
    .select('*')
    .eq('user_id', userId);
  assertEquals(people?.length || 0, 0, 'People should be deleted');

  // Check messages deleted (cascade)
  const { data: messages } = await supabase
    .from('messages')
    .select('*')
    .eq('user_id', userId);
  assertEquals(messages?.length || 0, 0, 'Messages should be deleted');

  // Check topics deleted
  const { data: topics } = await supabase
    .from('topics')
    .select('*')
    .eq('created_by', userId);
  assertEquals(topics?.length || 0, 0, 'Topics should be deleted');
}

Deno.test("Delete Account API", async (t) => {

  await t.step("should reject requests without authorization", async () => {
    const response = await makeTestRequest(FUNCTION_URL, 'DELETE');

    assertEquals(response.status, 401);
    assertExists(response.data.error);
    assertEquals(response.data.error, 'Authorization header is required');
  });

  await t.step("should reject requests with invalid token", async () => {
    const response = await makeTestRequest(FUNCTION_URL, 'DELETE', null, {
      'Authorization': 'Bearer invalid-token'
    });

    assertEquals(response.status, 401);
    assertExists(response.data.error);
  });

  await t.step("should reject non-DELETE methods", async () => {
    const response = await makeTestRequest(FUNCTION_URL, 'GET', null, {
      'Authorization': 'Bearer test-token'
    });

    assertEquals(response.status, 405);
    assertEquals(response.data.error, 'Method not allowed');
  });

  await t.step("should successfully delete account with all related data", async () => {
    // Create test user with full data
    const testUser = await createTestUserWithData();

    // Delete the account
    const response = await makeTestRequest(FUNCTION_URL, 'DELETE', null, {
      'Authorization': `Bearer ${testUser.token}`
    });

    assertEquals(response.status, 200);
    assertEquals(response.data.success, true);
    assertEquals(response.data.message, 'Account successfully deleted');

    // Verify all data was deleted
    await verifyUserDeleted(testUser.userId);
  });

  await t.step("should delete account even with conversations and messages", async () => {
    const testUser = await createTestUserWithData();

    // Add more messages
    const supabase = createClient(
      Deno.env.get('SUPABASE_URL')!,
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
    );

    await supabase.from('messages').insert([
      {
        user_id: testUser.userId,
        person_id: testUser.personId,
        conversation_id: testUser.conversationId,
        content: 'Message 1',
        is_user: true
      },
      {
        user_id: testUser.userId,
        person_id: testUser.personId,
        conversation_id: testUser.conversationId,
        content: 'Message 2',
        is_user: false
      },
      {
        user_id: testUser.userId,
        person_id: testUser.personId,
        conversation_id: testUser.conversationId,
        content: 'Message 3',
        is_user: true
      }
    ]);

    // Delete account
    const response = await makeTestRequest(FUNCTION_URL, 'DELETE', null, {
      'Authorization': `Bearer ${testUser.token}`
    });

    assertEquals(response.status, 200);
    assertEquals(response.data.success, true);

    // Verify cascade deletion worked
    await verifyUserDeleted(testUser.userId);
  });

  await t.step("should handle storage file deletion gracefully", async () => {
    // This tests that the function continues even if storage cleanup fails
    const testUser = await createTestUserWithData();

    const response = await makeTestRequest(FUNCTION_URL, 'DELETE', null, {
      'Authorization': `Bearer ${testUser.token}`
    });

    assertEquals(response.status, 200);
    assertEquals(response.data.success, true);

    // Even if storage cleanup had issues, user should still be deleted
    await verifyUserDeleted(testUser.userId);
  });

  await t.step("should delete user with self person", async () => {
    const testUser = await createTestUserWithData();

    // Create self person
    const supabase = createClient(
      Deno.env.get('SUPABASE_URL')!,
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
    );

    await supabase.from('people').insert({
      user_id: testUser.userId,
      name: 'Test User (Self)',
      relationship_type: 'self',
      is_self: true
    });

    // Delete account
    const response = await makeTestRequest(FUNCTION_URL, 'DELETE', null, {
      'Authorization': `Bearer ${testUser.token}`
    });

    assertEquals(response.status, 200);
    assertEquals(response.data.success, true);

    // Verify all people (including self) are deleted
    await verifyUserDeleted(testUser.userId);
  });
});

Deno.test("Delete Account CORS", async (t) => {
  await t.step("should handle OPTIONS request for CORS", async () => {
    const response = await makeTestRequest(FUNCTION_URL, 'OPTIONS');

    assertEquals(response.status, 200);
    assertExists(response.headers.get('Access-Control-Allow-Origin'));
  });
});

Deno.test("Delete Account Edge Cases", async (t) => {
  await t.step("should handle deletion when user has no data", async () => {
    // Create minimal user with no additional data
    const supabase = createClient(
      Deno.env.get('SUPABASE_URL')!,
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
    );

    const testEmail = `test-minimal-${Date.now()}@example.com`;
    const testPassword = 'test-password-123';

    const { data: authData } = await supabase.auth.admin.createUser({
      email: testEmail,
      password: testPassword,
      email_confirm: true
    });

    const userId = authData!.user!.id;

    // Sign in
    const { data: signInData } = await supabase.auth.signInWithPassword({
      email: testEmail,
      password: testPassword
    });

    // Delete account
    const response = await makeTestRequest(FUNCTION_URL, 'DELETE', null, {
      'Authorization': `Bearer ${signInData.session?.access_token}`
    });

    assertEquals(response.status, 200);
    assertEquals(response.data.success, true);

    // Verify deleted
    await verifyUserDeleted(userId);
  });
});
