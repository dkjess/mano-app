#!/usr/bin/env -S deno run --allow-net --allow-env

// List people and profiles in production (safer approach)
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const PRODUCTION_URL = 'https://zfroutbzdkhivnpiezho.supabase.co'
const PRODUCTION_ANON_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Inpmcm91dGJ6ZGtoaXZucGllemhvIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NDk0MTY3MTAsImV4cCI6MjA2NDk5MjcxMH0.1oPaalBGxcVx1cOu_E4k8WVJIxL2OsS45bwPrbjnBt4'

const supabase = createClient(PRODUCTION_URL, PRODUCTION_ANON_KEY)

try {
  console.log('🔍 Checking production database state...')

  // Count people (public table)
  const { count: peopleCount, error: peopleError } = await supabase
    .from('people')
    .select('*', { count: 'exact', head: true })

  if (peopleError) {
    console.error('❌ Error counting people:', peopleError)
  } else {
    console.log(`📊 Total people in database: ${peopleCount}`)
  }

  // Count user profiles (public table)
  const { count: profileCount, error: profileError } = await supabase
    .from('user_profiles')
    .select('*', { count: 'exact', head: true })

  if (profileError) {
    console.error('❌ Error counting profiles:', profileError)
  } else {
    console.log(`📊 Total user profiles: ${profileCount}`)
  }

  // Count messages
  const { count: messageCount, error: messageError } = await supabase
    .from('messages')
    .select('*', { count: 'exact', head: true })

  if (messageError) {
    console.error('❌ Error counting messages:', messageError)
  } else {
    console.log(`📊 Total messages: ${messageCount}`)
  }

  // Count conversations
  const { count: conversationCount, error: conversationError } = await supabase
    .from('conversations')
    .select('*', { count: 'exact', head: true })

  if (conversationError) {
    console.error('❌ Error counting conversations:', conversationError)
  } else {
    console.log(`📊 Total conversations: ${conversationCount}`)
  }

  console.log('\n🔍 Sample data (if any):')

  // Get some sample people (without exposing user_ids)
  const { data: samplePeople, error: sampleError } = await supabase
    .from('people')
    .select('name, relationship_type, is_self, created_at')
    .order('created_at', { ascending: false })
    .limit(5)

  if (sampleError) {
    console.error('❌ Error fetching sample people:', sampleError)
  } else if (samplePeople && samplePeople.length > 0) {
    console.log('Recent people:')
    samplePeople.forEach((person, index) => {
      console.log(`  ${index + 1}. ${person.name} (${person.relationship_type}) ${person.is_self ? '[SELF]' : ''}`)
    })
  } else {
    console.log('No people found in database')
  }

} catch (error) {
  console.error('❌ Script error:', error)
}