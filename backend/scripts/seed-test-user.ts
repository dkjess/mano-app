#!/usr/bin/env tsx

/**
 * Seed Test User Script
 * 
 * Creates a test user with sample data for local development and testing.
 * This allows developers to test chat functionality and other authenticated features.
 */

import { createClient } from '@supabase/supabase-js';
import * as dotenv from 'dotenv';

// Load environment variables
dotenv.config({ path: '.env.local' });

const supabaseUrl = process.env.NEXT_PUBLIC_SUPABASE_URL!;
const supabaseServiceKey = process.env.SUPABASE_SERVICE_ROLE_KEY!;

if (!supabaseUrl || !supabaseServiceKey) {
  console.error('❌ Missing required environment variables:');
  console.error('   NEXT_PUBLIC_SUPABASE_URL');
  console.error('   SUPABASE_SERVICE_ROLE_KEY');
  process.exit(1);
}

// Create Supabase client with service role key (bypasses RLS)
const supabase = createClient(supabaseUrl, supabaseServiceKey, {
  auth: {
    autoRefreshToken: false,
    persistSession: false
  }
});

// Test user credentials
const TEST_USER = {
  email: 'dev@mano.local',
  password: 'dev123456',
  name: 'Dev User',
  id: '00000000-0000-0000-0000-000000000001' // Fixed UUID for consistency
};

// Sample people data (self person is created automatically)
const SAMPLE_PEOPLE = [
  {
    name: 'Alice Johnson',
    role: 'Senior Engineer',
    relationship_type: 'direct_report',
    notes: 'Strong technical skills, working on React migration project.'
  },
  {
    name: 'Bob Chen',
    role: 'Product Manager',
    relationship_type: 'peer',
    notes: 'Great at stakeholder management, very collaborative.'
  },
  {
    name: 'Carol Martinez',
    role: 'Engineering Manager',
    relationship_type: 'manager',
    notes: 'My direct manager, very supportive of career growth.'
  }
];

// Sample topics
const SAMPLE_TOPICS = [
  {
    title: 'Team Strategy Discussion'
  },
  {
    title: 'Performance Review Prep'
  }
];

async function seedTestUser() {
  console.log('🌱 Starting test user seed process...\n');

  try {
    // Step 1: Create test user account
    console.log('1️⃣ Creating test user account...');
    
    // First check if user already exists
    const { data: existingUser } = await supabase.auth.admin.getUserById(TEST_USER.id);
    
    if (existingUser.user) {
      console.log('   ✅ Test user already exists, skipping creation');

      // Ensure user profile exists
      const { data: profile } = await supabase
        .from('user_profiles')
        .select('*')
        .eq('user_id', TEST_USER.id)
        .single();

      if (!profile) {
        await supabase
          .from('user_profiles')
          .insert({
            user_id: TEST_USER.id,
            preferred_name: TEST_USER.name,
            call_name: 'Dev',
            job_role: 'Engineering Manager',
            company: 'Test Company'
          });
        console.log('   ✅ Created user profile');
      }
    } else {
      const { data: authData, error: authError } = await supabase.auth.admin.createUser({
        id: TEST_USER.id,
        email: TEST_USER.email,
        password: TEST_USER.password,
        email_confirm: true, // Auto-confirm email for local dev
        user_metadata: {
          name: TEST_USER.name
        }
      });

      if (authError) {
        throw new Error(`Failed to create user: ${authError.message}`);
      }

      console.log(`   ✅ Created test user: ${TEST_USER.email}`);

      // Ensure self person is created (in case trigger doesn't fire)
      console.log('   🔄 Ensuring self person exists...');
      const { data: selfPerson } = await supabase
        .from('people')
        .select('id, name')
        .eq('user_id', TEST_USER.id)
        .eq('is_self', true)
        .single();

      if (!selfPerson) {
        // Create self person manually
        const { data: newSelf, error: selfError } = await supabase
          .from('people')
          .insert({
            user_id: TEST_USER.id,
            name: TEST_USER.name,
            relationship_type: 'self',
            is_self: true
          })
          .select()
          .single();

        if (selfError) {
          console.warn('   ⚠️ Could not create self person:', selfError.message);
        } else {
          console.log('   ✅ Created self person:', newSelf.name);

          // Create welcome message for self-reflection
          await supabase
            .from('messages')
            .insert({
              user_id: TEST_USER.id,
              person_id: newSelf.id,
              content: `Welcome to your self-reflection space, ${TEST_USER.name}! This is where you can explore your thoughts about leadership, management challenges, and personal growth. What's on your mind today?`,
              is_user: false
            });
        }
      } else {
        console.log('   ✅ Self person already exists:', selfPerson.name);
      }

      // Ensure user profile exists
      const { data: profile } = await supabase
        .from('user_profiles')
        .select('*')
        .eq('user_id', TEST_USER.id)
        .single();

      if (!profile) {
        await supabase
          .from('user_profiles')
          .insert({
            user_id: TEST_USER.id,
            preferred_name: TEST_USER.name,
            call_name: 'Dev',
            job_role: 'Engineering Manager',
            company: 'Test Company'
          });
        console.log('   ✅ Created user profile');
      }
    }

    // Step 2: Create sample people
    console.log('\n2️⃣ Creating sample people...');
    
    // Check if people already exist
    const { data: existingPeople } = await supabase
      .from('people')
      .select('id')
      .eq('user_id', TEST_USER.id);

    if (existingPeople && existingPeople.length > 0) {
      console.log('   ✅ Sample people already exist, skipping creation');

    // Always ensure self person exists
    const { data: selfCheck } = await supabase
      .from('people')
      .select('id')
      .eq('user_id', TEST_USER.id)
      .eq('is_self', true)
      .single();

    if (!selfCheck) {
      const { error: selfError } = await supabase
        .from('people')
        .insert({
          user_id: TEST_USER.id,
          name: TEST_USER.name,
          relationship_type: 'self',
          is_self: true
        });

      if (!selfError) {
        console.log('   ✅ Created missing self person');
      }
    }
    } else {
      const peopleToInsert = SAMPLE_PEOPLE.map(person => ({
        ...person,
        user_id: TEST_USER.id
      }));

      const { data: people, error: peopleError } = await supabase
        .from('people')
        .insert(peopleToInsert)
        .select();

      if (peopleError) {
        throw new Error(`Failed to create people: ${peopleError.message}`);
      }

      console.log(`   ✅ Created ${people.length} sample people`);
    }

    // Step 3: Create sample topics
    console.log('\n3️⃣ Creating sample topics...');
    
    const { data: existingTopics } = await supabase
      .from('topics')
      .select('id')
      .eq('created_by', TEST_USER.id);

    if (existingTopics && existingTopics.length > 0) {
      console.log('   ✅ Sample topics already exist, skipping creation');
    } else {
      const topicsToInsert = SAMPLE_TOPICS.map(topic => ({
        ...topic,
        created_by: TEST_USER.id
      }));

      const { data: topics, error: topicsError } = await supabase
        .from('topics')
        .insert(topicsToInsert)
        .select();

      if (topicsError) {
        throw new Error(`Failed to create topics: ${topicsError.message}`);
      }

      console.log(`   ✅ Created ${topics.length} sample topics`);
    }

    // Step 4: Create some sample messages with conversations
    console.log('\n4️⃣ Creating sample messages...');

    // Get the first person for sample messages
    const { data: people } = await supabase
      .from('people')
      .select('id, name')
      .eq('user_id', TEST_USER.id)
      .limit(1);

    if (people && people.length > 0) {
      const person = people[0];

      // Check if messages already exist
      const { data: existingMessages } = await supabase
        .from('messages')
        .select('id')
        .eq('person_id', person.id);

      if (existingMessages && existingMessages.length > 0) {
        console.log('   ✅ Sample messages already exist, skipping creation');
      } else {
        // First create a conversation
        const { data: conversation, error: conversationError } = await supabase
          .from('conversations')
          .insert({
            person_id: person.id,
            title: 'Project Status Discussion',
            is_active: true
          })
          .select()
          .single();

        if (conversationError) {
          throw new Error(`Failed to create conversation: ${conversationError.message}`);
        }

        const sampleMessages = [
          {
            content: `Hi ${person.name}, how are things going with the current project?`,
            is_user: true,
            person_id: person.id,
            user_id: TEST_USER.id,
            conversation_id: conversation.id
          },
          {
            content: `Things are going well! We're making good progress on the React migration. I should have the authentication components done by end of week.`,
            is_user: false,
            person_id: person.id,
            user_id: TEST_USER.id,
            conversation_id: conversation.id
          },
          {
            content: `That's great to hear! Let me know if you need any help or have blockers.`,
            is_user: true,
            person_id: person.id,
            user_id: TEST_USER.id,
            conversation_id: conversation.id
          }
        ];

        const { data: messages, error: messagesError } = await supabase
          .from('messages')
          .insert(sampleMessages)
          .select();

        if (messagesError) {
          throw new Error(`Failed to create messages: ${messagesError.message}`);
        }

        console.log(`   ✅ Created conversation and ${messages.length} sample messages`);
      }
    }

    console.log('\n🎉 Test user seed completed successfully!\n');
    console.log('📋 Test User Credentials:');
    console.log(`   Email: ${TEST_USER.email}`);
    console.log(`   Password: ${TEST_USER.password}`);
    console.log('\n💡 You can now log in with these credentials to test the application.');
    console.log('🔄 To reset test data, delete the user from Supabase Auth and run this script again.');

  } catch (error) {
    console.error('\n❌ Seed process failed:', error);
    process.exit(1);
  }
}

// Reset function to clean up test data
async function resetTestUser() {
  console.log('🧹 Resetting test user data...\n');

  try {
    // Delete auth user (this will cascade to related data due to foreign keys)
    const { error: deleteError } = await supabase.auth.admin.deleteUser(TEST_USER.id);
    
    if (deleteError && deleteError.message !== 'User not found') {
      throw new Error(`Failed to delete user: ${deleteError.message}`);
    }

    console.log('✅ Test user data reset complete');
    console.log('💡 Run the seed script again to recreate test data');

  } catch (error) {
    console.error('❌ Reset failed:', error);
    process.exit(1);
  }
}

// Main execution
async function main() {
  const command = process.argv[2];

  if (command === 'reset') {
    await resetTestUser();
  } else {
    await seedTestUser();
  }

  process.exit(0);
}

// Run if this is the main module (ES module compatible)
if (import.meta.url === `file://${process.argv[1]}`) {
  main();
}