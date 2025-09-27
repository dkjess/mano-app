#!/usr/bin/env tsx

/**
 * Fix Self Person Creation - Production
 *
 * This script ensures that the self person is created for existing users in production.
 */

import { createClient } from '@supabase/supabase-js';

// Production configuration
const supabaseUrl = 'https://zfroutbzdkhivnpiezho.supabase.co';
// Note: You'll need to get the production service role key from the Supabase dashboard
const supabaseServiceKey = process.env.SUPABASE_SERVICE_ROLE_KEY_PROD || 'NEED_PRODUCTION_SERVICE_KEY';

if (!supabaseServiceKey || supabaseServiceKey === 'NEED_PRODUCTION_SERVICE_KEY') {
  console.error('❌ Missing production service role key');
  console.log('💡 Get the service role key from:');
  console.log('   https://supabase.com/dashboard/project/zfroutbzdkhivnpiezho/settings/api');
  console.log('   Then set: export SUPABASE_SERVICE_ROLE_KEY_PROD="your_key"');
  process.exit(1);
}

// Create Supabase client with service role key
const supabase = createClient(supabaseUrl, supabaseServiceKey, {
  auth: {
    autoRefreshToken: false,
    persistSession: false
  }
});

async function fixSelfPersonProduction(userEmail?: string) {
  console.log('🔧 Fixing self person creation in PRODUCTION...\n');

  if (userEmail) {
    console.log(`🎯 Targeting specific user: ${userEmail}`);
  }

  try {
    // Get all users or specific user
    const { data: { users }, error: usersError } = await supabase.auth.admin.listUsers();

    if (usersError) {
      throw new Error(`Failed to list users: ${usersError.message}`);
    }

    const targetUsers = userEmail
      ? users.filter(u => u.email === userEmail)
      : users;

    if (userEmail && targetUsers.length === 0) {
      console.log(`❌ User not found: ${userEmail}`);
      return;
    }

    console.log(`Found ${targetUsers.length} users to check`);

    for (const user of targetUsers) {
      console.log(`\n👤 Checking user: ${user.email} (ID: ${user.id})`);

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
        console.error(`   Details:`, createError);
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

        if (messageError) {
          console.error(`   ⚠️  Failed to create welcome message: ${messageError.message}`);
        } else {
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

// Get target user from command line argument
const targetUser = process.argv[2];

// Run the fix
fixSelfPersonProduction(targetUser);