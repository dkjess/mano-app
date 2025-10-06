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
    const {
      call_name,
      job_role,
      experience_level,
      communication_style,
      tone_preference,
      onboarding_step
    } = body

    // Validate required fields based on onboarding step
    if (!call_name) {
      return new Response(
        JSON.stringify({
          error: 'call_name is required'
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

    // Check if all required fields are present to mark onboarding complete
    // Note: communication_style is optional (removed from onboarding flow)
    const isComplete = !!(
      call_name &&
      job_role &&
      experience_level &&
      tone_preference
    )

    // Build update object with only provided fields
    const updateData: any = {
      user_id: user.id,
      updated_at: new Date().toISOString()
    }

    if (call_name) updateData.call_name = call_name
    if (job_role) updateData.job_role = job_role
    if (experience_level) updateData.experience_level = experience_level
    if (tone_preference) updateData.tone_preference = tone_preference
    // communication_style is optional - only set if provided and not empty
    if (communication_style && communication_style.trim() !== '') {
      updateData.communication_style = communication_style
    }

    // Update onboarding step if provided
    if (typeof onboarding_step === 'number') {
      updateData.onboarding_step = onboarding_step
    }

    // Mark complete only when all required fields are filled
    if (isComplete) {
      updateData.onboarding_completed = true
      updateData.onboarding_step = 3 // All 3 steps done (Name, Role, Tone)
    }

    // Upsert user profile with onboarding data
    const { data: updatedProfile, error: updateError } = await supabase
      .from('user_profiles')
      .upsert(updateData, {
        onConflict: 'user_id'
      })
      .select()
      .single()

    if (updateError) {
      console.error('Error updating user profile:', updateError)
      throw updateError
    }

    // Update the is_self person with the user's information
    if (call_name || job_role) {
      // First check if is_self person exists
      const { data: existingPerson } = await supabase
        .from('people')
        .select('id')
        .eq('user_id', user.id)
        .eq('is_self', true)
        .single()

      if (existingPerson) {
        // Update existing is_self person
        const personUpdate: any = {
          updated_at: new Date().toISOString()
        }
        if (call_name) personUpdate.name = call_name
        if (job_role) personUpdate.role = job_role

        const { error: personUpdateError } = await supabase
          .from('people')
          .update(personUpdate)
          .eq('id', existingPerson.id)

        if (personUpdateError) {
          console.warn('Warning: Could not update is_self person:', personUpdateError)
        }

        // Generate initial welcome message if onboarding is complete
        if (isComplete) {
          try {
            // Small delay to ensure database transaction has committed
            await new Promise(resolve => setTimeout(resolve, 500))

            const supabaseURL = Deno.env.get('SUPABASE_URL') ?? ''
            const personResponse = await fetch(`${supabaseURL}/functions/v1/person/${existingPerson.id}/initial-message`, {
              method: 'POST',
              headers: {
                'Authorization': authHeader, // Use user's auth token
                'Content-Type': 'application/json',
              },
              body: JSON.stringify({
                generate_conversation_starters: true
              })
            })
            if (!personResponse.ok) {
              console.warn('Warning: Could not generate initial message for is_self person')
            }
          } catch (error) {
            console.warn('Warning: Failed to call person initial-message endpoint:', error)
          }
        }
      } else {
        // Create new is_self person
        const { data: newPerson, error: personInsertError } = await supabase
          .from('people')
          .insert({
            user_id: user.id,
            name: call_name || 'User',
            role: job_role || null,
            relationship_type: 'self',
            is_self: true
          })
          .select()
          .single()

        if (personInsertError) {
          console.warn('Warning: Could not create is_self person:', personInsertError)
        } else if (newPerson) {
          // Generate initial welcome message for is_self person
          try {
            const supabaseURL = Deno.env.get('SUPABASE_URL') ?? ''
            const personResponse = await fetch(`${supabaseURL}/functions/v1/person/${newPerson.id}/initial-message`, {
              method: 'POST',
              headers: {
                'Authorization': authHeader, // Use user's auth token
                'Content-Type': 'application/json',
              },
              body: JSON.stringify({
                generate_conversation_starters: true
              })
            })
            if (!personResponse.ok) {
              console.warn('Warning: Could not generate initial message for is_self person')
            }
          } catch (error) {
            console.warn('Warning: Failed to call person initial-message endpoint:', error)
          }
        }
      }
    }

    return new Response(
      JSON.stringify({
        success: true,
        profile: updatedProfile,
        message: isComplete ? 'Onboarding completed successfully' : 'Onboarding progress saved',
        onboarding_completed: isComplete
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