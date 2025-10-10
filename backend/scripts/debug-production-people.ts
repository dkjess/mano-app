#!/usr/bin/env -S deno run --allow-net --allow-env

// Debug script to check production people data
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const PRODUCTION_URL = 'https://zfroutbzdkhivnpiezho.supabase.co'
const PRODUCTION_ANON_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Inpmcm91dGJ6ZGtoaXZucGllemhvIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NDk0MTY3MTAsImV4cCI6MjA2NDk5MjcxMH0.1oPaalBGxcVx1cOu_E4k8WVJIxL2OsS45bwPrbjnBt4'

// You'll need to provide a valid JWT token from the production user
const JWT_TOKEN = Deno.args[0]

if (!JWT_TOKEN) {
  console.error('Usage: deno run debug-production-people.ts <jwt-token>')
  console.error('Get JWT token from the iOS app or production login')
  Deno.exit(1)
}

const supabase = createClient(PRODUCTION_URL, PRODUCTION_ANON_KEY, {
  global: {
    headers: { Authorization: `Bearer ${JWT_TOKEN}` }
  }
})

try {
  console.log('🔍 Checking production people data...')

  // Get user info
  const { data: { user }, error: userError } = await supabase.auth.getUser()
  if (userError) {
    console.error('❌ Auth error:', userError)
    Deno.exit(1)
  }

  console.log('✅ User:', user?.id, user?.email)

  // Get all people for this user
  const { data: people, error: peopleError } = await supabase
    .from('people')
    .select('*')
    .eq('user_id', user?.id)
    .order('created_at')

  if (peopleError) {
    console.error('❌ People fetch error:', peopleError)
  } else {
    console.log(`✅ Found ${people?.length || 0} people:`)
    people?.forEach(person => {
      console.log(`  - ${person.name} (${person.relationship_type}) is_self=${person.is_self}`)
    })
  }

  // Check user profile
  const { data: profile, error: profileError } = await supabase
    .from('user_profiles')
    .select('*')
    .eq('user_id', user?.id)
    .single()

  if (profileError) {
    console.log('⚠️ No user profile found:', profileError)
  } else {
    console.log('✅ User profile:', profile.call_name, profile.job_role, profile.company)
  }

} catch (error) {
  console.error('❌ Script error:', error)
}