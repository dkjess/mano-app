#!/usr/bin/env -S deno run --allow-net --allow-env

// List users in production database
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const PRODUCTION_URL = 'https://zfroutbzdkhivnpiezho.supabase.co'
const PRODUCTION_SERVICE_KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')

if (!PRODUCTION_SERVICE_KEY) {
  console.error('❌ Missing SUPABASE_SERVICE_ROLE_KEY environment variable')
  console.error('Set it with: export SUPABASE_SERVICE_ROLE_KEY=your_service_key')
  Deno.exit(1)
}

const supabase = createClient(PRODUCTION_URL, PRODUCTION_SERVICE_KEY, {
  auth: {
    autoRefreshToken: false,
    persistSession: false
  }
})

try {
  console.log('🔍 Listing production users...')

  // Query auth.users table directly (requires service role key)
  const { data: users, error } = await supabase
    .from('auth.users')
    .select('id, email, created_at, last_sign_in_at, email_confirmed_at')
    .order('created_at', { ascending: false })

  if (error) {
    console.error('❌ Error fetching users:', error)
    // Try alternative approach if direct auth table access fails
    console.log('Trying alternative approach...')

    const { data: profiles, error: profileError } = await supabase
      .from('user_profiles')
      .select('user_id, preferred_name, call_name, job_role, company, created_at')
      .order('created_at', { ascending: false })

    if (profileError) {
      console.error('❌ Error fetching user profiles:', profileError)
      Deno.exit(1)
    }

    console.log(`✅ Found ${profiles?.length || 0} user profiles:`)
    profiles?.forEach((profile, index) => {
      console.log(`${index + 1}. ${profile.call_name || profile.preferred_name} (${profile.user_id})`)
      console.log(`   Role: ${profile.job_role || 'Not set'}`)
      console.log(`   Company: ${profile.company || 'Not set'}`)
      console.log(`   Created: ${new Date(profile.created_at).toLocaleString()}`)
      console.log()
    })

  } else {
    console.log(`✅ Found ${users?.length || 0} users:`)
    users?.forEach((user, index) => {
      console.log(`${index + 1}. ${user.email}`)
      console.log(`   ID: ${user.id}`)
      console.log(`   Created: ${new Date(user.created_at).toLocaleString()}`)
      console.log(`   Last Sign In: ${user.last_sign_in_at ? new Date(user.last_sign_in_at).toLocaleString() : 'Never'}`)
      console.log(`   Email Confirmed: ${user.email_confirmed_at ? 'Yes' : 'No'}`)
      console.log()
    })
  }

} catch (error) {
  console.error('❌ Script error:', error)
}