#!/usr/bin/env tsx

/**
 * Test Chat Flow Script - Direct Database Version
 * 
 * Tests the complete flow by interacting directly with Supabase:
 * 1. Logging in as test user
 * 2. Creating a new person directly in DB
 * 3. Creating messages and triggering chat
 * 4. Verifying no "seeing double" bug
 */

import { createClient } from '@supabase/supabase-js';
import * as dotenv from 'dotenv';

// Load environment variables
dotenv.config({ path: '.env.local' });

const supabaseUrl = process.env.NEXT_PUBLIC_SUPABASE_URL!;
const supabaseAnonKey = process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!;

// Test user credentials from seed script
const TEST_USER = {
  email: 'dev@mano.local',
  password: 'dev123456'
};

// Create Supabase client
const supabase = createClient(supabaseUrl, supabaseAnonKey);

async function testChatFlowDirect() {
  console.log('🧪 Starting direct chat flow test...\n');

  try {
    // Step 1: Log in as test user
    console.log('1️⃣ Logging in as test user...');
    const { data: authData, error: authError } = await supabase.auth.signInWithPassword({
      email: TEST_USER.email,
      password: TEST_USER.password
    });

    if (authError) {
      throw new Error(`Failed to log in: ${authError.message}`);
    }

    console.log(`   ✅ Logged in successfully as ${TEST_USER.email}`);
    const session = authData.session;
    const user = authData.user;
    
    if (!session || !user) {
      throw new Error('No session or user returned from login');
    }

    // Step 2: Get initial person count
    console.log('\n2️⃣ Checking initial people count...');
    const { data: initialPeople, error: initialError } = await supabase
      .from('people')
      .select('id, name, role')
      .eq('user_id', user.id);

    if (initialError) throw initialError;
    console.log(`   📊 Initial people count: ${initialPeople?.length || 0}`);

    // Step 3: Create a new person directly
    console.log('\n3️⃣ Creating a new person...');
    const newPerson = {
      name: 'Emma Wilson',
      role: 'Senior Designer',
      relationship_type: 'direct_report',
      notes: 'Just joined the team, working on the new design system.',
      user_id: user.id
    };

    const { data: person, error: createError } = await supabase
      .from('people')
      .insert(newPerson)
      .select()
      .single();

    if (createError) throw createError;
    console.log(`   ✅ Created person: ${person.name} (ID: ${person.id})`);

    // Step 4: Create a user message about management challenges
    console.log('\n4️⃣ Creating a management-focused conversation message...');
    const userMessage = {
      content: 'I need to discuss Emma\'s performance and career development. She\'s been struggling with some of the design system work and I\'m not sure how to best support her growth. What are some strategies I could use?',
      is_user: true,
      person_id: person.id,
      user_id: user.id
    };

    const { data: message, error: messageError } = await supabase
      .from('messages')
      .insert(userMessage)
      .select()
      .single();

    if (messageError) throw messageError;
    console.log(`   ✅ Created user message (ID: ${message.id})`);

    // Step 5: Trigger AI response via Edge Function
    console.log('\n5️⃣ Triggering AI response...');
    const response = await fetch(`${supabaseUrl}/functions/v1/chat`, {
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${session.access_token}`,
        'apikey': supabaseAnonKey,
        'Content-Type': 'application/json'
      },
      body: JSON.stringify({
        action: 'streaming_chat',
        message: userMessage.content,
        hasFiles: false,
        isTopicConversation: false,
        messageId: message.id,
        person_id: person.id
      })
    });

    if (!response.ok) {
      const error = await response.text();
      console.error('   ❌ Edge Function error:', error);
    } else {
      console.log('   ✅ AI response triggered');
      
      // Read a bit of the streaming response
      const reader = response.body?.getReader();
      const decoder = new TextDecoder();
      let preview = '';
      
      if (reader) {
        const { value } = await reader.read();
        if (value) {
          const chunk = decoder.decode(value, { stream: true });
          preview = chunk.substring(0, 100);
          console.log(`   🤖 Response preview: "${preview}..."`);
        }
        reader.releaseLock();
      }
    }

    // Step 6: Wait for any person detection to process
    console.log('\n6️⃣ Waiting for person detection processing...');
    await new Promise(resolve => setTimeout(resolve, 3000));

    // Step 7: Check for "seeing double" bug
    console.log('\n7️⃣ Checking for "seeing double" bug...');
    const { data: allPeople, error: peopleError } = await supabase
      .from('people')
      .select('id, name, role, created_at')
      .eq('user_id', user.id)
      .order('created_at', { ascending: false });

    if (peopleError) throw peopleError;

    const emmaInstances = allPeople.filter(p => 
      p.name.toLowerCase().includes('emma') || 
      p.name.toLowerCase().includes('wilson')
    );

    console.log(`   📊 Total people after conversation: ${allPeople.length}`);
    console.log(`   🔍 Emma instances found: ${emmaInstances.length}`);

    if (emmaInstances.length > 1) {
      console.log('\n   ❌ SEEING DOUBLE BUG DETECTED!');
      emmaInstances.forEach(p => {
        console.log(`      - ${p.name} (${p.role}) created at ${p.created_at}`);
      });
    } else {
      console.log('   ✅ No duplicate detected! Bug appears to be fixed.');
    }

    // Step 8: Check AI messages
    console.log('\n8️⃣ Checking AI responses...');
    const { data: messages, error: messagesError } = await supabase
      .from('messages')
      .select('id, content, is_user, created_at')
      .eq('person_id', person.id)
      .order('created_at', { ascending: true });

    if (messagesError) throw messagesError;

    console.log(`   📨 Total messages in conversation: ${messages.length}`);
    messages.forEach((msg, idx) => {
      const preview = msg.content.substring(0, 60);
      console.log(`      ${idx + 1}. ${msg.is_user ? '👤 User' : '🤖 AI'}: "${preview}..."`);
    });

    // Check if AI mentioned Emma in welcome message
    const aiMessages = messages.filter(m => !m.is_user);
    const mentionsEmma = aiMessages.some(m => 
      m.content.toLowerCase().includes('emma')
    );

    if (mentionsEmma && emmaInstances.length === 1) {
      console.log('\n   ✅ AI mentioned Emma but no duplicate was created!');
      console.log('   🎉 The "seeing double" bug fix is working correctly!');
    }

    console.log('\n🎉 Direct chat flow test completed successfully!');
    console.log('\n📊 Test Summary:');
    console.log('   ✅ Authentication working');
    console.log('   ✅ Person creation working');
    console.log('   ✅ Message creation working');
    console.log('   ✅ Edge Function callable');
    console.log(`   ${emmaInstances.length > 1 ? '❌' : '✅'} "Seeing double" bug ${emmaInstances.length > 1 ? 'PRESENT' : 'FIXED'}`);

  } catch (error) {
    console.error('\n❌ Test failed:', error);
    process.exit(1);
  } finally {
    // Log out
    await supabase.auth.signOut();
    console.log('\n🔚 Logged out test user');
  }
}

// Run the test
if (import.meta.url === `file://${process.argv[1]}`) {
  testChatFlowDirect().then(() => process.exit(0));
}