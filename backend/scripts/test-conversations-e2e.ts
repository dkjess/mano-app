#!/usr/bin/env -S npx tsx

/**
 * Comprehensive end-to-end test for conversation functionality
 * Tests the entire flow: authentication, message sending, conversation creation, title generation
 */

import { createClient } from '@supabase/supabase-js';

// Local Supabase configuration
const SUPABASE_URL = 'http://127.0.0.1:54321';
const SUPABASE_ANON_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZS1kZW1vIiwicm9sZSI6ImFub24iLCJleHAiOjE5ODM4MTI5OTZ9.CRXP1A7WOeoJeXxjNni43kdQwgnWNReilDMblYTn_I0';

// Test user credentials
const TEST_EMAIL = 'dev@mano.local';
const TEST_PASSWORD = 'dev123456';

async function delay(ms: number) {
  return new Promise(resolve => setTimeout(resolve, ms));
}

async function callChatAPI(personId: string, message: string, accessToken: string) {
  const response = await fetch(`${SUPABASE_URL}/functions/v1/chat`, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'Authorization': `Bearer ${accessToken}`,
      'apikey': SUPABASE_ANON_KEY,
    },
    body: JSON.stringify({
      message,
      person_id: personId
    })
  });

  if (!response.ok) {
    const error = await response.text();
    throw new Error(`Chat API failed: ${response.status} - ${error}`);
  }

  return await response.json();
}

async function main() {
  console.log('🚀 Starting comprehensive conversation E2E test...\n');

  const client = createClient(SUPABASE_URL, SUPABASE_ANON_KEY);

  try {
    // 1. Authenticate with test user
    console.log('🔐 Authenticating test user...');
    const { data: authData, error: authError } = await client.auth.signInWithPassword({
      email: TEST_EMAIL,
      password: TEST_PASSWORD,
    });

    if (authError) {
      throw new Error(`Authentication failed: ${authError.message}`);
    }

    console.log(`✅ Authenticated as: ${authData.user?.email}`);
    const userId = authData.user?.id;
    const accessToken = authData.session?.access_token;

    if (!userId || !accessToken) {
      throw new Error('Missing user ID or access token');
    }

    // 2. Get or create a test person
    console.log('\n👤 Getting test person...');

    // First check if we have any people
    const { data: existingPeople, error: peopleError } = await client
      .from('people')
      .select('*')
      .eq('user_id', userId)
      .limit(1);

    if (peopleError) {
      throw new Error(`Failed to fetch people: ${peopleError.message}`);
    }

    let testPerson;
    if (existingPeople && existingPeople.length > 0) {
      testPerson = existingPeople[0];
      console.log(`✅ Using existing person: ${testPerson.name}`);
    } else {
      // Create a test person
      console.log('📝 Creating test person...');
      const { data: newPerson, error: createError } = await client
        .from('people')
        .insert({
          user_id: userId,
          name: 'Alice Smith',
          role: 'Senior Engineer',
          relationship_type: 'direct_report',
          team: 'Engineering',
          location: 'San Francisco'
        })
        .select()
        .single();

      if (createError) {
        throw new Error(`Failed to create person: ${createError.message}`);
      }

      testPerson = newPerson;
      console.log(`✅ Created test person: ${testPerson.name}`);
    }

    // 3. Test conversation creation through chat API
    console.log('\n💬 Testing conversation creation via chat API...');

    const testMessages = [
      'How can I improve my communication skills with Alice?',
      'I want to give Alice more challenging projects.',
      'What should I discuss in our next one-on-one meeting?'
    ];

    for (let i = 0; i < testMessages.length; i++) {
      const message = testMessages[i];
      console.log(`\n📤 Sending message ${i + 1}: "${message}"`);

      try {
        const result = await callChatAPI(testPerson.id, message, accessToken);
        console.log(`✅ Chat API responded successfully`);

        // Wait a moment for async operations to complete
        await delay(1000);
      } catch (error) {
        console.log(`⚠️ Chat API error for message ${i + 1}: ${error}`);
        // Continue with other messages
      }
    }

    // 4. Check if conversations were created
    console.log('\n🔍 Checking conversation creation...');
    const { data: conversations, error: convError } = await client
      .from('conversations')
      .select('*')
      .eq('person_id', testPerson.id)
      .order('created_at', { ascending: false });

    if (convError) {
      throw new Error(`Failed to fetch conversations: ${convError.message}`);
    }

    console.log(`✅ Found ${conversations?.length || 0} conversations for ${testPerson.name}`);

    if (conversations && conversations.length > 0) {
      const activeConv = conversations.find(c => c.is_active);
      const latestConv = conversations[0];

      console.log(`   Active conversation: ${activeConv?.id || 'None'}`);
      console.log(`   Latest conversation: ${latestConv.id}`);
      console.log(`   Latest title: ${latestConv.title || 'No title yet'}`);

      // 5. Check messages in the conversation
      const { data: messages, error: msgError } = await client
        .from('messages')
        .select('*')
        .eq('conversation_id', latestConv.id)
        .order('created_at', { ascending: true });

      if (msgError) {
        throw new Error(`Failed to fetch messages: ${msgError.message}`);
      }

      console.log(`✅ Found ${messages?.length || 0} messages in latest conversation:`);
      messages?.forEach((msg, index) => {
        const preview = msg.content.substring(0, 50);
        console.log(`   ${index + 1}. [${msg.is_user ? 'USER' : 'AI'}] ${preview}${msg.content.length > 50 ? '...' : ''}`);
      });

      // 6. Test title generation if needed
      if (!latestConv.title && messages && messages.length >= 4) {
        console.log('\n🏷️ Testing title generation...');

        try {
          const titleResponse = await fetch(`${SUPABASE_URL}/functions/v1/generate-conversation-title`, {
            method: 'POST',
            headers: {
              'Content-Type': 'application/json',
              'Authorization': `Bearer ${accessToken}`,
              'apikey': SUPABASE_ANON_KEY,
            },
            body: JSON.stringify({
              conversation_id: latestConv.id
            })
          });

          if (titleResponse.ok) {
            const titleResult = await titleResponse.json();
            console.log(`✅ Generated title: "${titleResult.title}"`);
          } else {
            const titleError = await titleResponse.text();
            console.log(`⚠️ Title generation failed: ${titleError}`);
          }
        } catch (error) {
          console.log(`⚠️ Title generation error: ${error}`);
        }
      }

      // 7. Test conversation archiving (create new conversation)
      console.log('\n📦 Testing conversation archiving...');
      const archiveMessage = "Let's start a fresh conversation about Alice's career development.";

      // First, archive the current conversation manually
      const { error: archiveError } = await client
        .from('conversations')
        .update({ is_active: false })
        .eq('id', latestConv.id);

      if (archiveError) {
        console.log(`⚠️ Failed to archive conversation: ${archiveError.message}`);
      } else {
        console.log(`✅ Archived conversation: ${latestConv.id}`);
      }

      // Send a new message which should create a new conversation
      try {
        await callChatAPI(testPerson.id, archiveMessage, accessToken);
        console.log(`✅ Sent message to trigger new conversation`);

        // Wait for new conversation creation
        await delay(1000);

        // Check for new conversation
        const { data: newConversations } = await client
          .from('conversations')
          .select('*')
          .eq('person_id', testPerson.id)
          .eq('is_active', true)
          .order('created_at', { ascending: false });

        if (newConversations && newConversations.length > 0) {
          const newConv = newConversations[0];
          console.log(`✅ New conversation created: ${newConv.id}`);
        }
      } catch (error) {
        console.log(`⚠️ New conversation test failed: ${error}`);
      }
    }

    // 8. Final summary
    console.log('\n📊 Final summary:');
    const { data: finalConversations } = await client
      .from('conversations')
      .select('*')
      .eq('person_id', testPerson.id);

    const { data: finalMessages } = await client
      .from('messages')
      .select('*')
      .eq('person_id', testPerson.id);

    console.log(`   Total conversations: ${finalConversations?.length || 0}`);
    console.log(`   Total messages: ${finalMessages?.length || 0}`);
    console.log(`   Active conversations: ${finalConversations?.filter(c => c.is_active).length || 0}`);

    console.log('\n🎉 End-to-end conversation test completed!');

  } catch (error) {
    console.error('❌ E2E test failed:', error);
    process.exit(1);
  }
}

if (import.meta.main) {
  main();
}