#!/usr/bin/env -S npx tsx

/**
 * Quick script to check the current database state
 */

import { createClient } from '@supabase/supabase-js';

// Local Supabase configuration
const SUPABASE_URL = 'http://127.0.0.1:54321';
const SUPABASE_SERVICE_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZS1kZW1vIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImV4cCI6MTk4MzgxMjk5Nn0.EGIM96RAZx35lJzdJsyH-qQwv8Hdp7fsn3W0YpN81IU';

async function checkDatabaseState() {
  console.log('🔍 Checking current database state...\n');

  const client = createClient(SUPABASE_URL, SUPABASE_SERVICE_KEY, {
    auth: { autoRefreshToken: false, persistSession: false }
  });

  try {
    // 1. Check people table
    const { data: people, error: peopleError } = await client
      .from('people')
      .select('id, name, user_id')
      .limit(5);

    if (peopleError) {
      console.error('❌ Error fetching people:', peopleError);
    } else {
      console.log(`👥 Found ${people?.length || 0} people:`);
      people?.forEach(person => {
        console.log(`   - ${person.name} (${person.id})`);
      });
    }

    // 2. Check conversations table
    const { data: conversations, error: convError } = await client
      .from('conversations')
      .select('*')
      .limit(5);

    if (convError) {
      console.error('❌ Error fetching conversations:', convError);
    } else {
      console.log(`\n💬 Found ${conversations?.length || 0} conversations:`);
      conversations?.forEach(conv => {
        console.log(`   - ${conv.id} (person: ${conv.person_id}, active: ${conv.is_active}, title: ${conv.title || 'No title'})`);
      });
    }

    // 3. Check messages table
    const { data: messages, error: msgError } = await client
      .from('messages')
      .select('id, content, conversation_id, person_id, is_user, created_at')
      .order('created_at', { ascending: false })
      .limit(5);

    if (msgError) {
      console.error('❌ Error fetching messages:', msgError);
    } else {
      console.log(`\n📨 Found ${messages?.length || 0} recent messages:`);
      messages?.forEach(msg => {
        const preview = msg.content.substring(0, 50);
        const userType = msg.is_user ? 'USER' : 'AI';
        console.log(`   - [${userType}] "${preview}${msg.content.length > 50 ? '...' : ''}" (conv: ${msg.conversation_id || 'null'})`);
      });
    }

    // 4. Check messages without conversation_id
    const { data: orphanMessages, error: orphanError } = await client
      .from('messages')
      .select('id, content, person_id, is_user')
      .is('conversation_id', null)
      .limit(3);

    if (orphanError) {
      console.error('❌ Error fetching orphan messages:', orphanError);
    } else if (orphanMessages && orphanMessages.length > 0) {
      console.log(`\n⚠️ Found ${orphanMessages.length} messages without conversation_id:`);
      orphanMessages.forEach(msg => {
        const preview = msg.content.substring(0, 40);
        const userType = msg.is_user ? 'USER' : 'AI';
        console.log(`   - [${userType}] "${preview}..." (person: ${msg.person_id})`);
      });
    }

    console.log('\n✅ Database state check complete!');

  } catch (error) {
    console.error('❌ Database check failed:', error);
  }
}

if (import.meta.main) {
  checkDatabaseState();
}