import { createClient } from '@supabase/supabase-js'

const supabaseUrl = 'http://127.0.0.1:54321'
const supabaseServiceKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZS1kZW1vIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImV4cCI6MTk4MzgxMjk5Nn0.EGIM96RAZx35lJzdJsyH-qQwv8Hdp7fsn3W0YpN81IU'

const supabase = createClient(supabaseUrl, supabaseServiceKey, {
  auth: { autoRefreshToken: false, persistSession: false }
})

async function testConversations() {
  console.log('🔍 Testing conversations migration...')

  // Check conversations
  const { data: conversations, error: convError } = await supabase
    .from('conversations')
    .select(`
      id,
      title,
      is_active,
      people!inner(name),
      created_at
    `)
    .order('created_at')

  if (convError) {
    console.error('❌ Error fetching conversations:', convError)
    return
  }

  console.log(`✅ Found ${conversations?.length || 0} conversations:`)
  conversations?.forEach(conv => {
    console.log(`   - "${conv.title}" for ${conv.people.name} (active: ${conv.is_active})`)
  })

  // Check messages with conversation_id
  const { data: messages, error: msgError } = await supabase
    .from('messages')
    .select(`
      id,
      content,
      conversation_id,
      person_id,
      created_at
    `)
    .not('conversation_id', 'is', null)
    .limit(5)
    .order('created_at')

  if (msgError) {
    console.error('❌ Error fetching messages:', msgError)
    return
  }

  console.log(`\n✅ Found ${messages?.length || 0} messages with conversation_id:`)
  messages?.forEach(msg => {
    console.log(`   - "${msg.content.substring(0, 50)}..." (conversation: ${msg.conversation_id})`)
  })

  console.log('\n🎉 Conversations migration looks good!')
}

testConversations().catch(console.error)