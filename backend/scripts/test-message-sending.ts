#!/usr/bin/env -S deno run --allow-net --allow-env

/**
 * Test script for message sending functionality
 * Tests:
 * 1. Person creation with initial message generation
 * 2. Chat message sending
 * 3. Streaming response
 */

const SUPABASE_URL = Deno.env.get('SUPABASE_URL') || 'http://127.0.0.1:54321'
const SUPABASE_ANON_KEY = Deno.env.get('SUPABASE_ANON_KEY') || 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZS1kZW1vIiwicm9sZSI6ImFub24iLCJleHAiOjE5ODM4MTI5OTZ9.CRXP1A7WOeoJeXxjNni43kdQwgnWNReilDMblYTn_I0'

// Test user token (from dev@mano.local)
const TEST_USER_TOKEN = Deno.env.get('TEST_USER_TOKEN') || ''

if (!TEST_USER_TOKEN) {
  console.error('❌ TEST_USER_TOKEN environment variable required')
  console.log('Get it from: http://127.0.0.1:54321/project/default/auth/users')
  Deno.exit(1)
}

interface TestResult {
  name: string
  passed: boolean
  details?: string
  error?: string
}

const results: TestResult[] = []

async function testPersonCreation() {
  console.log('\n📝 Test 1: Person Creation with Initial Message')
  console.log('================================================')

  try {
    const response = await fetch(`${SUPABASE_URL}/functions/v1/person`, {
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${TEST_USER_TOKEN}`,
        'Content-Type': 'application/json',
        'apikey': SUPABASE_ANON_KEY
      },
      body: JSON.stringify({
        name: 'Test Person',
        role: 'Software Engineer',
        relationship_type: 'direct_report',
        generate_initial_message: true
      })
    })

    if (!response.ok) {
      const error = await response.text()
      throw new Error(`HTTP ${response.status}: ${error}`)
    }

    const data = await response.json()
    console.log('✅ Person created:', data.person?.name)

    if (data.initialMessage) {
      console.log('✅ Initial message created:', data.initialMessage.content.substring(0, 100) + '...')
      results.push({
        name: 'Person creation with initial message',
        passed: true,
        details: `Person "${data.person.name}" created with initial message`
      })
    } else {
      console.log('⚠️  No initial message in response')
      results.push({
        name: 'Person creation with initial message',
        passed: false,
        details: 'Person created but no initial message returned'
      })
    }

    return data.person
  } catch (error) {
    console.error('❌ Person creation failed:', error.message)
    results.push({
      name: 'Person creation with initial message',
      passed: false,
      error: error.message
    })
    return null
  }
}

async function testMessageSending(personId: string) {
  console.log('\n💬 Test 2: Message Sending')
  console.log('===========================')

  try {
    const response = await fetch(`${SUPABASE_URL}/functions/v1/chat`, {
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${TEST_USER_TOKEN}`,
        'Content-Type': 'application/json',
        'apikey': SUPABASE_ANON_KEY
      },
      body: JSON.stringify({
        action: 'streaming_chat',
        message: 'What should I focus on with this person?',
        person_id: personId
      })
    })

    if (!response.ok) {
      const error = await response.text()
      throw new Error(`HTTP ${response.status}: ${error}`)
    }

    console.log('✅ Chat request accepted')
    console.log('📡 Streaming response:')

    let receivedData = false
    let fullResponse = ''

    const reader = response.body?.getReader()
    const decoder = new TextDecoder()

    if (!reader) {
      throw new Error('No response body')
    }

    while (true) {
      const { done, value } = await reader.read()

      if (done) {
        break
      }

      const chunk = decoder.decode(value, { stream: true })
      const lines = chunk.split('\n')

      for (const line of lines) {
        if (line.startsWith('data: ')) {
          receivedData = true
          const jsonStr = line.slice(6)
          try {
            const data = JSON.parse(jsonStr)
            if (data.content) {
              process.stdout.write(data.content)
              fullResponse += data.content
            }
            if (data.done) {
              console.log('\n✅ Stream completed')
            }
          } catch (e) {
            // Skip non-JSON lines
          }
        }
      }
    }

    console.log('\n')

    if (receivedData && fullResponse.length > 0) {
      console.log(`✅ Received ${fullResponse.length} characters`)
      results.push({
        name: 'Message sending with streaming',
        passed: true,
        details: `Received ${fullResponse.length} character response`
      })
    } else {
      console.log('⚠️  No data received')
      results.push({
        name: 'Message sending with streaming',
        passed: false,
        details: 'Request succeeded but no data streamed'
      })
    }
  } catch (error) {
    console.error('❌ Message sending failed:', error.message)
    results.push({
      name: 'Message sending with streaming',
      passed: false,
      error: error.message
    })
  }
}

// Run tests
console.log('🧪 Testing Message Sending Functionality')
console.log('=========================================')
console.log(`Supabase URL: ${SUPABASE_URL}`)

const person = await testPersonCreation()

if (person) {
  await testMessageSending(person.id)
}

// Print results
console.log('\n📊 Test Results')
console.log('================')
results.forEach((result, i) => {
  const icon = result.passed ? '✅' : '❌'
  console.log(`${i + 1}. ${icon} ${result.name}`)
  if (result.details) {
    console.log(`   ${result.details}`)
  }
  if (result.error) {
    console.log(`   Error: ${result.error}`)
  }
})

const passed = results.filter(r => r.passed).length
const total = results.length
console.log(`\n${passed}/${total} tests passed`)

Deno.exit(passed === total ? 0 : 1)
