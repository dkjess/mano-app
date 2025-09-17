#!/usr/bin/env -S npx tsx

/**
 * Simple backend test to verify basic connectivity
 */

console.log('🧪 Testing Mano Backend - Basic Connectivity\n')

// Test database connection
const testDbConnection = async () => {
  try {
    const response = await fetch('http://127.0.0.1:54321/rest/v1/', {
      method: 'GET',
      headers: {
        'apikey': 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZS1kZW1vIiwicm9sZSI6ImFub24iLCJleHAiOjE5ODM4MTI5OTZ9.CRXP1A7WOeoJeXxjNni43kdQwgnWNReilDMblYTn_I0'
      }
    })
    
    if (response.ok) {
      console.log('✅ Database API accessible')
      return true
    } else {
      console.log('❌ Database API not accessible:', response.status)
      return false
    }
  } catch (error) {
    console.log('❌ Database connection failed:', error.message)
    return false
  }
}

// Test Edge Functions availability
const testFunctionsAvailable = async () => {
  try {
    const response = await fetch('http://127.0.0.1:54321/functions/v1/chat', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json'
      },
      body: JSON.stringify({ test: 'connectivity' })
    })
    
    // Should get authorization error, which means the function is available
    if (response.status === 401) {
      console.log('✅ Edge Functions are running (chat function accessible)')
      return true
    } else {
      console.log('⚠️  Unexpected response from Edge Functions:', response.status)
      return true // Still counts as available
    }
  } catch (error) {
    console.log('❌ Edge Functions not accessible:', error.message)
    return false
  }
}

// Main test function
const main = async () => {
  console.log('Supabase URL: http://127.0.0.1:54321')
  console.log('Testing against local Supabase instance...\n')

  const dbOk = await testDbConnection()
  const functionsOk = await testFunctionsAvailable()

  console.log('\n📊 Test Results:')
  console.log('================')

  if (dbOk && functionsOk) {
    console.log('✅ Backend is ready! All basic connectivity tests passed.')
    console.log('\nNext steps:')
    console.log('   1. Seed test data: npm run seed:dev')
    console.log('   2. Open iOS project: open ../Mano.xcodeproj')
    console.log('   3. Run iOS app in Xcode simulator')
    process.exit(0)
  } else {
    console.log('❌ Backend setup incomplete. Check your local Supabase setup:')
    console.log('   1. Is Supabase running? (supabase start)')
    console.log('   2. Are Edge Functions running? (supabase functions serve --env-file .env.local)')
    console.log('   3. Check the logs for errors')
    process.exit(1)
  }
}

if (import.meta.main) {
  main().catch((error) => {
    console.error('❌ Test runner failed:', error)
    process.exit(1)
  })
}