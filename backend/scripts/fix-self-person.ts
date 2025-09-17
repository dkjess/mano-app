#!/usr/bin/env tsx

/**
 * Fix Self Person Creation
 *
 * This script ensures that the self person is created for existing users.
 * It's a workaround for when the database trigger doesn't fire properly.
 */

import { createClient } from '@supabase/supabase-js';
import * as dotenv from 'dotenv';

// Load environment variables
dotenv.config({ path: '.env.local' });

const supabaseUrl = process.env.NEXT_PUBLIC_SUPABASE_URL!;
const supabaseServiceKey = process.env.SUPABASE_SERVICE_ROLE_KEY!;

if (!supabaseUrl || !supabaseServiceKey) {
  console.error('❌ Missing required environment variables');
  process.exit(1);
}

// Create Supabase client with service role key
const supabase = createClient(supabaseUrl, supabaseServiceKey, {
  auth: {
    autoRefreshToken: false,
    persistSession: false
  }
});

async function fixSelfPerson() {
  console.log('🔧 Fixing self person creation...\n');

  try {
    // Get all users
    const { data: { users }, error: usersError } = await supabase.auth.admin.listUsers();

    if (usersError) {
      throw new Error(`Failed to list users: ${usersError.message}`);
    }

    console.log(`Found ${users.length} users to check`);

    for (const user of users) {
      console.log(`\n👤 Checking user: ${user.email}`);

      // Check if self person already exists
      const { data: existingSelf } = await supabase
        .from('people')
        .select('id, name')
        .eq('user_id', user.id)
        .eq('is_self', true)
        .single();

      if (existingSelf) {
        console.log(`   ✅ Self person already exists: ${existingSelf.name}`);
        continue;
      }

      // Create self person
      const userName = user.user_metadata?.name ||
                      user.user_metadata?.full_name ||
                      user.user_metadata?.preferred_name ||
                      user.email?.split('@')[0] ||
                      'Me';

      console.log(`   🔄 Creating self person: ${userName}`);

      const { data: newSelf, error: createError } = await supabase
        .from('people')
        .insert({
          user_id: user.id,
          name: userName,
          relationship_type: 'self',
          is_self: true,
          created_at: new Date().toISOString(),
          updated_at: new Date().toISOString()
        })
        .select()
        .single();

      if (createError) {
        console.error(`   ❌ Failed to create self person: ${createError.message}`);
      } else {
        console.log(`   ✅ Created self person: ${newSelf.name} (ID: ${newSelf.id})`);

        // Create initial self-reflection message
        const { error: messageError } = await supabase
          .from('messages')
          .insert({
            user_id: user.id,
            person_id: newSelf.id,
            content: `Welcome to your self-reflection space, ${userName}! This is where you can explore your thoughts about leadership, management challenges, and personal growth. What's on your mind today?`,
            is_user: false,
            created_at: new Date().toISOString()
          });

        if (!messageError) {
          console.log(`   ✅ Created welcome message for self-reflection`);
        }
      }
    }

    console.log('\n🎉 Self person fix completed!');

  } catch (error) {
    console.error('\n❌ Fix failed:', error);
    process.exit(1);
  }
}

// Run the fix
fixSelfPerson();