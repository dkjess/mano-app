#!/usr/bin/env -S deno run --allow-net --allow-env

/**
 * Test script for person creation with started_working_together field
 */

const SUPABASE_URL = 'http://127.0.0.1:54321';
const SUPABASE_ANON_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZS1kZW1vIiwicm9sZSI6ImFub24iLCJleHAiOjE5ODM4MTI5OTZ9.CRXP1A7WOeoJeXxjNni43kdQwgnWNReilDMblYTn_I0';

// Test user credentials
const TEST_EMAIL = 'dev@mano.local';
const TEST_PASSWORD = 'dev123456';

async function testPersonCreation() {
  console.log('🧪 Testing Person Creation with started_working_together\n');

  try {
    // Step 1: Sign in to get a valid JWT
    console.log('1️⃣ Signing in as test user...');
    const signInResponse = await fetch(`${SUPABASE_URL}/auth/v1/token?grant_type=password`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'apikey': SUPABASE_ANON_KEY,
      },
      body: JSON.stringify({
        email: TEST_EMAIL,
        password: TEST_PASSWORD,
      }),
    });

    if (!signInResponse.ok) {
      const error = await signInResponse.text();
      throw new Error(`Sign in failed: ${error}`);
    }

    const signInData = await signInResponse.json();
    const accessToken = signInData.access_token;
    console.log('✅ Signed in successfully\n');

    // Step 2: Create a person with started_working_together
    console.log('2️⃣ Creating person with started_working_together field...');
    const personData = {
      name: 'Test Person ' + Date.now(),
      role: 'Operations Manager',
      relationship_type: 'peer',
      generate_initial_message: true,
      started_working_together: '2024-04-01T00:00:00Z', // ISO 8601 format
    };

    console.log('📤 Request data:', JSON.stringify(personData, null, 2));

    const createResponse = await fetch(`${SUPABASE_URL}/functions/v1/person`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${accessToken}`,
        'apikey': SUPABASE_ANON_KEY,
      },
      body: JSON.stringify(personData),
    });

    const responseText = await createResponse.text();
    console.log('\n📥 Response status:', createResponse.status);
    console.log('📥 Response body:', responseText);

    if (!createResponse.ok) {
      throw new Error(`Person creation failed with status ${createResponse.status}: ${responseText}`);
    }

    const responseData = JSON.parse(responseText);
    console.log('\n✅ Person created successfully!');
    console.log('📋 Response structure:');
    console.log('   - person:', responseData.person ? '✓' : '✗');
    console.log('   - initialMessage:', responseData.initialMessage ? '✓' : '✗');
    console.log('   - hasInitialMessage:', responseData.hasInitialMessage);

    if (responseData.person) {
      console.log('\n👤 Person details:');
      console.log('   - id:', responseData.person.id);
      console.log('   - name:', responseData.person.name);
      console.log('   - role:', responseData.person.role);
      console.log('   - relationship_type:', responseData.person.relationship_type);
      console.log('   - started_working_together:', responseData.person.started_working_together);
      console.log('   - created_at:', responseData.person.created_at);
    }

    if (responseData.initialMessage) {
      console.log('\n💬 Initial message:');
      console.log('   - id:', responseData.initialMessage.id);
      console.log('   - content:', responseData.initialMessage.content);
      console.log('   - is_user:', responseData.initialMessage.is_user);
    }

    // Step 3: Verify the person was saved with correct data
    console.log('\n3️⃣ Verifying person in database...');
    const verifyResponse = await fetch(
      `${SUPABASE_URL}/rest/v1/people?id=eq.${responseData.person.id}&select=*`,
      {
        headers: {
          'Authorization': `Bearer ${accessToken}`,
          'apikey': SUPABASE_ANON_KEY,
          'Content-Type': 'application/json',
        },
      }
    );

    const verifyData = await verifyResponse.json();
    if (verifyData && verifyData.length > 0) {
      const person = verifyData[0];
      console.log('✅ Person verified in database');
      console.log('   - started_working_together:', person.started_working_together);

      if (!person.started_working_together) {
        console.error('❌ ERROR: started_working_together field is null in database!');
        Deno.exit(1);
      }
    }

    console.log('\n🎉 All tests passed!');
    Deno.exit(0);

  } catch (error) {
    console.error('\n❌ Test failed:', error.message);
    if (error.stack) {
      console.error('\nStack trace:', error.stack);
    }
    Deno.exit(1);
  }
}

// Run the test
testPersonCreation();
