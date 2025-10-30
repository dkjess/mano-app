import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const SUPABASE_URL = 'http://127.0.0.1:54321'
const SUPABASE_SERVICE_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZS1kZW1vIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImV4cCI6MTk4MzgxMjk5Nn0.EGIM96RAZx35lJzdJsyH-qQwv8Hdp7fsn3W0YpN81IU'

async function main() {
  const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_KEY)

  // Check messages table
  console.log('🔍 Checking messages in database...\n')
  const { data: messages, error } = await supabase
    .from('messages')
    .select('id, content, conversation_id, is_user')
    .limit(3)

  if (error) {
    console.error('❌ Error:', error)
    return
  }

  console.log('Messages:')
  messages?.forEach(msg => {
    console.log(`  ID: ${msg.id}`)
    console.log(`  Conversation ID: ${msg.conversation_id}`)
    console.log(`  Content: ${msg.content.substring(0, 50)}...`)
    console.log(`  Is User: ${msg.is_user}\n`)
  })

  // Check pinned messages
  console.log('🔍 Checking pinned messages...\n')
  const { data: pinned } = await supabase
    .from('pinned_messages')
    .select(`
      id, message_id,
      conversation_id:messages!message_id(conversation_id)
    `)
    .limit(3)

  console.log('Pinned messages with conversation_id:')
  console.log(JSON.stringify(pinned, null, 2))
}

main()
