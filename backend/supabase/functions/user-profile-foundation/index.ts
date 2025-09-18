import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

serve(async (req) => {
  // Handle CORS preflight
  if (req.method === 'OPTIONS') {
    return new Response(null, { headers: corsHeaders })
  }

  // Only allow PUT method
  if (req.method !== 'PUT') {
    return new Response(
      JSON.stringify({ error: 'Method not allowed' }),
      {
        status: 405,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' }
      }
    )
  }

  try {
    // Parse request body
    const body = await req.json()
    const { preferred_name, call_name, job_role, company } = body

    if (!preferred_name || !call_name || !job_role) {
      return new Response(
        JSON.stringify({
          error: 'preferred_name, call_name, and job_role are required'
        }),
        {
          status: 400,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' }
        }
      )
    }

    // Create Supabase client with user's auth
    const authHeader = req.headers.get('Authorization')
    if (!authHeader) {
      return new Response(
        JSON.stringify({ error: 'Authorization header is required' }),
        {
          status: 401,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' }
        }
      )
    }

    const supabase = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_ANON_KEY') ?? '',
      {
        global: {
          headers: { Authorization: authHeader },
        },
      }
    )

    // Get current user
    const { data: { user }, error: userError } = await supabase.auth.getUser()
    if (userError || !user) {
      return new Response(
        JSON.stringify({ error: 'Authentication failed' }),
        {
          status: 401,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' }
        }
      )
    }

    // Upsert user profile with foundation data (insert if doesn't exist, update if exists)
    const { data: updatedProfile, error: updateError } = await supabase
      .from('user_profiles')
      .upsert({
        user_id: user.id,
        preferred_name,
        call_name,
        job_role,
        company: company || null, // Company is optional
        onboarding_step: 1, // Foundation profile completed (step 1)
        onboarding_completed: true, // Mark onboarding as complete
        updated_at: new Date().toISOString()
      }, {
        onConflict: 'user_id'
      })
      .select()
      .single()

    if (updateError) {
      console.error('Error updating user profile:', updateError)
      throw updateError
    }

    // Also upsert the is_self person with the name information
    // Use call_name for the person record as that's what Mano should call them
    const { error: personUpdateError } = await supabase
      .from('people')
      .upsert({
        user_id: user.id,
        name: call_name, // Use their preferred call name, not full name
        role: job_role,
        team: company || null,
        relationship_type: 'self',
        is_self: true,
        updated_at: new Date().toISOString()
      }, {
        onConflict: 'user_id,is_self',
        ignoreDuplicates: false
      })

    if (personUpdateError) {
      console.warn('Warning: Could not upsert is_self person:', personUpdateError)
      // Don't fail the request for this - the user profile update is more important
    }

    return new Response(
      JSON.stringify({
        success: true,
        profile: updatedProfile,
        message: 'Foundation profile completed successfully'
      }),
      {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        status: 200
      }
    )

  } catch (error) {
    console.error('Error in user-profile-foundation function:', error)
    return new Response(
      JSON.stringify({ error: (error as any).message }),
      {
        status: 500,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' }
      }
    )
  }
})