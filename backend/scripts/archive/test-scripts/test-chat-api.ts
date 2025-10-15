#!/usr/bin/env tsx

/**
 * Test Chat API Script
 * 
 * Tests the new /api/chat endpoint with proper authentication
 */

import * as dotenv from 'dotenv';

// Load environment variables
dotenv.config({ path: '.env.local' });

const apiUrl = process.env.NEXT_PUBLIC_SITE_URL || 'http://localhost:3000';

// Test user credentials
const TEST_USER = {
  email: 'dev@mano.local',
  password: 'dev123456'
};

async function testChatAPI() {
  console.log('🧪 Testing Chat API endpoint...\n');

  try {
    // Step 1: Log in to get session token
    console.log('1️⃣ Logging in via API...');
    
    const loginResponse = await fetch(`${apiUrl}/auth/callback`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        email: TEST_USER.email,
        password: TEST_USER.password
      }),
      redirect: 'manual'
    });

    console.log('   Login response status:', loginResponse.status);
    
    // Extract cookies from login response
    const cookies = loginResponse.headers.get('set-cookie');
    console.log('   Cookies received:', cookies ? 'Yes' : 'No');

    // Alternative: Use Supabase client for auth
    const { createClient } = await import('@supabase/supabase-js');
    const supabase = createClient(
      process.env.NEXT_PUBLIC_SUPABASE_URL!,
      process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!
    );

    const { data: authData, error: authError } = await supabase.auth.signInWithPassword({
      email: TEST_USER.email,
      password: TEST_USER.password
    });

    if (authError || !authData.session) {
      throw new Error(`Login failed: ${authError?.message}`);
    }

    console.log('   ✅ Logged in successfully');

    // Step 2: Get a person to chat with
    console.log('\n2️⃣ Getting a person to chat with...');
    const { data: people } = await supabase
      .from('people')
      .select('id, name')
      .limit(1);

    if (!people || people.length === 0) {
      throw new Error('No people found');
    }

    const person = people[0];
    console.log(`   ✅ Found person: ${person.name} (ID: ${person.id})`);

    // Step 3: Test the chat API
    console.log('\n3️⃣ Testing /api/chat endpoint...');
    
    // First, let's test with curl to see raw response
    console.log('   Testing with direct fetch...');
    
    const chatResponse = await fetch(`${apiUrl}/api/chat`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${authData.session.access_token}`,
        'Cookie': `sb-auth-token=${authData.session.access_token}`
      },
      body: JSON.stringify({
        messages: [{ role: 'user', content: 'Hello! This is a test message.' }],
        person_id: person.id
      })
    });

    console.log('   Response status:', chatResponse.status);
    console.log('   Response headers:', Object.fromEntries(chatResponse.headers.entries()));

    if (chatResponse.status === 307) {
      console.log('   ❌ Got redirect - authentication not working via API');
      const location = chatResponse.headers.get('location');
      console.log('   Redirect location:', location);
    } else if (chatResponse.ok) {
      console.log('   ✅ Chat API responded successfully!');
      
      // Read some of the response
      const reader = chatResponse.body?.getReader();
      if (reader) {
        const { value } = await reader.read();
        if (value) {
          const preview = new TextDecoder().decode(value).substring(0, 100);
          console.log(`   Response preview: "${preview}..."`);
        }
        reader.releaseLock();
      }
    } else {
      const error = await chatResponse.text();
      console.log('   ❌ Chat API error:', error);
    }

    console.log('\n📊 Test Summary:');
    console.log('   ✅ Can authenticate with Supabase');
    console.log('   ✅ Can access database');
    console.log(`   ${chatResponse.ok ? '✅' : '❌'} Chat API endpoint ${chatResponse.ok ? 'working' : 'needs fixes'}`);

  } catch (error) {
    console.error('\n❌ Test failed:', error);
  }
}

// Run the test
if (import.meta.url === `file://${process.argv[1]}`) {
  testChatAPI().then(() => process.exit(0));
}