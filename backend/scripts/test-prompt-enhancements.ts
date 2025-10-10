/**
 * Test script for prompt enhancements
 * Tests the new personalization features
 */

import { createClient } from '@supabase/supabase-js'

const supabaseUrl = 'http://127.0.0.1:54321'
const supabaseAnonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZS1kZW1vIiwicm9sZSI6ImFub24iLCJleHAiOjE5ODM4MTI5OTZ9.CRXP1A7WOeoJeXxjNni43kdQwgnWNReilDMblYTn_I0'
const serviceRoleKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZS1kZW1vIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImV4cCI6MTk4MzgxMjk5Nn0.EGIM96RAZx35lJzdJsyH-qQwv8Hdp7fsn3W0YpN81IU'

async function testPromptEnhancements() {
  console.log('🧪 Testing Prompt Enhancements\n')

  // Sign in as test user
  const supabase = createClient(supabaseUrl, supabaseAnonKey)

  const { data: authData, error: authError } = await supabase.auth.signInWithPassword({
    email: 'dev@mano.local',
    password: 'dev123456'
  })

  if (authError || !authData.user) {
    console.error('❌ Failed to sign in:', authError)
    return
  }

  console.log(`✅ Signed in as: ${authData.user.email}`)

  // Get current user profile
  const { data: profile } = await supabase
    .from('user_profiles')
    .select('*')
    .eq('user_id', authData.user.id)
    .single()

  console.log('\n📋 Current User Profile:')
  console.log(`   Name: ${profile?.call_name}`)
  console.log(`   Role: ${profile?.job_role}`)
  console.log(`   Experience Level: ${profile?.experience_level || 'NOT SET'}`)
  console.log(`   Tone Preference: ${profile?.tone_preference || 'NOT SET'}`)

  // Update profile to test different scenarios
  console.log('\n🔧 Setting test profile values...')
  const { error: updateError } = await supabase
    .from('user_profiles')
    .update({
      experience_level: 'veteran',
      tone_preference: 'analytical'
    })
    .eq('user_id', authData.user.id)

  if (updateError) {
    console.error('❌ Failed to update profile:', updateError)
    return
  }

  console.log('✅ Profile updated: experience_level=veteran, tone_preference=analytical')

  // Get a person to test with
  const { data: people } = await supabase
    .from('people')
    .select('id, name, relationship_type')
    .eq('user_id', authData.user.id)
    .limit(1)

  if (!people || people.length === 0) {
    console.log('\n⚠️  No people found. Create a person first to test fully.')
    return
  }

  const testPerson = people[0]
  console.log(`\n👤 Testing with person: ${testPerson.name} (${testPerson.relationship_type})`)

  // Test different message types
  const testMessages = [
    {
      type: 'Self-Reflection',
      message: 'I feel worried about my leadership approach lately'
    },
    {
      type: 'Interpersonal',
      message: `I'm having a conflict with ${testPerson.name}`
    },
    {
      type: 'Direct Question',
      message: 'Tell me how to run effective 1:1s'
    },
    {
      type: 'Exploring',
      message: "I'm thinking about changing our team's sprint format"
    }
  ]

  console.log('\n🧪 Testing Different Message Types:\n')

  for (const test of testMessages) {
    console.log(`📝 ${test.type}: "${test.message}"`)

    try {
      const response = await fetch(`${supabaseUrl}/functions/v1/chat`, {
        method: 'POST',
        headers: {
          'Authorization': `Bearer ${authData.session?.access_token}`,
          'Content-Type': 'application/json'
        },
        body: JSON.stringify({
          person_id: testPerson.id,
          userMessage: test.message
        })
      })

      if (!response.ok) {
        console.log(`   ❌ Failed: ${response.statusText}\n`)
        continue
      }

      // Read the streaming response
      const reader = response.body?.getReader()
      const decoder = new TextDecoder()
      let fullResponse = ''

      if (reader) {
        while (true) {
          const { done, value } = await reader.read()
          if (done) break

          const chunk = decoder.decode(value)
          const lines = chunk.split('\n')

          for (const line of lines) {
            if (line.startsWith('data: ')) {
              try {
                const data = JSON.parse(line.slice(6))
                if (data.token) {
                  fullResponse += data.token
                }
              } catch (e) {
                // Skip invalid JSON
              }
            }
          }
        }
      }

      console.log(`   ✅ Response (${fullResponse.length} chars):`)
      console.log(`   "${fullResponse.substring(0, 150)}..."\n`)

    } catch (error) {
      console.log(`   ❌ Error: ${error}\n`)
    }

    // Wait a bit between requests
    await new Promise(resolve => setTimeout(resolve, 1000))
  }

  console.log('\n✅ Test complete!')
  console.log('\n💡 Tips:')
  console.log('   - Check logs: tail -f /tmp/supabase-functions.log')
  console.log('   - Watch for "COACHING CONTEXT" and "SITUATION TYPE" in prompts')
  console.log('   - Try changing experience_level and tone_preference in Studio')
}

testPromptEnhancements().catch(console.error)
