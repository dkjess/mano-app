#!/usr/bin/env -S npx tsx

/**
 * Test script for Mano backend Edge Functions
 * Validates that all functions are working correctly
 */

import { createClient } from '@supabase/supabase-js'

const supabaseUrl = 'http://127.0.0.1:54321'
const supabaseServiceKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZS1kZW1vIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImV4cCI6MTk4MzgxMjk5Nn0.EGIM96RAZx35lJzdJsyH-qQwv8Hdp7fsn3W0YpN81IU'

const supabase = createClient(supabaseUrl, supabaseServiceKey)

interface TestResult {
  name: string
  success: boolean
  message: string
  duration?: number
}

const results: TestResult[] = []

async function testFunction(name: string, testFn: () => Promise<void>) {
  const start = Date.now()
  try {
    await testFn()
    const duration = Date.now() - start
    results.push({ name, success: true, message: `✅ Passed (${duration}ms)`, duration })
  } catch (error) {
    const duration = Date.now() - start
    results.push({ 
      name, 
      success: false, 
      message: `❌ Failed: ${error instanceof Error ? error.message : String(error)} (${duration}ms)`,
      duration
    })
  }
}

async function testDatabaseConnection() {
  const { data, error } = await supabase.from('people').select('count').limit(1)
  if (error) throw error
  console.log('Database connection successful')
}

async function testChatFunction() {
  const { data, error } = await supabase.functions.invoke('chat', {
    body: { 
      message: 'Hello, this is a test message',
      stream: false 
    }
  })
  
  if (error) throw error
  if (!data) throw new Error('No response from chat function')
  
  console.log('Chat function responded successfully')
}

async function testProfileGet() {
  const { data, error } = await supabase.functions.invoke('profile-get')
  
  if (error) throw error
  console.log('Profile get function responded successfully')
}

async function testProfileUpdate() {
  const { data, error } = await supabase.functions.invoke('profile-update', {
    body: {
      name: 'Test User',
      role: 'Engineering Manager'
    }
  })
  
  if (error) throw error
  console.log('Profile update function responded successfully')
}

async function main() {
  console.log('🧪 Testing Mano Backend Functions\n')
  console.log('Supabase URL:', supabaseUrl)
  console.log('Testing against local Supabase instance...\n')

  await testFunction('Database Connection', testDatabaseConnection)
  await testFunction('Chat Function', testChatFunction)
  await testFunction('Profile Get', testProfileGet)
  await testFunction('Profile Update', testProfileUpdate)

  console.log('\n📊 Test Results:')
  console.log('================')

  let passed = 0
  let failed = 0

  for (const result of results) {
    console.log(`${result.message}`)
    if (result.success) passed++
    else failed++
  }

  console.log(`\n🎯 Summary: ${passed} passed, ${failed} failed`)

  if (failed > 0) {
    console.log('\n⚠️  Some tests failed. Check your local Supabase setup:')
    console.log('   1. Is Supabase running? (supabase start)')
    console.log('   2. Are Edge Functions running? (supabase functions serve --env-file .env.local)')
    console.log('   3. Is test data seeded? (npm run seed:dev)')
    process.exit(1)
  } else {
    console.log('\n✅ All tests passed! Backend is ready for iOS client integration.')
  }
}

if (import.meta.main) {
  main().catch((error) => {
    console.error('❌ Test runner failed:', error)
    process.exit(1)
  })
}