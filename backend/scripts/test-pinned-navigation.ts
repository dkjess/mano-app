import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const SUPABASE_URL = 'http://127.0.0.1:54321'
const SUPABASE_SERVICE_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZS1kZW1vIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImV4cCI6MTk4MzgxMjk5Nn0.EGIM96RAZx35lJzdJsyH-qQwv8Hdp7fsn3W0YpN81IU'

async function testPinnedNavigation() {
  const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_KEY)

  console.log('🧪 Testing Pinned Message Navigation Feature\n')

  // 1. Check if pinned messages exist
  console.log('1️⃣ Fetching pinned messages...')
  const { data: pinnedMessages, error: fetchError } = await supabase
    .from('pinned_messages')
    .select(`
      id, user_id, message_id, person_id, topic_id, note, title, pinned_at, created_at, updated_at,
      message_content:messages!message_id(content),
      message_created_at:messages!message_id(created_at),
      conversation_id:messages!message_id(conversation_id),
      person_name:people!person_id(name),
      person_emoji:people!person_id(emoji),
      topic_title:topics!topic_id(title)
    `)
    .order('pinned_at', { ascending: false })

  if (fetchError) {
    console.error('❌ Error fetching pinned messages:', fetchError)
    return
  }

  console.log(`✅ Found ${pinnedMessages.length} pinned message(s)\n`)

  // 2. Check each pinned message for navigation data
  for (const pin of pinnedMessages) {
    console.log('📌 Pinned Message:')
    console.log(`   ID: ${pin.id}`)
    console.log(`   Title: ${pin.title || '(no title)'}`)
    console.log(`   Message ID: ${pin.message_id}`)
    console.log(`   Person ID: ${pin.person_id}`)

    // @ts-ignore - conversation_id is a nested join
    const conversationId = pin.conversation_id?.[0]?.conversation_id
    console.log(`   Conversation ID: ${conversationId || '❌ MISSING!'}`)

    // @ts-ignore - person_name is a nested join
    const personName = pin.person_name?.[0]?.name
    console.log(`   Person: ${personName || '(no name)'}`)

    // @ts-ignore - message_content is a nested join
    const messageContent = pin.message_content?.[0]?.content
    console.log(`   Message Preview: ${messageContent?.substring(0, 60)}...`)

    if (conversationId) {
      console.log('   ✅ Has conversation_id - navigation will work!')
    } else {
      console.log('   ❌ Missing conversation_id - navigation will fail!')
    }
    console.log()
  }

  // 3. Test if we can fetch the conversation and messages
  if (pinnedMessages.length > 0) {
    const pin = pinnedMessages[0]
    // @ts-ignore
    const conversationId = pin.conversation_id?.[0]?.conversation_id

    if (conversationId) {
      console.log('2️⃣ Testing conversation fetch...')

      const { data: conversation, error: convError } = await supabase
        .from('conversations')
        .select('*')
        .eq('id', conversationId)
        .single()

      if (convError) {
        console.error('❌ Error fetching conversation:', convError)
        return
      }

      console.log(`✅ Conversation found: ${conversation.title || 'Untitled'}`)

      const { data: messages, error: msgError } = await supabase
        .from('messages')
        .select('*')
        .eq('conversation_id', conversationId)
        .order('created_at', { ascending: true })

      if (msgError) {
        console.error('❌ Error fetching messages:', msgError)
        return
      }

      console.log(`✅ Found ${messages.length} messages in conversation`)

      // Check if the pinned message exists in the conversation
      const pinnedMessageExists = messages.some(m => m.id === pin.message_id)
      if (pinnedMessageExists) {
        console.log('✅ Pinned message exists in conversation - scroll will work!')
      } else {
        console.log('❌ Pinned message NOT found in conversation - scroll will fail!')
      }
    }
  }

  console.log('\n✅ Pinned navigation test complete!')
}

testPinnedNavigation()
