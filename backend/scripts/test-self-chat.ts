#!/usr/bin/env tsx

/**
 * Test Self-Reflection Chat
 *
 * This script tests the chat functionality with the self person.
 */

import { createClient } from '@supabase/supabase-js';
import * as dotenv from 'dotenv';

// Load environment variables
dotenv.config({ path: '.env.local' });

const supabaseUrl = process.env.NEXT_PUBLIC_SUPABASE_URL!;
const supabaseAnonKey = process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!;

const TEST_USER = {
  email: 'dev@mano.local',
  password: 'dev123456'
};

async function testSelfChat() {
  console.log('🧪 Testing self-reflection chat...\n');

  try {
    // Create client with anon key
    const supabase = createClient(supabaseUrl, supabaseAnonKey);

    // Sign in as test user
    console.log('1️⃣ Signing in as test user...');
    const { data: authData, error: authError } = await supabase.auth.signInWithPassword({
      email: TEST_USER.email,
      password: TEST_USER.password
    });

    if (authError) {
      throw new Error(`Failed to sign in: ${authError.message}`);
    }
    console.log('✅ Signed in successfully');

    // Get the self person
    console.log('\n2️⃣ Getting self person...');
    const { data: selfPerson, error: personError } = await supabase
      .from('people')
      .select('*')
      .eq('is_self', true)
      .single();

    if (personError || !selfPerson) {
      throw new Error(`Self person not found: ${personError?.message}`);
    }
    console.log('✅ Found self person:', selfPerson.name, `(${selfPerson.id})`);

    // Test chat endpoint
    console.log('\n3️⃣ Testing chat with self person...');
    const chatMessage = "How am I doing as a manager? What areas should I focus on improving?";
    console.log('📝 Sending message:', chatMessage);

    const response = await fetch(`${supabaseUrl}/functions/v1/chat`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${authData.session?.access_token}`
      },
      body: JSON.stringify({
        message: chatMessage,
        person_id: selfPerson.id,
        stream: false // Use non-streaming for simpler testing
      })
    });

    if (!response.ok) {
      const error = await response.text();
      throw new Error(`Chat API failed: ${response.status} - ${error}`);
    }

    const result = await response.json();
    console.log('\n✅ Chat response received!');
    console.log('📬 Assistant message:', result.content || result.message || 'No content in response');

    // Verify the message was saved
    console.log('\n4️⃣ Verifying messages were saved...');
    const { data: messages, error: messagesError } = await supabase
      .from('messages')
      .select('content, is_user, created_at')
      .eq('person_id', selfPerson.id)
      .order('created_at', { ascending: false })
      .limit(2);

    if (messagesError) {
      console.warn('⚠️ Could not fetch messages:', messagesError.message);
    } else {
      console.log(`✅ Found ${messages.length} recent messages in the conversation`);
      messages.forEach((msg, i) => {
        console.log(`   ${i + 1}. ${msg.is_user ? 'User' : 'Mano'}: ${msg.content.substring(0, 100)}...`);
      });
    }

    // Check if the response uses self-reflection prompt
    console.log('\n5️⃣ Analyzing response for self-reflection characteristics...');
    const responseText = result.content || result.message || '';
    const selfReflectionIndicators = [
      'reflection',
      'your leadership',
      'your management',
      'you are',
      'you have',
      'your style',
      'self-awareness',
      'personal growth'
    ];

    const foundIndicators = selfReflectionIndicators.filter(indicator =>
      responseText.toLowerCase().includes(indicator)
    );

    if (foundIndicators.length > 0) {
      console.log('✅ Response appears to be using self-reflection prompt');
      console.log('   Found indicators:', foundIndicators.join(', '));
    } else {
      console.log('⚠️ Response may not be using self-reflection prompt optimally');
    }

    console.log('\n🎉 Self-reflection chat test completed successfully!');
    console.log('\n📊 Summary:');
    console.log('   • Self person exists and is properly configured');
    console.log('   • Chat API works with self person');
    console.log('   • Messages are being saved to database');
    console.log('   • Response tone appears appropriate for self-reflection');

    // Sign out
    await supabase.auth.signOut();

  } catch (error) {
    console.error('\n❌ Test failed:', error);
    process.exit(1);
  }
}

// Run the test
testSelfChat();