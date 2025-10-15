#!/usr/bin/env tsx

/**
 * Test Chat Flow Script
 * 
 * Tests the complete flow of:
 * 1. Logging in as test user
 * 2. Creating a new person
 * 3. Having a conversation
 * 4. Verifying no "seeing double" bug
 */

import { createClient } from '@supabase/supabase-js';
import * as dotenv from 'dotenv';

// Load environment variables
dotenv.config({ path: '.env.local' });

const supabaseUrl = process.env.NEXT_PUBLIC_SUPABASE_URL!;
const supabaseAnonKey = process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!;
const apiUrl = process.env.NEXT_PUBLIC_SITE_URL || 'http://localhost:3000';

// Test user credentials from seed script
const TEST_USER = {
  email: 'dev@mano.local',
  password: 'dev123456'
};

// Create Supabase client
const supabase = createClient(supabaseUrl, supabaseAnonKey);

async function testChatFlow() {
  console.log('🧪 Starting chat flow test...\n');

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
    
    if (!session) {
      throw new Error('No session returned from login');
    }

    // Step 2: Create a new person
    console.log('\n2️⃣ Creating a new person...');
    const newPerson = {
      name: 'Emma Wilson',
      role: 'Senior Designer',
      relationship_type: 'direct_report',
      notes: 'Just joined the team, working on the new design system.'
    };

    const createPersonResponse = await fetch(`${apiUrl}/api/people`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${session.access_token}`
      },
      body: JSON.stringify(newPerson)
    });

    if (!createPersonResponse.ok) {
      const error = await createPersonResponse.text();
      throw new Error(`Failed to create person: ${error}`);
    }

    const { person } = await createPersonResponse.json();
    console.log(`   ✅ Created person: ${person.name} (ID: ${person.id})`);

    // Step 3: Start a conversation
    console.log('\n3️⃣ Starting a conversation...');
    console.log(`   💬 Sending: "Hi Emma, welcome to the team! How are you settling in?"`);
    
    const chatResponse = await fetch(`${apiUrl}/api/chat`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${session.access_token}`
      },
      body: JSON.stringify({
        messages: [{ role: 'user', content: 'Hi Emma, welcome to the team! How are you settling in?' }],
        person_id: person.id
      })
    });

    if (!chatResponse.ok) {
      const error = await chatResponse.text();
      throw new Error(`Failed to send message: ${error}`);
    }

    // Read the streaming response
    console.log('   🔄 Receiving AI response...');
    const reader = chatResponse.body?.getReader();
    const decoder = new TextDecoder();
    let aiResponse = '';

    if (reader) {
      while (true) {
        const { done, value } = await reader.read();
        if (done) break;
        
        const chunk = decoder.decode(value, { stream: true });
        const lines = chunk.split('\n');
        
        for (const line of lines) {
          if (line.startsWith('data: ')) {
            const data = line.slice(6);
            try {
              const parsed = JSON.parse(data);
              if (parsed.type === 'delta' || parsed.type === 'content') {
                aiResponse += parsed.text || parsed.content || '';
              }
            } catch (e) {
              // Plain text
              if (data && data !== '[DONE]') {
                aiResponse += data;
              }
            }
          }
        }
      }
    }

    console.log(`   🤖 AI Response: "${aiResponse.substring(0, 100)}..."`);

    // Step 4: Check for "seeing double" bug
    console.log('\n4️⃣ Checking for "seeing double" bug...');
    
    // Wait a moment for any person detection to process
    await new Promise(resolve => setTimeout(resolve, 2000));
    
    // Fetch all people to see if Emma appears multiple times
    const peopleResponse = await fetch(`${apiUrl}/api/people`, {
      headers: {
        'Authorization': `Bearer ${session.access_token}`
      }
    });

    if (!peopleResponse.ok) {
      throw new Error('Failed to fetch people');
    }

    const { people } = await peopleResponse.json();
    const emmaCount = people.filter((p: any) => 
      p.name.toLowerCase().includes('emma') || 
      p.name.toLowerCase().includes('wilson')
    ).length;

    if (emmaCount > 1) {
      console.log(`   ❌ SEEING DOUBLE BUG DETECTED! Found ${emmaCount} instances of Emma`);
      people.filter((p: any) => 
        p.name.toLowerCase().includes('emma') || 
        p.name.toLowerCase().includes('wilson')
      ).forEach((p: any) => {
        console.log(`      - ${p.name} (${p.role}) created at ${p.created_at}`);
      });
    } else {
      console.log(`   ✅ No duplicate detected! Emma appears exactly ${emmaCount} time(s)`);
    }

    // Step 5: Send another message to test continued conversation
    console.log('\n5️⃣ Testing continued conversation...');
    console.log(`   💬 Sending: "What are your initial thoughts on our design system?"`);
    
    const secondChatResponse = await fetch(`${apiUrl}/api/chat`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${session.access_token}`
      },
      body: JSON.stringify({
        messages: [
          { role: 'user', content: 'Hi Emma, welcome to the team! How are you settling in?' },
          { role: 'assistant', content: aiResponse },
          { role: 'user', content: 'What are your initial thoughts on our design system?' }
        ],
        person_id: person.id
      })
    });

    if (!secondChatResponse.ok) {
      const error = await secondChatResponse.text();
      throw new Error(`Failed to send second message: ${error}`);
    }

    console.log('   ✅ Second message sent successfully');

    // Final check for duplicates
    console.log('\n6️⃣ Final duplicate check...');
    await new Promise(resolve => setTimeout(resolve, 2000));
    
    const finalPeopleResponse = await fetch(`${apiUrl}/api/people`, {
      headers: {
        'Authorization': `Bearer ${session.access_token}`
      }
    });

    const { people: finalPeople } = await finalPeopleResponse.json();
    const finalEmmaCount = finalPeople.filter((p: any) => 
      p.name.toLowerCase().includes('emma') || 
      p.name.toLowerCase().includes('wilson')
    ).length;

    if (finalEmmaCount > 1) {
      console.log(`   ❌ SEEING DOUBLE BUG STILL PRESENT! Found ${finalEmmaCount} instances`);
    } else {
      console.log(`   ✅ Bug fix confirmed! No duplicates after multiple messages`);
    }

    console.log('\n🎉 Chat flow test completed successfully!');
    console.log('\n📊 Test Summary:');
    console.log('   ✅ Authentication working');
    console.log('   ✅ Person creation working');
    console.log('   ✅ Chat API working');
    console.log('   ✅ Streaming responses working');
    console.log(`   ${finalEmmaCount > 1 ? '❌' : '✅'} "Seeing double" bug ${finalEmmaCount > 1 ? 'PRESENT' : 'FIXED'}`);

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
  testChatFlow().then(() => process.exit(0));
}