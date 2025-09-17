import { createClient } from '@supabase/supabase-js';

const supabaseUrl = 'http://127.0.0.1:54321';
const supabaseServiceRoleKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZS1kZW1vIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImV4cCI6MTk4MzgxMjk5Nn0.EGIM96RAZx35lJzdJsyH-qQwv8Hdp7fsn3W0YpN81IU';

const supabase = createClient(supabaseUrl, supabaseServiceRoleKey, {
  auth: {
    autoRefreshToken: false,
    persistSession: false
  }
});

async function checkUser() {
  // Find user by email
  const { data: authUser, error: authError } = await supabase.auth.admin.listUsers();
  
  if (authError) {
    console.error('Error fetching users:', authError);
    return;
  }
  
  const user = authUser.users.find((u: any) => u.email === 'dkjess@gmail.com');
  
  if (!user) {
    console.log('❌ User not found: dkjess@gmail.com');
    return;
  }
  
  console.log('✅ User found:', {
    id: user.id,
    email: user.email,
    created_at: user.created_at
  });
  
  // Check user_profiles
  const { data: profile, error: profileError } = await supabase
    .from('user_profiles')
    .select('*')
    .eq('user_id', user.id)
    .single();
    
  if (profileError) {
    console.log('❌ No user_profiles record:', profileError.message);
  } else {
    console.log('📋 User Profile:', {
      preferred_name: profile.preferred_name,
      call_name: profile.call_name,
      job_role: profile.job_role,
      company: profile.company,
      onboarding_completed: profile.onboarding_completed,
      onboarding_step: profile.onboarding_step
    });
  }
  
  // Check people (self person)
  const { data: people, error: peopleError } = await supabase
    .from('people')
    .select('*')
    .eq('user_id', user.id)
    .eq('is_self', true);
    
  if (peopleError || !people || people.length === 0) {
    console.log('❌ No self person found');
  } else {
    console.log('👤 Self Person:', {
      name: people[0].name,
      role: people[0].role,
      is_self: people[0].is_self
    });
  }
}

await checkUser();
