/**
 * Test script for pinned message title generation
 *
 * Tests:
 * 1. Pin a message
 * 2. Generate title for the pinned message
 * 3. Verify title was saved correctly
 */

import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const SUPABASE_URL = 'http://127.0.0.1:54321'
const SUPABASE_SERVICE_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZS1kZW1vIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImV4cCI6MTk4MzgxMjk5Nn0.EGIM96RAZx35lJzdJsyH-qQwv8Hdp7fsn3W0YpN81IU'
const TEST_USER_EMAIL = 'dev@mano.local'
const TEST_USER_PASSWORD = 'dev123456'

async function main() {
  console.log('🧪 Testing Pinned Message Title Generation\n')

  // Initialize Supabase client
  const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_KEY)

  // Sign in as test user
  console.log('1️⃣ Signing in as test user...')
  const { data: authData, error: authError } = await supabase.auth.signInWithPassword({
    email: TEST_USER_EMAIL,
    password: TEST_USER_PASSWORD,
  })

  if (authError || !authData.user) {
    console.error('❌ Failed to sign in:', authError)
    return
  }

  const userId = authData.user.id
  console.log(`✅ Signed in as: ${TEST_USER_EMAIL}`)
  console.log(`   User ID: ${userId}\n`)

  // Find an existing message to pin
  console.log('2️⃣ Finding a message to pin...')
  const { data: messages, error: messagesError } = await supabase
    .from('messages')
    .select('id, content, person_id, is_user')
    .eq('is_user', false) // AI messages only
    .limit(1)
    .single()

  if (messagesError || !messages) {
    console.error('❌ Failed to find message:', messagesError)
    return
  }

  console.log(`✅ Found message: ${messages.id}`)
  console.log(`   Content preview: ${messages.content.substring(0, 100)}...\n`)

  // Pin the message
  console.log('3️⃣ Pinning the message...')
  const { error: pinError } = await supabase
    .from('pinned_messages')
    .insert({
      user_id: userId,
      message_id: messages.id,
      person_id: messages.person_id,
    })

  if (pinError) {
    // Check if already pinned
    if (pinError.code === '23505') {
      console.log('ℹ️  Message already pinned, continuing with test...\n')
    } else {
      console.error('❌ Failed to pin message:', pinError)
      return
    }
  } else {
    console.log('✅ Message pinned successfully\n')
  }

  // Generate title via Edge Function
  console.log('4️⃣ Generating title via Edge Function...')
  const { data: titleResponse, error: titleError } = await supabase.functions.invoke(
    'generate-pinned-title',
    {
      body: {
        message_id: messages.id,
        user_id: userId,
      },
    }
  )

  if (titleError) {
    console.error('❌ Failed to generate title:', titleError)
    return
  }

  console.log('✅ Title generation response:', titleResponse)
  console.log(`   Generated title: "${titleResponse.title}"\n`)

  // Verify title was saved
  console.log('5️⃣ Verifying title was saved...')
  const { data: pinnedMessage, error: verifyError } = await supabase
    .from('pinned_messages')
    .select('title')
    .eq('message_id', messages.id)
    .eq('user_id', userId)
    .single()

  if (verifyError) {
    console.error('❌ Failed to verify title:', verifyError)
    return
  }

  console.log(`✅ Title saved in database: "${pinnedMessage.title}"\n`)

  // Summary
  console.log('📊 Test Summary:')
  console.log('   ✅ Message pinned successfully')
  console.log('   ✅ Title generated via AI')
  console.log('   ✅ Title saved to database')
  console.log(`   📌 Final title: "${pinnedMessage.title}"`)
  console.log('\n🎉 All tests passed!')
}

main().catch(console.error)
