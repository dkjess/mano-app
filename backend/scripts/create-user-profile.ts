#!/usr/bin/env tsx

/**
 * Create User Profile
 *
 * This script creates a user profile for the test user.
 */

import { createClient } from '@supabase/supabase-js';
import * as dotenv from 'dotenv';

// Load environment variables
dotenv.config({ path: '.env.local' });

const supabaseUrl = process.env.NEXT_PUBLIC_SUPABASE_URL!;
const supabaseServiceKey = process.env.SUPABASE_SERVICE_ROLE_KEY!;

// Create Supabase client with service role key
const supabase = createClient(supabaseUrl, supabaseServiceKey, {
  auth: {
    autoRefreshToken: false,
    persistSession: false
  }
});

async function createUserProfile() {
  console.log('👤 Creating user profile...\n');

  try {
    const TEST_USER_ID = '00000000-0000-0000-0000-000000000001';

    // Check if profile already exists
    const { data: existingProfile } = await supabase
      .from('user_profiles')
      .select('*')
      .eq('user_id', TEST_USER_ID)
      .single();

    if (existingProfile) {
      console.log('✅ User profile already exists:', existingProfile.call_name || existingProfile.preferred_name);
      return;
    }

    // Create user profile
    const { data: newProfile, error: profileError } = await supabase
      .from('user_profiles')
      .insert({
        user_id: TEST_USER_ID,
        preferred_name: 'Dev User',
        call_name: 'Dev',
        job_role: 'Engineering Manager',
        company: 'Test Company',
        created_at: new Date().toISOString(),
        updated_at: new Date().toISOString()
      })
      .select()
      .single();

    if (profileError) {
      throw new Error(`Failed to create profile: ${profileError.message}`);
    }

    console.log('✅ Created user profile:');
    console.log('   Name:', newProfile.call_name || newProfile.preferred_name);
    console.log('   Role:', newProfile.job_role);
    console.log('   Company:', newProfile.company);

  } catch (error) {
    console.error('❌ Failed to create profile:', error);
    process.exit(1);
  }
}

// Run the script
createUserProfile();