/**
 * E2E Tests for Signup and Onboarding Flow
 *
 * Tests the complete user journey from account creation through onboarding to first conversation.
 * This covers:
 * - Account signup (via Supabase Auth)
 * - Step 1: Name input (call_name)
 * - Step 2: Role and experience (job_role, experience_level)
 * - Step 3: Tone preference (tone_preference)
 * - Self person creation
 * - Initial welcome message generation
 * - First user message to self
 */

import { assertEquals, assertExists } from "@std/assert";
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';
import { makeTestRequest } from "@test-helpers";

const SUPABASE_URL = Deno.env.get('SUPABASE_URL')!;
const SUPABASE_SERVICE_KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;
const SUPABASE_ANON_KEY = Deno.env.get('SUPABASE_ANON_KEY')!;

// Helper to create a unique test user
function generateTestUser() {
  const timestamp = Date.now();
  return {
    email: `test-onboarding-${timestamp}@example.com`,
    password: 'test-password-123456'
  };
}

// Helper to clean up test user
async function cleanupTestUser(userId: string) {
  const adminClient = createClient(SUPABASE_URL, SUPABASE_SERVICE_KEY);
  await adminClient.auth.admin.deleteUser(userId);
}

Deno.test("Complete Onboarding Flow", async (t) => {
  let testUserId: string | null = null;
  let authToken: string | null = null;

  try {
    await t.step("Step 0: User signs up with email and password", async () => {
      const adminClient = createClient(SUPABASE_URL, SUPABASE_SERVICE_KEY);
      const testUser = generateTestUser();

      // Create user account
      const { data: authData, error: signUpError } = await adminClient.auth.admin.createUser({
        email: testUser.email,
        password: testUser.password,
        email_confirm: true
      });

      assertEquals(signUpError, null, 'Signup should succeed');
      assertExists(authData.user, 'User should be created');
      testUserId = authData.user!.id;

      // Sign in to get auth token
      const userClient = createClient(SUPABASE_URL, SUPABASE_ANON_KEY);
      const { data: signInData, error: signInError } = await userClient.auth.signInWithPassword({
        email: testUser.email,
        password: testUser.password
      });

      assertEquals(signInError, null, 'Sign in should succeed');
      assertExists(signInData.session, 'Session should be created');
      authToken = signInData.session!.access_token;

      // Verify user profile was created (via database trigger)
      const { data: profile } = await adminClient
        .from('user_profiles')
        .select('*')
        .eq('user_id', testUserId)
        .single();

      assertExists(profile, 'User profile should be auto-created');
      assertEquals(profile.onboarding_completed, false, 'Onboarding should not be complete yet');
      assertEquals(profile.onboarding_step, 0, 'Should start at step 0');
    });

    await t.step("Step 1: User provides their name", async () => {
      const response = await makeTestRequest('/user-profile-foundation', 'PUT', {
        call_name: 'Taylor',
        onboarding_step: 1
      }, {
        'Authorization': `Bearer ${authToken}`
      });

      assertEquals(response.status, 200);
      assertEquals(response.data.success, true);
      assertEquals(response.data.profile.call_name, 'Taylor');
      assertEquals(response.data.profile.onboarding_step, 1);
      assertEquals(response.data.onboarding_completed, false, 'Onboarding not complete after step 1');
    });

    await t.step("Step 2: User provides role and experience level", async () => {
      const response = await makeTestRequest('/user-profile-foundation', 'PUT', {
        call_name: 'Taylor',
        job_role: 'Engineering Manager',
        experience_level: 'intermediate',
        onboarding_step: 2
      }, {
        'Authorization': `Bearer ${authToken}`
      });

      assertEquals(response.status, 200);
      assertEquals(response.data.success, true);
      assertEquals(response.data.profile.job_role, 'Engineering Manager');
      assertEquals(response.data.profile.experience_level, 'intermediate');
      assertEquals(response.data.profile.onboarding_step, 2);
      assertEquals(response.data.onboarding_completed, false, 'Onboarding not complete after step 2');
    });

    await t.step("Step 3: User selects tone preference and completes onboarding", async () => {
      const response = await makeTestRequest('/user-profile-foundation', 'PUT', {
        call_name: 'Taylor',
        job_role: 'Engineering Manager',
        experience_level: 'intermediate',
        tone_preference: 'balanced',
        onboarding_step: 3
      }, {
        'Authorization': `Bearer ${authToken}`
      });

      assertEquals(response.status, 200);
      assertEquals(response.data.success, true);
      assertEquals(response.data.profile.tone_preference, 'balanced');
      assertEquals(response.data.profile.onboarding_step, 3);
      assertEquals(response.data.onboarding_completed, true, 'Onboarding should be complete after step 3');
      assertEquals(response.data.message, 'Onboarding completed successfully');
    });

    await t.step("Verify self person was created and updated with user info", async () => {
      const adminClient = createClient(SUPABASE_URL, SUPABASE_SERVICE_KEY);

      // Small delay to ensure database operations complete
      await new Promise(resolve => setTimeout(resolve, 1000));

      const { data: selfPerson } = await adminClient
        .from('people')
        .select('*')
        .eq('user_id', testUserId!)
        .eq('is_self', true)
        .single();

      assertExists(selfPerson, 'Self person should be created');
      assertEquals(selfPerson.name, 'Taylor', 'Self person should have user name');
      assertEquals(selfPerson.role, 'Engineering Manager', 'Self person should have user role');
      assertEquals(selfPerson.relationship_type, 'self');
      assertEquals(selfPerson.is_self, true);
    });

    await t.step("Verify initial welcome message was generated for self person", async () => {
      const adminClient = createClient(SUPABASE_URL, SUPABASE_SERVICE_KEY);

      // Wait for initial message generation
      await new Promise(resolve => setTimeout(resolve, 2000));

      const { data: selfPerson } = await adminClient
        .from('people')
        .select('id')
        .eq('user_id', testUserId!)
        .eq('is_self', true)
        .single();

      assertExists(selfPerson, 'Self person should exist');

      // Check for welcome message
      const { data: messages } = await adminClient
        .from('messages')
        .select('*')
        .eq('person_id', selfPerson.id)
        .eq('is_user', false)
        .order('created_at', { ascending: true });

      assertExists(messages, 'Messages should exist');
      assertEquals(messages.length > 0, true, 'Should have at least one welcome message');

      // Verify message content is appropriate for self-reflection
      const welcomeMessage = messages[0];
      assertExists(welcomeMessage.content);
      assertEquals(welcomeMessage.is_user, false);
    });

    await t.step("User sends first message to self for reflection", async () => {
      const adminClient = createClient(SUPABASE_URL, SUPABASE_SERVICE_KEY);

      const { data: selfPerson } = await adminClient
        .from('people')
        .select('id')
        .eq('user_id', testUserId!)
        .eq('is_self', true)
        .single();

      assertExists(selfPerson);

      const response = await makeTestRequest('/chat', 'POST', {
        message: 'What should I focus on as a new engineering manager?',
        person_id: selfPerson.id
      }, {
        'Authorization': `Bearer ${authToken}`
      });

      assertEquals(response.status, 200);

      // Wait for message to be saved
      await new Promise(resolve => setTimeout(resolve, 2000));

      // Verify user message was saved
      const { data: userMessages } = await adminClient
        .from('messages')
        .select('*')
        .eq('person_id', selfPerson.id)
        .eq('is_user', true);

      assertExists(userMessages);
      assertEquals(userMessages.length > 0, true, 'User message should be saved');

      // Verify AI response was generated
      const { data: aiMessages } = await adminClient
        .from('messages')
        .select('*')
        .eq('person_id', selfPerson.id)
        .eq('is_user', false)
        .order('created_at', { ascending: false })
        .limit(1);

      assertExists(aiMessages);
      assertEquals(aiMessages.length > 0, true, 'AI response should be generated');
    });

  } finally {
    // Cleanup: Delete test user and all related data
    if (testUserId) {
      await cleanupTestUser(testUserId);
    }
  }
});

Deno.test("Onboarding Edge Cases", async (t) => {
  let testUserId: string | null = null;
  let authToken: string | null = null;

  try {
    await t.step("Setup: Create test user", async () => {
      const adminClient = createClient(SUPABASE_URL, SUPABASE_SERVICE_KEY);
      const testUser = generateTestUser();

      const { data: authData } = await adminClient.auth.admin.createUser({
        email: testUser.email,
        password: testUser.password,
        email_confirm: true
      });

      testUserId = authData!.user!.id;

      const userClient = createClient(SUPABASE_URL, SUPABASE_ANON_KEY);
      const { data: signInData } = await userClient.auth.signInWithPassword({
        email: testUser.email,
        password: testUser.password
      });

      authToken = signInData!.session!.access_token;
    });

    await t.step("Should reject onboarding without call_name", async () => {
      const response = await makeTestRequest('/user-profile-foundation', 'PUT', {
        job_role: 'Engineer'
      }, {
        'Authorization': `Bearer ${authToken}`
      });

      assertEquals(response.status, 400);
      assertExists(response.data.error);
      assertEquals(response.data.error, 'call_name is required');
    });

    await t.step("Should allow partial updates (progressive onboarding)", async () => {
      // Update only call_name
      const response1 = await makeTestRequest('/user-profile-foundation', 'PUT', {
        call_name: 'Sam',
        onboarding_step: 1
      }, {
        'Authorization': `Bearer ${authToken}`
      });

      assertEquals(response1.status, 200);
      assertEquals(response1.data.profile.call_name, 'Sam');
      assertEquals(response1.data.onboarding_completed, false);

      // Add job_role later
      const response2 = await makeTestRequest('/user-profile-foundation', 'PUT', {
        call_name: 'Sam',
        job_role: 'Product Manager',
        experience_level: 'beginner',
        onboarding_step: 2
      }, {
        'Authorization': `Bearer ${authToken}`
      });

      assertEquals(response2.status, 200);
      assertEquals(response2.data.profile.call_name, 'Sam');
      assertEquals(response2.data.profile.job_role, 'Product Manager');
      assertEquals(response2.data.onboarding_completed, false);
    });

    await t.step("Should handle different tone preference options", async () => {
      const toneOptions = ['direct', 'balanced', 'gentle'];

      for (const tone of toneOptions) {
        const response = await makeTestRequest('/user-profile-foundation', 'PUT', {
          call_name: 'Sam',
          job_role: 'Product Manager',
          experience_level: 'beginner',
          tone_preference: tone,
          onboarding_step: 3
        }, {
          'Authorization': `Bearer ${authToken}`
        });

        assertEquals(response.status, 200);
        assertEquals(response.data.profile.tone_preference, tone);
      }
    });

    await t.step("Should handle different experience levels", async () => {
      const experienceLevels = ['beginner', 'intermediate', 'experienced'];

      for (const level of experienceLevels) {
        const response = await makeTestRequest('/user-profile-foundation', 'PUT', {
          call_name: 'Sam',
          job_role: 'Product Manager',
          experience_level: level,
          tone_preference: 'balanced',
          onboarding_step: 3
        }, {
          'Authorization': `Bearer ${authToken}`
        });

        assertEquals(response.status, 200);
        assertEquals(response.data.profile.experience_level, level);
      }
    });

    await t.step("Should handle optional communication_style field", async () => {
      // With communication_style
      const response1 = await makeTestRequest('/user-profile-foundation', 'PUT', {
        call_name: 'Sam',
        job_role: 'Product Manager',
        experience_level: 'intermediate',
        tone_preference: 'balanced',
        communication_style: 'I prefer clear, actionable advice',
        onboarding_step: 3
      }, {
        'Authorization': `Bearer ${authToken}`
      });

      assertEquals(response1.status, 200);
      assertEquals(response1.data.profile.communication_style, 'I prefer clear, actionable advice');

      // Without communication_style (should still work)
      const response2 = await makeTestRequest('/user-profile-foundation', 'PUT', {
        call_name: 'Sam',
        job_role: 'Product Manager',
        experience_level: 'intermediate',
        tone_preference: 'balanced',
        onboarding_step: 3
      }, {
        'Authorization': `Bearer ${authToken}`
      });

      assertEquals(response2.status, 200);
      assertEquals(response2.data.onboarding_completed, true);
    });

  } finally {
    if (testUserId) {
      await cleanupTestUser(testUserId);
    }
  }
});

Deno.test("Onboarding Authentication & Security", async (t) => {
  await t.step("Should reject requests without authorization", async () => {
    const response = await makeTestRequest('/user-profile-foundation', 'PUT', {
      call_name: 'Test'
    });

    assertEquals(response.status, 401);
    assertExists(response.data.error);
    assertEquals(response.data.error, 'Authorization header is required');
  });

  await t.step("Should reject invalid HTTP methods", async () => {
    const response = await makeTestRequest('/user-profile-foundation', 'GET', null, {
      'Authorization': 'Bearer test-token'
    });

    assertEquals(response.status, 405);
    assertEquals(response.data.error, 'Method not allowed');
  });

  await t.step("Should handle CORS preflight", async () => {
    const response = await makeTestRequest('/user-profile-foundation', 'OPTIONS');

    assertEquals(response.status, 200);
    assertExists(response.headers.get('Access-Control-Allow-Origin'));
  });
});
