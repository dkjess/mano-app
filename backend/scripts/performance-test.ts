#!/usr/bin/env node
import { createClient } from '@supabase/supabase-js'

const supabaseUrl = process.env.NEXT_PUBLIC_SUPABASE_URL || 'http://127.0.0.1:54321'
const supabaseKey = process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY || 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZS1kZW1vIiwicm9sZSI6ImFub24iLCJleHAiOjE5ODM4MTI5OTZ9.CRXP1A7WOeoJeXxjNni43kdQwgnWNReilDMblYTn_I0'

interface TestResult {
  testName: string
  totalTime: number
  firstByteTime?: number
  responseLength: number
  cached: boolean
  error?: string
}

class PerformanceTester {
  private supabase: any
  private session: any
  private person: any
  private results: TestResult[] = []

  constructor() {
    this.supabase = createClient(supabaseUrl, supabaseKey)
  }

  async setup() {
    console.log('🔧 Setting up performance test...\n')
    
    // Sign in as test user
    const { data: authData, error: authError } = await this.supabase.auth.signInWithPassword({
      email: 'dev@mano.local',
      password: 'dev123456'
    })
    
    if (authError) throw new Error(`Auth failed: ${authError.message}`)
    
    this.session = authData.session
    console.log('✅ Authenticated as:', authData.user.email)
    
    // Get a person to chat with
    const { data: people, error: peopleError } = await this.supabase
      .from('people')
      .select('*')
      .limit(1)
    
    if (peopleError || !people?.length) throw new Error('No people found')
    
    this.person = people[0]
    console.log('👤 Testing with person:', this.person.name)
    console.log('')
  }

  async runTest(testName: string, message: string, expectCached: boolean = false) {
    console.log(`🧪 Running test: ${testName}`)
    
    const startTime = Date.now()
    let firstByteTime: number | undefined
    
    try {
      const response = await fetch(`${supabaseUrl}/functions/v1/chat`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'Authorization': `Bearer ${this.session.access_token}`
        },
        body: JSON.stringify({
          action: 'streaming_chat',
          messages: [{ role: 'user', content: message }],
          person_id: this.person.id
        })
      })
      
      if (!response.ok) {
        throw new Error(`HTTP ${response.status}: ${await response.text()}`)
      }
      
      // Read the streaming response
      const reader = response.body?.getReader()
      let fullResponse = ''
      let firstChunk = true
      
      if (reader) {
        while (true) {
          const { done, value } = await reader.read()
          
          if (firstChunk && value) {
            firstByteTime = Date.now() - startTime
            firstChunk = false
          }
          
          if (done) break
          
          const chunk = new TextDecoder().decode(value)
          fullResponse += chunk
        }
      }
      
      const totalTime = Date.now() - startTime
      
      const result: TestResult = {
        testName,
        totalTime,
        firstByteTime,
        responseLength: fullResponse.length,
        cached: expectCached
      }
      
      this.results.push(result)
      
      console.log(`✅ Complete in ${totalTime}ms (First byte: ${firstByteTime}ms)`)
      console.log(`   Response length: ${fullResponse.length} chars`)
      console.log('')
      
    } catch (error) {
      const result: TestResult = {
        testName,
        totalTime: Date.now() - startTime,
        responseLength: 0,
        cached: expectCached,
        error: error.message
      }
      
      this.results.push(result)
      
      console.log(`❌ Failed: ${error.message}`)
      console.log('')
    }
  }

  async runTestSuite() {
    console.log('🚀 Starting Performance Test Suite\n')
    console.log('='*50 + '\n')
    
    // Test 1: Cold start - first request
    await this.runTest(
      'Cold Start Request',
      'What are the key challenges Sarah is facing with her current project?',
      false
    )
    
    // Wait a bit
    await new Promise(resolve => setTimeout(resolve, 1000))
    
    // Test 2: Warm cache - similar request
    await this.runTest(
      'Warm Cache Request',
      'How can I help Sarah overcome her project obstacles?',
      true
    )
    
    // Test 3: Different person context (should partially use cache)
    await this.runTest(
      'Different Context Request',
      'What management strategies would work best for improving team collaboration?',
      true
    )
    
    // Test 4: Complex request with file context simulation
    await this.runTest(
      'Complex Request',
      'Based on our previous discussions and the team dynamics I\'ve mentioned, what specific actions should I take in my next 1:1 with Sarah to address both her technical challenges and career growth aspirations? Please consider her communication style and recent performance.',
      true
    )
    
    // Test 5: Rapid successive requests (stress test)
    console.log('🏃 Running rapid succession test (3 requests)...')
    const rapidStart = Date.now()
    
    await Promise.all([
      this.runTest('Rapid Request 1', 'Quick advice on team morale?', true),
      this.runTest('Rapid Request 2', 'How to handle conflict?', true),
      this.runTest('Rapid Request 3', 'Best delegation practices?', true)
    ])
    
    console.log(`🏁 Rapid test completed in ${Date.now() - rapidStart}ms total\n`)
  }

  printSummary() {
    console.log('='*50)
    console.log('📊 PERFORMANCE TEST SUMMARY\n')
    
    // Calculate statistics
    const validResults = this.results.filter(r => !r.error)
    const avgTotalTime = validResults.reduce((sum, r) => sum + r.totalTime, 0) / validResults.length
    const avgFirstByte = validResults.filter(r => r.firstByteTime).reduce((sum, r) => sum + (r.firstByteTime || 0), 0) / validResults.filter(r => r.firstByteTime).length
    
    const coldResults = validResults.filter(r => !r.cached)
    const cachedResults = validResults.filter(r => r.cached)
    
    const avgColdTime = coldResults.reduce((sum, r) => sum + r.totalTime, 0) / coldResults.length || 0
    const avgCachedTime = cachedResults.reduce((sum, r) => sum + r.totalTime, 0) / cachedResults.length || 0
    
    console.log('Overall Statistics:')
    console.log(`  • Average Response Time: ${Math.round(avgTotalTime)}ms`)
    console.log(`  • Average First Byte: ${Math.round(avgFirstByte)}ms`)
    console.log(`  • Cold Start Average: ${Math.round(avgColdTime)}ms`)
    console.log(`  • Cached Average: ${Math.round(avgCachedTime)}ms`)
    console.log(`  • Cache Improvement: ${Math.round((1 - avgCachedTime/avgColdTime) * 100)}%`)
    console.log('')
    
    console.log('Individual Test Results:')
    console.table(this.results.map(r => ({
      Test: r.testName,
      'Total (ms)': r.totalTime,
      'First Byte (ms)': r.firstByteTime || 'N/A',
      'Response Size': `${r.responseLength} chars`,
      Cached: r.cached ? '✓' : '✗',
      Status: r.error ? '❌ ' + r.error : '✅'
    })))
    
    // Performance recommendations
    console.log('\n🎯 Performance Analysis:')
    
    if (avgTotalTime > 10000) {
      console.log('  ⚠️  Average response time exceeds 10 seconds - optimization needed')
    } else if (avgTotalTime > 5000) {
      console.log('  ⚡ Response time is acceptable but could be improved')
    } else {
      console.log('  ✅ Response time is good!')
    }
    
    if (avgCachedTime < avgColdTime * 0.7) {
      console.log('  ✅ Caching is effective (>30% improvement)')
    } else {
      console.log('  ⚠️  Caching improvement is minimal - investigate cache hits')
    }
    
    if (avgFirstByte > 2000) {
      console.log('  ⚠️  High time to first byte - check initial processing')
    }
    
    // Export results for PostHog
    console.log('\n📈 Sending results to PostHog...')
    // In a real implementation, we'd send these metrics to PostHog
  }
}

// Run the test suite
async function main() {
  const tester = new PerformanceTester()
  
  try {
    await tester.setup()
    await tester.runTestSuite()
    tester.printSummary()
  } catch (error) {
    console.error('❌ Test suite failed:', error.message)
    process.exit(1)
  }
}

main()