import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const SUPABASE_URL = 'http://127.0.0.1:54321'
const SUPABASE_SERVICE_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZS1kZW1vIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImV4cCI6MTk4MzgxMjk5Nn0.EGIM96RAZx35lJzdJsyH-qQwv8Hdp7fsn3W0YpN81IU'

async function test() {
  const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_KEY)

  console.log('🧪 Testing Pinned Messages Backend\n')

  // Simple query first
  const { data, error } = await supabase
    .from('pinned_messages')
    .select('id, message_id, title')

  if (error) {
    console.error('❌ Error:', error)
    return
  }

  console.log(`✅ Found ${data.length} pinned messages`)
  console.log('Pinned messages:', JSON.stringify(data, null, 2))
}

test()
