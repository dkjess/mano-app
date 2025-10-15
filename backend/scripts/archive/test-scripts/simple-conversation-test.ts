#!/usr/bin/env -S npx tsx

/**
 * Simple test to verify conversation creation via chat API
 */

import { createClient } from '@supabase/supabase-js';

const SUPABASE_URL = 'http://127.0.0.1:54321';
const SUPABASE_ANON_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZS1kZW1vIiwicm9sZSI6ImFub24iLCJleHAiOjE5ODM4MTI5OTZ9.CRXP1A7WOeoJeXxjNni43kdQwgnWNReilDMblYTn_I0';
const TEST_EMAIL = 'dev@mano.local';
const TEST_PASSWORD = 'dev123456';

async function main() {
  console.log('🧪 Simple conversation test...\n');

  const client = createClient(SUPABASE_URL, SUPABASE_ANON_KEY);

  // 1. Authenticate
  const { data: authData, error: authError } = await client.auth.signInWithPassword({
    email: TEST_EMAIL,
    password: TEST_PASSWORD,
  });

  if (authError || !authData.session) {
    console.error('❌ Auth failed:', authError);
    return;
  }

  console.log('✅ Authenticated successfully');

  // 2. Get a person to chat with
  const { data: people } = await client
    .from('people')
    .select('*')
    .limit(1);

  if (!people || people.length === 0) {
    console.error('❌ No people found');
    return;
  }

  const person = people[0];
  console.log(`✅ Found person: ${person.name}`);

  // 3. Check database state BEFORE
  const { data: conversationsBefore } = await client
    .from('conversations')
    .select('*')
    .eq('person_id', person.id);

  const { data: messagesBefore } = await client
    .from('messages')
    .select('*')
    .eq('person_id', person.id);

  console.log(`📊 BEFORE: ${conversationsBefore?.length || 0} conversations, ${messagesBefore?.length || 0} messages`);

  // 4. Send a test message via chat API
  console.log('\n📤 Sending test message via chat API...');

  try {
    const response = await fetch(`${SUPABASE_URL}/functions/v1/chat`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${authData.session.access_token}`,
        'apikey': SUPABASE_ANON_KEY,
      },
      body: JSON.stringify({
        message: 'How can I help this person grow in their role?',
        person_id: person.id
      })
    });

    if (response.ok) {
      console.log('✅ Chat API call successful');
    } else {
      const error = await response.text();
      console.log(`⚠️ Chat API error: ${response.status} - ${error}`);
    }
  } catch (error) {
    console.log(`⚠️ Chat API exception: ${error}`);
  }

  // 5. Wait a moment for async operations
  console.log('⏳ Waiting for background operations...');
  await new Promise(resolve => setTimeout(resolve, 3000));

  // 6. Check database state AFTER
  const { data: conversationsAfter } = await client
    .from('conversations')
    .select('*')
    .eq('person_id', person.id);

  const { data: messagesAfter } = await client
    .from('messages')
    .select('*')
    .eq('person_id', person.id);

  console.log(`📊 AFTER: ${conversationsAfter?.length || 0} conversations, ${messagesAfter?.length || 0} messages`);

  // 7. Show conversation details
  if (conversationsAfter && conversationsAfter.length > 0) {
    console.log('\n💬 Conversation details:');
    conversationsAfter.forEach(conv => {
      console.log(`   - ${conv.id} (active: ${conv.is_active}, title: ${conv.title || 'No title'})`);
    });
  }

  // 8. Show recent messages with conversation_id
  if (messagesAfter && messagesAfter.length > 0) {
    console.log('\n📨 Recent messages:');
    messagesAfter
      .filter(msg => msg.conversation_id)
      .slice(-3)
      .forEach(msg => {
        const userType = msg.is_user ? 'USER' : 'AI';
        const preview = msg.content.substring(0, 40);
        console.log(`   - [${userType}] "${preview}..." (conv: ${msg.conversation_id})`);
      });
  }

  console.log('\n🎉 Simple test complete!');
}

if (import.meta.main) {
  main().catch(console.error);
}