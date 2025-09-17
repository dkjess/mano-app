import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'
import { corsHeaders } from '../_shared/cors.ts'

console.log('Test OpenAI function starting...')

serve(async (req) => {
  // Handle CORS
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  console.log('🔍 Test request received')
  
  try {
    // Test 1: Basic connectivity
    console.log('🧪 Test 1: Checking OpenAI API key...')
    const apiKey = Deno.env.get('OPENAI_API_KEY')
    console.log('API Key available:', !!apiKey)
    console.log('API Key length:', apiKey?.length || 0)
    
    if (!apiKey) {
      throw new Error('OPENAI_API_KEY not found in environment')
    }

    // Test 2: Simple fetch with timeout
    console.log('🧪 Test 2: Testing basic fetch to OpenAI...')
    const controller = new AbortController()
    const timeoutId = setTimeout(() => controller.abort(), 10000) // 10 second timeout
    
    try {
      console.log('About to fetch...')
      const testResponse = await fetch('https://api.openai.com/v1/models', {
        method: 'GET',
        headers: {
          'Authorization': `Bearer ${apiKey}`,
        },
        signal: controller.signal
      })
      clearTimeout(timeoutId)
      
      console.log('Fetch completed! Status:', testResponse.status)
      console.log('Headers:', Object.fromEntries(testResponse.headers.entries()))
      
      if (!testResponse.ok) {
        const error = await testResponse.text()
        console.error('API Error:', error)
      } else {
        const data = await testResponse.json()
        console.log('Success! Got', data.data?.length || 0, 'models')
      }
    } catch (fetchError) {
      clearTimeout(timeoutId)
      console.error('Fetch error:', fetchError)
      console.error('Error name:', fetchError.name)
      console.error('Error message:', fetchError.message)
    }

    // Test 3: Actual embedding call with minimal payload
    console.log('🧪 Test 3: Testing embedding endpoint...')
    const embeddingController = new AbortController()
    const embeddingTimeoutId = setTimeout(() => embeddingController.abort(), 10000)
    
    try {
      console.log('About to fetch embeddings endpoint...')
      const embeddingResponse = await fetch('https://api.openai.com/v1/embeddings', {
        method: 'POST',
        headers: {
          'Authorization': `Bearer ${apiKey}`,
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({
          input: 'test',
          model: 'text-embedding-ada-002'
        }),
        signal: embeddingController.signal
      })
      clearTimeout(embeddingTimeoutId)
      
      console.log('Embedding fetch completed! Status:', embeddingResponse.status)
      
      if (!embeddingResponse.ok) {
        const error = await embeddingResponse.text()
        console.error('Embedding API Error:', error)
      } else {
        const data = await embeddingResponse.json()
        console.log('Success! Embedding length:', data.data?.[0]?.embedding?.length || 0)
      }
    } catch (embeddingError) {
      clearTimeout(embeddingTimeoutId)
      console.error('Embedding fetch error:', embeddingError)
      console.error('Error name:', embeddingError.name)
      console.error('Error message:', embeddingError.message)
    }

    // Test 4: Test VectorService directly
    console.log('🧪 Test 4: Testing VectorService...')
    try {
      const { createClient } = await import('https://esm.sh/@supabase/supabase-js@2')
      const { VectorService } = await import('../_shared/vector-service.ts')
      
      console.log('Creating Supabase client...')
      const supabaseUrl = Deno.env.get('SUPABASE_URL')!
      const supabaseKey = Deno.env.get('SUPABASE_ANON_KEY')!
      const supabase = createClient(supabaseUrl, supabaseKey)
      
      console.log('Creating VectorService instance...')
      const vectorService = new VectorService(supabase)
      
      console.log('Calling generateEmbedding...')
      const embedding = await vectorService.generateEmbedding('test message')
      console.log('✅ VectorService worked! Embedding length:', embedding.length)
      
    } catch (vectorError) {
      console.error('VectorService test error:', vectorError)
      console.error('Error name:', vectorError.name)
      console.error('Error message:', vectorError.message)
    }

    // Return results
    return new Response(
      JSON.stringify({
        success: true,
        message: 'Tests completed - check Edge Function logs for details'
      }),
      {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      }
    )
    
  } catch (error) {
    console.error('Test function error:', error)
    return new Response(
      JSON.stringify({ error: error.message }),
      {
        status: 500,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      }
    )
  }
})