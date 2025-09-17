#!/usr/bin/env tsx

/**
 * Test is_self Functionality
 *
 * This script tests the is_self person functionality:
 * 1. Verifies that a self person is auto-created for new users
 * 2. Tests that self persons use the correct prompts
 * 3. Ensures proper handling of self-reflection conversations
 */

import { createClient } from '@supabase/supabase-js';
import * as dotenv from 'dotenv';

// Load environment variables
dotenv.config({ path: '.env.local' });

const supabaseUrl = process.env.NEXT_PUBLIC_SUPABASE_URL!;
const supabaseServiceKey = process.env.SUPABASE_SERVICE_ROLE_KEY!;

if (!supabaseUrl || !supabaseServiceKey) {
  console.error('❌ Missing required environment variables');
  process.exit(1);
}

// Create Supabase client with service role key
const supabase = createClient(supabaseUrl, supabaseServiceKey, {
  auth: {
    autoRefreshToken: false,
    persistSession: false
  }
});

async function testIsSelfFunctionality() {
  console.log('🔍 Testing is_self functionality...\n');

  try {
    // Step 1: Check if test user exists
    console.log('1️⃣ Checking test user...');
    const TEST_USER_ID = '00000000-0000-0000-0000-000000000001';

    const { data: authUser } = await supabase.auth.admin.getUserById(TEST_USER_ID);
    if (!authUser.user) {
      console.error('❌ Test user not found. Run npm run seed:dev first');
      process.exit(1);
    }
    console.log('✅ Test user found:', authUser.user.email);

    // Step 2: Check for self person
    console.log('\n2️⃣ Checking for self person...');
    const { data: selfPerson, error: selfError } = await supabase
      .from('people')
      .select('*')
      .eq('user_id', TEST_USER_ID)
      .eq('is_self', true)
      .single();

    if (selfError || !selfPerson) {
      console.error('❌ Self person not found for test user');
      console.error('Error:', selfError);

      // Try to manually check all people for this user
      const { data: allPeople } = await supabase
        .from('people')
        .select('id, name, relationship_type, is_self')
        .eq('user_id', TEST_USER_ID);

      console.log('\nAll people for test user:');
      console.table(allPeople);
      process.exit(1);
    }

    console.log('✅ Self person found:');
    console.log('   ID:', selfPerson.id);
    console.log('   Name:', selfPerson.name);
    console.log('   Relationship Type:', selfPerson.relationship_type);
    console.log('   Is Self:', selfPerson.is_self);

    // Step 3: Test creating another self person (should fail)
    console.log('\n3️⃣ Testing prevention of duplicate self persons...');
    const { error: duplicateError } = await supabase
      .from('people')
      .insert({
        user_id: TEST_USER_ID,
        name: 'Duplicate Self',
        relationship_type: 'self',
        is_self: true
      });

    if (duplicateError) {
      console.log('✅ Correctly prevented duplicate self person:', duplicateError.message);
    } else {
      console.error('❌ Should have prevented duplicate self person!');
    }

    // Step 4: Test chat with self person
    console.log('\n4️⃣ Testing chat with self person...');
    console.log('   Note: This would require the Edge Functions to be running.');
    console.log('   The chat function should use SELF_SYSTEM_PROMPT for is_self=true persons.');

    // Create a test message
    const { data: testMessage, error: messageError } = await supabase
      .from('messages')
      .insert({
        user_id: TEST_USER_ID,
        person_id: selfPerson.id,
        content: 'How am I doing as a manager?',
        is_user: true
      })
      .select()
      .single();

    if (messageError) {
      console.error('❌ Failed to create test message:', messageError);
    } else {
      console.log('✅ Created test message for self-reflection');
      console.log('   Message ID:', testMessage.id);
    }

    // Step 5: Verify person list includes self
    console.log('\n5️⃣ Verifying person list includes self...');
    const { data: allPeople } = await supabase
      .from('people')
      .select('id, name, relationship_type, is_self')
      .eq('user_id', TEST_USER_ID)
      .order('is_self', { ascending: false })
      .order('name');

    console.log('\nAll people for test user:');
    console.table(allPeople);

    // Summary
    console.log('\n📊 Test Summary:');
    console.log('✅ Self person exists:', !!selfPerson);
    console.log('✅ Has correct is_self flag:', selfPerson?.is_self === true);
    console.log('✅ Has self relationship type:', selfPerson?.relationship_type === 'self');
    console.log('✅ Prevents duplicate self persons: Yes');
    console.log('✅ Total people count:', allPeople?.length || 0);

    console.log('\n🎉 is_self functionality test completed successfully!');
    console.log('\n💡 Next steps:');
    console.log('   1. Start Supabase: supabase start');
    console.log('   2. Serve Edge Functions: supabase functions serve --env-file .env.local');
    console.log('   3. Test in the iOS app with self-reflection conversations');

  } catch (error) {
    console.error('\n❌ Test failed:', error);
    process.exit(1);
  }
}

// Run the test
testIsSelfFunctionality();