/**
 * Test that onboarding completion generates initial message for is_self person
 */

import { createClient } from '@supabase/supabase-js'

const supabaseUrl = 'http://127.0.0.1:54321'
const supabaseAnonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZS1kZW1vIiwicm9sZSI6ImFub24iLCJleHAiOjE5ODM4MTI5OTZ9.CRXP1A7WOeoJeXxjNni43kdQwgnWNReilDMblYTn_I0'

async function testOnboardingInitialMessage() {
  console.log('🧪 Testing onboarding initial message generation...\n')

  // Create a new test user
  const testEmail = `test-${Date.now()}@mano.local`
  const testPassword = 'test123456'

  console.log(`1️⃣ Creating new user: ${testEmail}`)
  const supabase = createClient(supabaseUrl, supabaseAnonKey)

  const { data: signUpData, error: signUpError } = await supabase.auth.signUp({
    email: testEmail,
    password: testPassword,
  })

  if (signUpError) {
    console.error('❌ Failed to create user:', signUpError)
    return
  }

  console.log(`✅ User created: ${signUpData.user?.id}`)

  // Wait a moment for trigger to complete
  await new Promise(resolve => setTimeout(resolve, 1000))

  // Check if self person was created by trigger
  const { data: selfPerson, error: selfPersonError } = await supabase
    .from('people')
    .select('id, name')
    .eq('user_id', signUpData.user!.id)
    .eq('is_self', true)
    .single()

  if (selfPersonError) {
    console.error('❌ Self person not created by trigger:', selfPersonError)
    return
  }

  console.log(`✅ Self person created by trigger: ${selfPerson.name} (${selfPerson.id})`)

  // Check messages before onboarding
  const { data: messagesBefore, error: messagesBeforeError } = await supabase
    .from('messages')
    .select('*')
    .eq('person_id', selfPerson.id.toString())

  console.log(`📬 Messages before onboarding: ${messagesBefore?.length || 0}`)

  // Complete onboarding
  console.log('\n2️⃣ Completing onboarding...')

  const response = await fetch(`${supabaseUrl}/functions/v1/user-profile-foundation`, {
    method: 'PUT',
    headers: {
      'Authorization': `Bearer ${signUpData.session?.access_token}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({
      call_name: 'Test User',
      job_role: 'Engineering Manager',
      experience_level: 'experienced',
      tone_preference: 'warm',
      onboarding_step: 3
    })
  })

  const onboardingResult = await response.json()

  if (!response.ok) {
    console.error('❌ Onboarding failed:', onboardingResult)
    return
  }

  console.log(`✅ Onboarding completed`)

  // Wait for initial message to be generated (longer delay for generation + API calls)
  console.log(`\n3️⃣ Waiting for initial message generation...`)
  await new Promise(resolve => setTimeout(resolve, 5000))

  // Check messages after onboarding
  const { data: messagesAfter, error: messagesAfterError } = await supabase
    .from('messages')
    .select('*')
    .eq('person_id', selfPerson.id.toString())
    .order('created_at', { ascending: false })

  console.log(`📬 Messages after onboarding: ${messagesAfter?.length || 0}`)

  if (messagesAfter && messagesAfter.length > 0) {
    console.log(`\n✅ Initial message created!`)
    console.log(`   Content: "${messagesAfter[0].content.substring(0, 100)}..."`)
    console.log(`   Is User: ${messagesAfter[0].is_user}`)
  } else {
    console.log(`\n❌ No initial message found!`)
    console.log(`   Checking if person still exists...`)
    const { data: checkPerson } = await supabase
      .from('people')
      .select('id, name, user_id')
      .eq('id', selfPerson.id)
      .single()
    console.log(`   Person exists:`, checkPerson ? 'Yes' : 'No')
  }

  // Clean up: delete the test user
  console.log(`\n4️⃣ Cleaning up test user...`)
  const adminClient = createClient(
    supabaseUrl,
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZS1kZW1vIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImV4cCI6MTk4MzgxMjk5Nn0.EGIM96RAZx35lJzdJsyH-qQwv8Hdp7fsn3W0YpN81IU'
  )

  await adminClient.auth.admin.deleteUser(signUpData.user!.id)
  console.log(`✅ Test user deleted`)

  console.log(`\n🎉 Test completed!`)
}

testOnboardingInitialMessage().catch(console.error)
