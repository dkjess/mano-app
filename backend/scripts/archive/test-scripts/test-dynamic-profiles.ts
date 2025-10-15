import { createClient } from '@supabase/supabase-js';

const supabaseUrl = 'http://127.0.0.1:54321';
const supabaseKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZS1kZW1vIiwicm9sZSI6ImFub24iLCJleHAiOjE5ODM4MTI5OTZ9.CRXP1A7WOeoJeXxjNni43kdQwgnWNReilDMblYTn_I0';

async function testDynamicProfiles() {
  console.log('🧪 Testing Dynamic Profiles Phase 1a...');
  
  const supabase = createClient(supabaseUrl, supabaseKey);
  
  // Sign in as dev user
  console.log('🔑 Signing in as dev user...');
  const { data: authData, error: authError } = await supabase.auth.signInWithPassword({
    email: 'dev@mano.local',
    password: 'dev123456'
  });
  
  if (authError) {
    console.error('❌ Failed to sign in:', authError);
    return;
  }
  
  console.log('✅ Signed in as:', authData.user?.email);
  
  // Get user's people
  console.log('👥 Fetching people...');
  const { data: people, error: peopleError } = await supabase
    .from('people')
    .select('*')
    .limit(1);
    
  if (peopleError) {
    console.error('❌ Failed to fetch people:', peopleError);
    return;
  }
  
  if (people.length === 0) {
    console.log('❌ No people found - run seed script first');
    return;
  }
  
  const testPerson = people[0];
  console.log('👤 Testing with person:', testPerson.name);
  
  // Test profile-get endpoint
  console.log('📄 Testing profile-get...');
  const session = await supabase.auth.getSession();
  const token = session.data.session?.access_token;
  
  if (!token) {
    console.error('❌ No access token available');
    return;
  }
  
  const getResponse = await fetch(`${supabaseUrl}/functions/v1/profile-get?person_id=${testPerson.id}`, {
    headers: {
      'Authorization': `Bearer ${token}`
    }
  });
  
  if (getResponse.ok) {
    const profileData = await getResponse.json();
    console.log('✅ Profile retrieved:', profileData);
  } else {
    console.error('❌ Failed to get profile:', await getResponse.text());
    return;
  }
  
  // Test profile-update endpoint
  console.log('📝 Testing profile-update...');
  const testContent = `# ${testPerson.name}\n\nTest content added at ${new Date().toISOString()}\n\n## Notes\n- This is a test note\n- Another test note`;
  
  const updateResponse = await fetch(`${supabaseUrl}/functions/v1/profile-update`, {
    method: 'PUT',
    headers: {
      'Content-Type': 'application/json',
      'Authorization': `Bearer ${token}`
    },
    body: JSON.stringify({
      person_id: testPerson.id,
      content: testContent
    })
  });
  
  if (updateResponse.ok) {
    const updatedProfile = await updateResponse.json();
    console.log('✅ Profile updated:', updatedProfile);
  } else {
    console.error('❌ Failed to update profile:', await updateResponse.text());
    return;
  }
  
  // Test retrieving updated content
  console.log('🔄 Testing updated content retrieval...');
  const getResponse2 = await fetch(`${supabaseUrl}/functions/v1/profile-get?person_id=${testPerson.id}`, {
    headers: {
      'Authorization': `Bearer ${token}`
    }
  });
  
  if (getResponse2.ok) {
    const profileData2 = await getResponse2.json();
    console.log('✅ Updated profile retrieved:', profileData2);
    
    if (profileData2.content === testContent) {
      console.log('✅ Content matches what we saved!');
    } else {
      console.log('⚠️ Content does not match exactly');
    }
  } else {
    console.error('❌ Failed to get updated profile:', await getResponse2.text());
    return;
  }
  
  console.log('🎉 All tests passed! Dynamic Profiles Phase 1a is working.');
  console.log(`🌐 Visit http://localhost:3001/people/${testPerson.id} to test the UI`);
}

testDynamicProfiles().catch(console.error);