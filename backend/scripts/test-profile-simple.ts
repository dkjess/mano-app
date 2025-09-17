import { createClient } from '@supabase/supabase-js';

const SUPABASE_URL = 'http://127.0.0.1:54321';
const SUPABASE_ANON_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZS1kZW1vIiwicm9sZSI6ImFub24iLCJleHAiOjE5ODM4MTI5OTZ9.CRXP1A7WOeoJeXxjNni43kdQwgnWNReilDMblYTn_I0';

async function testBasicFunctionality() {
  console.log('🧪 Testing Dynamic Profiles Basic Functionality\n');
  
  const supabase = createClient(SUPABASE_URL, SUPABASE_ANON_KEY);
  
  // 1. Test authentication
  console.log('1️⃣ Testing authentication...');
  const { data: authData, error: authError } = await supabase.auth.signInWithPassword({
    email: 'dev@mano.local',
    password: 'dev123456'
  });
  
  if (authError) {
    console.error('❌ Auth failed:', authError);
    return;
  }
  console.log('✅ Authentication successful');
  
  // 2. Get a person to test with
  console.log('\n2️⃣ Getting test person...');
  const { data: people, error: peopleError } = await supabase
    .from('people')
    .select('*')
    .limit(1);
    
  if (peopleError || !people?.length) {
    console.error('❌ Failed to get people:', peopleError);
    return;
  }
  
  const testPerson = people[0];
  console.log(`✅ Using person: ${testPerson.name} (${testPerson.id})`);
  
  // 3. Test profile GET via API route
  console.log('\n3️⃣ Testing profile GET...');
  const getResponse = await fetch(`http://localhost:3000/api/profile?person_id=${testPerson.id}`, {
    headers: {
      'Cookie': `sb-auth-token=${authData.session?.access_token}`
    }
  });
  
  if (!getResponse.ok) {
    console.error('❌ Profile GET failed:', getResponse.status, await getResponse.text());
    return;
  }
  
  const profileData = await getResponse.json();
  console.log('✅ Profile GET successful:', profileData);
  
  // 4. Test profile UPDATE via API route
  console.log('\n4️⃣ Testing profile UPDATE...');
  const testContent = `<p>Test profile content - ${new Date().toISOString()}</p>`;
  
  const updateResponse = await fetch('http://localhost:3000/api/profile', {
    method: 'PUT',
    headers: {
      'Content-Type': 'application/json',
      'Cookie': `sb-auth-token=${authData.session?.access_token}`
    },
    body: JSON.stringify({
      person_id: testPerson.id,
      content: testContent
    })
  });
  
  if (!updateResponse.ok) {
    console.error('❌ Profile UPDATE failed:', updateResponse.status, await updateResponse.text());
    return;
  }
  
  console.log('✅ Profile UPDATE successful');
  
  // 5. Verify the update worked
  console.log('\n5️⃣ Verifying update...');
  const verifyResponse = await fetch(`http://localhost:3000/api/profile?person_id=${testPerson.id}`, {
    headers: {
      'Cookie': `sb-auth-token=${authData.session?.access_token}`
    }
  });
  
  const verifyData = await verifyResponse.json();
  if (verifyData.content === testContent) {
    console.log('✅ Update verified - content matches!');
  } else {
    console.error('❌ Update verification failed - content mismatch');
  }
  
  // 6. Test message sending
  console.log('\n6️⃣ Testing message sending...');
  const testMessage = `Test message - ${Date.now()}`;
  
  const messageResponse = await fetch('http://localhost:3000/api/chat', {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'Cookie': `sb-auth-token=${authData.session?.access_token}`
    },
    body: JSON.stringify({
      conversationId: testPerson.id,
      conversationType: 'person',
      content: testMessage
    })
  });
  
  if (!messageResponse.ok) {
    console.error('❌ Message send failed:', messageResponse.status);
    return;
  }
  
  console.log('✅ Message sent successfully');
  
  console.log('\n✅ All basic functionality tests passed!');
}

testBasicFunctionality().catch(console.error);